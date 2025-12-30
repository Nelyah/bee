import Foundation
import OSLog

import SwiftUI

@MainActor
final class LauncherViewModel: ObservableObject {
    private enum Constants {
        static let defaultToastDuration: TimeInterval = 10
        static let toastAnimationDuration: TimeInterval = 0.2
        static let defaultUnexpectedTokenToastDelay: TimeInterval = 3
    }

    @Published var input: String = ""
    @Published var tasks: [ApiTask] = []
    @Published var selectedIndex: Int?
    @Published var tokens: [TokenSpan] = []
    @Published var actionName: String = ""
    @Published var mode: LauncherMode = .list
    @Published var statusMessage: String?
    /// Whether the text input has keyboard focus (insert mode).
    @Published var isInsertMode: Bool = true
    @Published var reportConfig: ReportConfig?
    @Published var toasts: [ToastMessage] = []
    @Published var isCommandPalettePresented: Bool = false
    @Published var commandPaletteMode: CommandPaletteMode = .root
    @Published var commandPaletteQuery: String = ""
    @Published var commandPaletteSelectionIndex: Int = 0
    @Published var commandPaletteIsLoading: Bool = false
    @Published private(set) var gitlabSuggestions: [GitlabMergeRequestSuggestion] = []
    @Published private(set) var jiraSuggestions: [JiraIssueSuggestion] = []

    // MARK: - Completion State
    @Published var completions: [CompletionItem] = []
    @Published var selectedCompletionIndex: Int = 0
    @Published var showCompletionMenu: Bool = false
    @Published var ghostText: String?
    @Published var completionContext: CompletionContext = .none
    @Published var cursorPosition: Int = 0

    // MARK: - Grouping State
    /// The current grouping strategy.
    let groupingStrategy: TaskGroupingStrategy = ProjectGroupingStrategy()
    /// Set of collapsed group keys.
    @Published var collapsedGroups: Set<String?> = []
    /// Currently hovered row index (for collapse toggle).
    @Published var hoveredRowIndex: Int?
    /// Currently selected row index in grouped view.
    @Published var selectedRowIndex: Int?

    private let actionService: LauncherActionService
    private let apiClient: ApiClientProtocol
    private var requestCounter: Int = 0
    private var latestParse: ParseResponse?
    private let logger = Logger(subsystem: "bee.macos-launcher", category: "view-model")
    private var suppressInputHandling = false
    private var configLoaded = false
    private let unexpectedTokenToastDelay: TimeInterval
    private lazy var parseErrorToastScheduler = ParseErrorToastScheduler(
        delay: unexpectedTokenToastDelay,
        shouldDefer: { [weak self] in
            self?.showCompletionMenu ?? false
        },
        isRequestCurrent: { [weak self] requestId in
            guard let self else { return false }
            return requestId == self.requestCounter
        },
        showToast: { [weak self] message in
            self?.showToast(message: message)
        }
    )

    // Cached completion data
    private var completionCache = CompletionCache()
    private var completionsLoaded = false

    init(
        apiClient: ApiClientProtocol = ApiClient(),
        actionService: LauncherActionService? = nil,
        unexpectedTokenToastDelay: TimeInterval = Constants.defaultUnexpectedTokenToastDelay
    ) {
        self.apiClient = apiClient
        self.actionService = actionService ?? LauncherActionService(apiClient: apiClient)
        self.unexpectedTokenToastDelay = unexpectedTokenToastDelay
    }

