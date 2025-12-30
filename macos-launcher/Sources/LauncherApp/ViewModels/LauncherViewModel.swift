import Foundation
import OSLog

import SwiftUI

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var input: String = ""
    @Published var tasks: [ApiTask] = []
    @Published var selectedIndex: Int?
    @Published var tokens: [TokenSpan] = []
    @Published var actionName: String = ""
    @Published var mode: LauncherMode = .list
    @Published var statusMessage: String?
    @Published var reportConfig: ReportConfig?
    @Published var toasts: [ToastMessage] = []

    // MARK: - Completion State
    @Published var completions: [CompletionItem] = []
    @Published var selectedCompletionIndex: Int = 0
    @Published var showCompletionMenu: Bool = false
    @Published var ghostText: String?
    @Published var completionContext: CompletionContext = .none
    @Published var cursorPosition: Int = 0

    private let apiClient: ApiClientProtocol
    private var requestCounter: Int = 0
    private var latestParse: ParseResponse?
    private let logger = Logger(subsystem: "bee.macos-launcher", category: "view-model")
    private var suppressInputHandling = false
    private var configLoaded = false
    private var pendingUnexpectedTokenToast: Task<Void, Never>?
    private var pendingUnexpectedTokenMessage: String?
    private var pendingUnexpectedTokenRequestId: Int?
    private let unexpectedTokenToastDelay: TimeInterval

    // Cached completion data
    private var cachedProjects: [CompletionItem] = []
    private var cachedTags: [CompletionItem] = []
    private var cachedActions: [CompletionItem] = []
    private var cachedStatus: [CompletionItem] = []
    private var cachedDates: [CompletionItem] = []
    private var completionsLoaded = false

    init(
        apiClient: ApiClientProtocol = ApiClient(),
        unexpectedTokenToastDelay: TimeInterval = 3
    ) {
        self.apiClient = apiClient
        self.unexpectedTokenToastDelay = unexpectedTokenToastDelay
    }

    /// Fetch the report configuration from the API.
    func loadConfig() async {
        guard !configLoaded else { return }
        configLoaded = true
        do {
            let config = try await apiClient.fetchConfig()
            reportConfig = config.report
            logger.info("Config loaded: \(config.report.columns.count) columns")
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
            // Use default config on failure
            reportConfig = ReportConfig(
                filters: ["status:pending or status:active"],
                columns: ["id", "summary", "tags", "status"],
                columnNames: ["ID", "Summary", "Tags", "Status"]
            )
        }
    }

    /// Handle text input changes and trigger parsing/actions on each keystroke.
    func handleInputChange(_ newValue: String) {
        if suppressInputHandling {
            return
        }
        cancelPendingParseErrorToast()
        requestCounter += 1
        let requestId = requestCounter

        logger.debug("Input change -> parse only. id=\(requestId), text=\(newValue, privacy: .private)")
        selectedIndex = nil
        mode = .list
        statusMessage = nil

        Task {
            await parseOnly(for: newValue, requestId: requestId)
        }
    }

    /// Parse input for highlighting and action preview without executing.
    func parseOnly(for query: String, requestId: Int) async {
        do {
            logger.debug("Parse request start. id=\(requestId)")
            let parsed = try await apiClient.parse(input: query)
            guard requestId == requestCounter else { return }
            latestParse = parsed
            tokens = parsed.tokens
            actionName = parsed.action
            cancelPendingParseErrorToast()
            logger.debug("Parse request done. id=\(requestId), action=\(parsed.action)")

            if shouldAutoList(actionName: parsed.action) {
                await runAction(from: parsed, requestId: requestId, resetInput: false, updateStatus: false)
            }
        } catch {
            guard requestId == requestCounter else { return }
            latestParse = nil
            tokens = []
            actionName = ""
            logger.error("Parse request failed. id=\(requestId), error=\(error.localizedDescription, privacy: .public)")
            scheduleParseErrorToast(message: error.localizedDescription, requestId: requestId)
        }
    }

    /// Execute the current parse result when the user submits.
    func handleSubmit() {
        if selectedIndex != nil {
            openDetail()
        } else {
            requestCounter += 1
            let requestId = requestCounter
            let snapshot = latestParse

            logger.info("Submit -> run action. id=\(requestId)")

            Task {
                await runAction(from: snapshot, requestId: requestId, resetInput: true, updateStatus: true)
            }
        }
    }

    /// Run the action derived from the latest parse response.
    func runAction(from parsed: ParseResponse?, requestId: Int, resetInput: Bool, updateStatus: Bool) async {
        do {
            let parsed = parsed ?? apiClient.emptyParse()
            let actionName = parsed.action.isEmpty ? "list" : parsed.action
            logger.debug("Action request start. id=\(requestId), action=\(actionName)")
            let filter = await resolveDefaultFilterIfNeeded(parsed: parsed, actionName: actionName)
            let response = try await apiClient.runAction(
                action: actionName,
                properties: parsed.properties,
                filter: filter
            )
            guard requestId == requestCounter else { return }
            tasks = sortTasksByUrgency(response.tasks)
            syncSelectionAfterTasksUpdate()
            if updateStatus {
                statusMessage = buildStatusMessage(from: response.events)
            }
            if resetInput {
                resetInputState()
                loadInitialListIfNeeded()
            }
            logger.debug("Action request done. id=\(requestId), tasks=\(response.tasks.count)")
        } catch {
            guard requestId == requestCounter else { return }
            tasks = []
            logger.error("Action request failed. id=\(requestId), error=\(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
        }
    }

    /// Apply default report filters to list actions when no filter was provided.
    func resolveDefaultFilterIfNeeded(parsed: ParseResponse, actionName: String) async -> JSONValue? {
        guard actionName.lowercased() == "list" else { return parsed.filter }
        guard parsed.filter == nil else { return parsed.filter }
        guard let defaults = reportConfig?.filters, !defaults.isEmpty else { return parsed.filter }

        let filterExpr = defaults.joined(separator: " or ")
        do {
            let parsedDefaults = try await apiClient.parse(input: "list \(filterExpr)")
            return parsedDefaults.filter
        } catch {
            logger.error("Failed to parse default filters: \(error.localizedDescription, privacy: .public)")
            return parsed.filter
        }
    }

    /// Present a toast message that auto-dismisses after a duration.
    func showToast(message: String, duration: TimeInterval = 10) {
        let toast = ToastMessage(message: message)
        withAnimation(.easeInOut(duration: 0.2)) {
            toasts.append(toast)
        }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toasts.removeAll { $0.id == toast.id }
                }
            }
        }
    }

    /// Cancel any pending delayed toast for parse errors.
    private func cancelPendingParseErrorToast() {
        pendingUnexpectedTokenToast?.cancel()
        pendingUnexpectedTokenToast = nil
        pendingUnexpectedTokenMessage = nil
        pendingUnexpectedTokenRequestId = nil
    }

    /// Schedule a delayed toast for parse errors if typing has paused.
    private func scheduleParseErrorToast(message: String, requestId: Int) {
        pendingUnexpectedTokenToast?.cancel()
        pendingUnexpectedTokenMessage = message
        pendingUnexpectedTokenRequestId = requestId
        if showCompletionMenu {
            return
        }
        pendingUnexpectedTokenToast = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.unexpectedTokenToastDelay))
            guard requestId == self.requestCounter else { return }
            guard let latest = self.pendingUnexpectedTokenMessage else { return }
            self.pendingUnexpectedTokenToast = nil
            self.pendingUnexpectedTokenMessage = nil
            self.pendingUnexpectedTokenRequestId = nil
            self.showToast(message: latest)
        }
    }

    /// If a parse error is pending, schedule it once the menu closes.
    private func schedulePendingParseErrorAfterMenuClose() {
        guard !showCompletionMenu else { return }
        guard let message = pendingUnexpectedTokenMessage,
              let requestId = pendingUnexpectedTokenRequestId else { return }
        scheduleParseErrorToast(message: message, requestId: requestId)
    }

    /// Move the selection by a delta, wrapping around the list.
    func moveSelection(delta: Int) {
        guard !tasks.isEmpty else { return }
        let count = tasks.count
        if let current = selectedIndex {
            let next = (current + delta + count) % count
            selectedIndex = next
        } else {
            selectedIndex = delta >= 0 ? 0 : count - 1
        }
    }

    /// Keep selection within bounds after tasks update.
    func syncSelectionAfterTasksUpdate() {
        guard let current = selectedIndex else { return }
        if tasks.isEmpty {
            selectedIndex = nil
            return
        }
        if current >= tasks.count {
            selectedIndex = tasks.count - 1
        }
    }

    /// Sort tasks by urgency, highest first, keeping nil urgency last.
    func sortTasksByUrgency(_ items: [ApiTask]) -> [ApiTask] {
        items.sorted { lhs, rhs in
            switch (lhs.urgency, rhs.urgency) {
            case let (l?, r?):
                if l == r {
                    return lhs.uuid < rhs.uuid
                }
                return l > r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.uuid < rhs.uuid
            }
        }
    }

    /// Open the detail view for the currently selected task.
    func openDetail() {
        guard selectedIndex != nil else { return }
        mode = .detail
    }

    /// Close the detail view and return to the list.
    func closeDetail() {
        mode = .list
    }

    /// Return the currently selected task.
    var selectedTask: ApiTask? {
        guard let index = selectedIndex, tasks.indices.contains(index) else { return nil }
        return tasks[index]
    }

    /// Return true if we should automatically run the list action while typing.
    func shouldAutoList(actionName: String) -> Bool {
        actionName.isEmpty || actionName.lowercased() == "list"
    }

    /// Build a status message from API events.
    func buildStatusMessage(from events: [ApiEvent]) -> String? {
        guard !events.isEmpty else { return nil }
        return events.map { $0.message }.joined(separator: " ")
    }

    /// Load the list view for the current input, if applicable.
    func loadInitialListIfNeeded() {
        guard shouldAutoList(actionName: actionName) else { return }
        requestCounter += 1
        let requestId = requestCounter
        let snapshot = apiClient.emptyParse()

        Task {
            await runAction(from: snapshot, requestId: requestId, resetInput: false, updateStatus: false)
        }
    }

    /// Temporarily disable input handling while updating the input.
    func resetInputState() {
        suppressInputHandling = true
        input = ""
        tokens = []
        actionName = ""
        selectedIndex = nil
        clearCompletions()
        suppressInputHandling = false
    }

    // MARK: - Completion Methods

    /// Load all completion data from the API at startup.
    func loadCompletionData() async {
        guard !completionsLoaded else { return }
        completionsLoaded = true

        async let projectsTask = apiClient.fetchCompletions(type: "projects")
        async let tagsTask = apiClient.fetchCompletions(type: "tags")
        async let actionsTask = apiClient.fetchCompletions(type: "actions")
        async let statusTask = apiClient.fetchCompletions(type: "status")
        async let datesTask = apiClient.fetchCompletions(type: "dates")

        do {
            let (projects, tags, actions, status, dates) = try await (
                projectsTask, tagsTask, actionsTask, statusTask, datesTask
            )
            cachedProjects = projects.items
            cachedTags = tags.items
            cachedActions = actions.items
            cachedStatus = status.items
            cachedDates = dates.items
            logger.info("Completions loaded: \(self.cachedProjects.count) projects, \(self.cachedTags.count) tags, \(self.cachedActions.count) actions")
        } catch {
            logger.error("Failed to load completions: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Detect the completion context based on the current input and cursor position.
    func detectCompletionContext() -> CompletionContext {
        let text = input
        let pos = min(cursorPosition, text.count)

        // Find the current word being typed (from last space or start to cursor)
        let beforeCursor = String(text.prefix(pos))
        let lastWord = lastWordBeforeCursor(beforeCursor)

        // Check for specific prefixes
        if let lastToken = tokens.last(where: { $0.end <= pos }) {
            let tokenType = lastToken.tokenType
            if TokenClassifier.isTagPrefix(tokenType) {
                return .tag
            }
            if TokenClassifier.isProjectPrefix(tokenType) {
                return .project
            }
            if TokenClassifier.isStatusFilter(tokenType) {
                return .status
            }
            if TokenClassifier.isDateFilter(tokenType) {
                return .date
            }
            if TokenClassifier.isDependency(tokenType) {
                return .taskRef
            }
        }

        // Check for trigger characters at end of beforeCursor
        if beforeCursor.hasSuffix("+") || beforeCursor.hasSuffix("-") {
            return .tag
        }
        if beforeCursor.hasSuffix("project:") || beforeCursor.hasSuffix("proj:") {
            return .project
        }
        if beforeCursor.hasSuffix("status:") {
            return .status
        }
        if beforeCursor.hasSuffix("due:") || beforeCursor.hasSuffix("due.before:") ||
           beforeCursor.hasSuffix("due.after:") || beforeCursor.hasSuffix("created.before:") ||
           beforeCursor.hasSuffix("created.after:") || beforeCursor.hasSuffix("end.before:") ||
           beforeCursor.hasSuffix("end.after:") {
            return .date
        }
        if beforeCursor.hasSuffix("depends:") {
            return .taskRef
        }

        // Handle prefixes with an in-progress value (e.g., "due:tom", "status:pen")
        if lastWord.hasPrefix("project:") || lastWord.hasPrefix("proj:") {
            return .project
        }
        if lastWord.hasPrefix("status:") {
            return .status
        }
        if lastWord.hasPrefix("due:") || lastWord.hasPrefix("due.before:") ||
            lastWord.hasPrefix("due.after:") || lastWord.hasPrefix("created.before:") ||
            lastWord.hasPrefix("created.after:") || lastWord.hasPrefix("end.before:") ||
            lastWord.hasPrefix("end.after:") {
            return .date
        }
        if lastWord.hasPrefix("depends:") {
            return .taskRef
        }

        // First word = action
        if !beforeCursor.contains(" ") && !beforeCursor.isEmpty {
            return .action
        }

        return .none
    }

    /// Return the last whitespace-delimited token before the cursor.
    func lastWordBeforeCursor(_ beforeCursor: String) -> String {
        beforeCursor.split(whereSeparator: { $0 == " " })
            .last
            .map(String.init) ?? ""
    }

    /// Get the current prefix being typed for completion filtering.
    func getCurrentPrefix() -> String {
        let text = input
        let pos = min(cursorPosition, text.count)
        let beforeCursor = String(text.prefix(pos))

        // Find start of current word (after last trigger char or space)
        var wordStart = beforeCursor.count
        for (i, char) in beforeCursor.enumerated().reversed() {
            if char == " " || char == ":" || char == "+" || char == "-" {
                wordStart = i + 1
                break
            }
            if i == 0 {
                wordStart = 0
            }
        }

        return String(beforeCursor.dropFirst(wordStart))
    }

    /// Update completions based on the current context and prefix.
    func updateCompletions() {
        let context = detectCompletionContext()
        completionContext = context
        let prefix = getCurrentPrefix().lowercased()

        let source: [CompletionItem]
        switch context {
        case .action:
            source = cachedActions
        case .tag:
            source = cachedTags
        case .project:
            source = cachedProjects
        case .status:
            source = cachedStatus
        case .date:
            source = cachedDates
        case .taskRef:
            // For task refs, use current task UUIDs
            source = tasks.map { CompletionItem(value: String($0.uuid.prefix(8)), count: nil) }
        case .none:
            completions = []
            ghostText = nil
            return
        }

        // Filter by prefix
        if prefix.isEmpty {
            completions = source
        } else {
            completions = source.filter { $0.value.lowercased().hasPrefix(prefix) }
        }

        selectedCompletionIndex = 0

        // Update ghost text
        if let first = completions.first, !prefix.isEmpty {
            let suffix = String(first.value.dropFirst(prefix.count))
            ghostText = suffix.isEmpty ? nil : suffix
        } else {
            ghostText = nil
        }
    }

    /// Accept the currently selected completion.
    func acceptCompletion(_ item: CompletionItem? = nil) {
        let completionItem = item ?? completions[safe: selectedCompletionIndex]
        guard let completion = completionItem else { return }

        let prefix = getCurrentPrefix()
        let pos = cursorPosition

        // Find the start of the prefix in the input
        let prefixStart = pos - prefix.count
        guard prefixStart >= 0 else { return }

        // Replace the prefix with the full completion value
        var newInput = input
        let startIndex = newInput.index(newInput.startIndex, offsetBy: prefixStart)
        let endIndex = newInput.index(newInput.startIndex, offsetBy: pos)
        newInput.replaceSubrange(startIndex..<endIndex, with: completion.value)

        // Update input and cursor
        suppressInputHandling = true
        input = newInput
        cursorPosition = prefixStart + completion.value.count
        suppressInputHandling = false

        clearCompletions()

        // Re-parse after completion
        handleInputChange(input)
    }

    /// Accept the ghost text completion (Tab key).
    func acceptGhostText() {
        if let _ = ghostText, !completions.isEmpty {
            acceptCompletion(completions.first)
        }
    }

    /// Toggle the completion menu visibility.
    func toggleCompletionMenu() {
        if showCompletionMenu {
            showCompletionMenu = false
        } else {
            updateCompletions()
            showCompletionMenu = !completions.isEmpty
        }
    }

    /// Move completion selection up/down.
    func moveCompletionSelection(delta: Int) {
        guard !completions.isEmpty else { return }
        let count = completions.count
        selectedCompletionIndex = (selectedCompletionIndex + delta + count) % count
    }

    /// Clear all completion state.
    func clearCompletions() {
        completions = []
        ghostText = nil
        showCompletionMenu = false
        selectedCompletionIndex = 0
        completionContext = .none
        schedulePendingParseErrorAfterMenuClose()
    }

    /// Handle cursor position changes from the text view.
    func handleCursorChange(_ position: Int) {
        cursorPosition = position
        updateCompletions()
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