    /// Fetch the report configuration from the API.
    func loadConfig() async {
        guard !configLoaded else { return }
        configLoaded = true
        do {
            let config = try await actionService.loadConfig()
            reportConfig = config
            logger.info("Config loaded: \(config.columns.count) columns")
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
        mode = NavigationCoordinator.modeForInputChange()
        statusMessage = nil

        Task {
            await parseOnly(for: newValue, requestId: requestId)
        }
    }

    /// Parse input for highlighting and action preview without executing.
    func parseOnly(for query: String, requestId: Int) async {
        do {
            logger.debug("Parse request start. id=\(requestId)")
            let parsed = try await actionService.parse(input: query)
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
            let parsed = parsed ?? actionService.emptyParse()
            let actionName = parsed.action.isEmpty ? "list" : parsed.action
            logger.debug("Action request start. id=\(requestId), action=\(actionName)")
            let response = try await actionService.runAction(parsed: parsed, actionName: actionName)
            guard requestId == requestCounter else { return }
            tasks = response.tasks
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
    /// Present a toast message that auto-dismisses after a duration.
    func showToast(message: String, duration: TimeInterval = Constants.defaultToastDuration) {
        let toast = ToastMessage(message: message)
        withAnimation(.easeInOut(duration: Constants.toastAnimationDuration)) {
            toasts.append(toast)
        }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                withAnimation(.easeInOut(duration: Constants.toastAnimationDuration)) {
                    toasts.removeAll { $0.id == toast.id }
                }
            }
        }
    }

    /// Cancel any pending delayed toast for parse errors.
    private func cancelPendingParseErrorToast() {
        parseErrorToastScheduler.cancel()
    }

    /// Schedule a delayed toast for parse errors if typing has paused.
    private func scheduleParseErrorToast(message: String, requestId: Int) {
        parseErrorToastScheduler.schedule(message: message, requestId: requestId)
    }

    /// If a parse error is pending, schedule it once the menu closes.
    private func schedulePendingParseErrorAfterMenuClose() {
        parseErrorToastScheduler.scheduleAfterMenuClose()
    }

    /// Move the selection by a delta, clamping at list boundaries (skipping group headers).
    /// Also exits insert mode when navigating.
    func moveSelection(delta: Int) {
        if isInsertMode {
            isInsertMode = false
        }
        // Use grouped selection to skip headers
        let rows = groupedRows
        selectedRowIndex = TaskListCoordinator.moveGroupedSelection(
            rows: rows,
            currentRowIndex: selectedRowIndex,
            delta: delta
        )
        // Also update flat selectedIndex for compatibility with detail view
        if let rowIdx = selectedRowIndex, case .task(let item) = rows[rowIdx] {
            selectedIndex = item.flatIndex
        }
    }

    /// Select the first row in the list.
    func selectFirstRow() {
        let rows = groupedRows
        guard !rows.isEmpty else { return }
        if isInsertMode { isInsertMode = false }
        selectedRowIndex = 0
        // Sync flat selectedIndex if this is a task row
        if case .task(let item) = rows[0] {
            selectedIndex = item.flatIndex
        }
    }

    /// Select the last row in the list.
    func selectLastRow() {
        let rows = groupedRows
        guard !rows.isEmpty else { return }
        if isInsertMode { isInsertMode = false }
        selectedRowIndex = rows.count - 1
        // Sync flat selectedIndex if this is a task row
        if case .task(let item) = rows[rows.count - 1] {
            selectedIndex = item.flatIndex
        }
    }

    /// Enter insert mode, focusing the text input.
    func enterInsertMode() {
        isInsertMode = true
    }

    // MARK: - Grouping Methods

    /// Computed grouped rows for display.
    var groupedRows: [GroupedListRow] {
        TaskListCoordinator.groupTasks(tasks, using: groupingStrategy, collapsedKeys: collapsedGroups)
    }

    /// Toggle collapse for a group.
    func toggleGroupCollapse(_ key: String?) {
        if collapsedGroups.contains(key) {
            collapsedGroups.remove(key)
        } else {
            collapsedGroups.insert(key)
        }
        saveCollapsedState()
    }

    /// Toggle collapse for the currently selected or hovered header. Returns true if toggled.
    func toggleSelectedOrHoveredGroupCollapse() -> Bool {
        let rows = groupedRows
        // Prefer selected row (keyboard navigation), fall back to hovered (mouse)
        let idx = selectedRowIndex ?? hoveredRowIndex
        guard let idx = idx,
              idx < rows.count,
              case .header(let h) = rows[idx] else {
            return false
        }
        toggleGroupCollapse(h.key)
        return true
    }

    private func saveCollapsedState() {
        let keys = collapsedGroups.compactMap { $0 }
        UserDefaults.standard.set(keys, forKey: UserDefaultsKeys.collapsedGroups)
        UserDefaults.standard.set(collapsedGroups.contains(nil), forKey: UserDefaultsKeys.collapsedNilGroup)
    }

    func loadCollapsedState() {
        let keys = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.collapsedGroups) ?? []
        let includesNil = UserDefaults.standard.bool(forKey: UserDefaultsKeys.collapsedNilGroup)
        collapsedGroups = Set(keys.map { Optional($0) })
        if includesNil { collapsedGroups.insert(nil) }
    }

    /// Keep selection within bounds after tasks update.
    func syncSelectionAfterTasksUpdate() {
        selectedIndex = TaskListCoordinator.syncSelection(tasks: tasks, selectedIndex: selectedIndex)
        if let selectedIndex {
            let rows = groupedRows
            selectedRowIndex = rows.firstIndex { row in
                if case .task(let item) = row {
                    return item.flatIndex == selectedIndex
                }
                return false
            }
        } else {
            selectedRowIndex = nil
        }
    }

    /// Sort tasks by urgency, highest first, keeping nil urgency last.
    func sortTasksByUrgency(_ items: [ApiTask]) -> [ApiTask] {
        TaskListCoordinator.sortTasksByUrgency(items)
    }

    /// Open the detail view for the currently selected task.
    func openDetail() {
        if let newMode = NavigationCoordinator.modeForOpenDetail(selectedIndex: selectedIndex) {
            mode = newMode
        }
    }

    /// Close the detail view and return to the list.
    func closeDetail() {
        mode = NavigationCoordinator.modeForCloseDetail()
    }

    /// Return the currently selected task.
    var selectedTask: ApiTask? {
        TaskListCoordinator.selectedTask(tasks: tasks, selectedIndex: selectedIndex)
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
        guard tasks.isEmpty else { return }
        guard shouldAutoList(actionName: actionName) else { return }
        requestCounter += 1
        let requestId = requestCounter
        let snapshot = actionService.emptyParse()

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

    // MARK: - Command Palette

    func openCommandPalette() {
        guard selectedTask != nil else {
            showToast(message: "Select a task to add a link.")
            return
        }
        commandPaletteMode = .root
        commandPaletteQuery = ""
        commandPaletteSelectionIndex = 0
        isCommandPalettePresented = true
    }

    func closeCommandPalette() {
        isCommandPalettePresented = false
        commandPaletteMode = .root
        commandPaletteQuery = ""
        commandPaletteSelectionIndex = 0
    }

    var filteredCommandPaletteActions: [CommandPaletteAction] {
        let query = commandPaletteQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return CommandPaletteAction.allCases }
        return CommandPaletteAction.allCases.filter { $0.rawValue.lowercased().contains(query) }
    }

    var filteredCommandPaletteSuggestions: [CommandPaletteSuggestion] {
        let query = commandPaletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = query.lowercased()
        var items: [CommandPaletteSuggestion]

        switch commandPaletteMode {
        case .addGitlab:
            items = gitlabSuggestions
                .filter { lower.isEmpty || $0.title.lowercased().contains(lower) || "\($0.id)".contains(lower) }
                .map { .gitlab($0) }
        case .addJira:
            items = jiraSuggestions
                .filter { lower.isEmpty || $0.summary.lowercased().contains(lower) || $0.key.lowercased().contains(lower) }
                .map { .jira($0) }
        case .root:
            items = []
        }

        if !query.isEmpty && commandPaletteMode != .root {
            items.insert(.rawInput(query), at: 0)
        }

        return items
    }

    func loadCommandPaletteSuggestions() {
        guard commandPaletteMode != .root else { return }
        commandPaletteIsLoading = true

        Task {
            do {
                switch commandPaletteMode {
                case .addGitlab:
                    let items = try await apiClient.fetchRecentGitlabMergeRequests(limit: 20)
                    gitlabSuggestions = items
                case .addJira:
                    let items = try await apiClient.fetchRecentJiraIssues(limit: 20, scope: .both)
                    jiraSuggestions = items
                case .root:
                    break
                }
                commandPaletteIsLoading = false
            } catch {
                commandPaletteIsLoading = false
                showToast(message: error.localizedDescription)
            }
        }
    }

    func selectCommandPaletteAction(_ action: CommandPaletteAction) {
        switch action {
        case .addGitlab:
            commandPaletteMode = .addGitlab
        case .addJira:
            commandPaletteMode = .addJira
        }
        commandPaletteQuery = ""
        commandPaletteSelectionIndex = 0
        loadCommandPaletteSuggestions()
    }

    func submitCommandPaletteSelection() {
        guard let task = selectedTask else {
            showToast(message: "Select a task to add a link.")
            closeCommandPalette()
            return
        }

        switch commandPaletteMode {
        case .root:
            let actions = filteredCommandPaletteActions
            guard let action = actions[safe: commandPaletteSelectionIndex] else { return }
            selectCommandPaletteAction(action)
        case .addGitlab:
            let items = filteredCommandPaletteSuggestions
            guard let item = items[safe: commandPaletteSelectionIndex] else { return }
            handleCommandPaletteSelection(item: item, provider: .gitlab, taskUUID: task.uuid)
        case .addJira:
            let items = filteredCommandPaletteSuggestions
            guard let item = items[safe: commandPaletteSelectionIndex] else { return }
            handleCommandPaletteSelection(item: item, provider: .jira, taskUUID: task.uuid)
        }
    }

    func moveCommandPaletteSelection(delta: Int, maxCount: Int) {
        guard maxCount > 0 else {
            commandPaletteSelectionIndex = 0
            return
        }
        let next = max(0, min(commandPaletteSelectionIndex + delta, maxCount - 1))
        commandPaletteSelectionIndex = next
    }

    private func handleCommandPaletteSelection(
        item: CommandPaletteSuggestion,
        provider: ExternalLinkProvider,
        taskUUID: String
    ) {
        commandPaletteIsLoading = true
        Task {
            do {
                let url: String
                switch item {
                case .gitlab(let mr):
                    url = mr.webURL
                case .jira(let issue):
                    url = issue.webURL
                case .rawInput(let value):
                    let resolved = try await apiClient.resolveExternalLink(provider: provider, input: value)
                    url = resolved.url
                }

                _ = try await apiClient.addExternalLink(taskUUID: taskUUID, url: url)
                commandPaletteIsLoading = false
                showToast(message: "Link added.")
                closeCommandPalette()
            } catch {
                commandPaletteIsLoading = false
                showToast(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Completion Methods

    /// Load all completion data from the API at startup.
    func loadCompletionData() async {
        guard !completionsLoaded else { return }

        do {
            completionCache = try await actionService.fetchCompletions()
            completionsLoaded = true
            updateCompletions()
            logger.info("Completions loaded: \(self.completionCache.projects.count) projects, \(self.completionCache.tags.count) tags, \(self.completionCache.actions.count) actions")
        } catch {
            logger.error("Failed to load completions: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Detect the completion context based on the current input and cursor position.
    func detectCompletionContext() -> CompletionContext {
        CompletionEngine.detectContext(input: input, cursorPosition: cursorPosition, tokens: tokens)
    }

    /// Update completions based on the current context and prefix.
    func updateCompletions() {
        let context = detectCompletionContext()
        completionContext = context
        let prefix = CompletionEngine.currentPrefix(
            input: input,
            cursorPosition: cursorPosition
        ).lowercased()
        let result = CompletionEngine.buildCompletions(
            context: context,
            prefix: prefix,
            cache: completionCache,
            tasks: tasks
        )
        completions = result.items
        ghostText = result.ghostText
        if context == .none {
            return
        }
        selectedCompletionIndex = 0
    }

    /// Accept the currently selected completion.
    func acceptCompletion(_ item: CompletionItem? = nil) {
        let completionItem = item ?? completions[safe: selectedCompletionIndex]
        guard let completion = completionItem else { return }

        let result = CompletionEngine.applyCompletion(
            input: input,
            cursorPosition: cursorPosition,
            completion: completion
        )
        suppressInputHandling = true
        input = result.text
        cursorPosition = result.cursorPosition
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
