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
    @Published var reportConfig: ReportConfig?
    @Published var toasts: [ToastMessage] = []

    // MARK: - Completion State
    @Published var completions: [CompletionItem] = []
    @Published var selectedCompletionIndex: Int = 0
    @Published var showCompletionMenu: Bool = false
    @Published var ghostText: String?
    @Published var completionContext: CompletionContext = .none
    @Published var cursorPosition: Int = 0

    private let actionService: LauncherActionService
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
            tasks = TaskListCoordinator.sortTasksByUrgency(response.tasks)
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

    /// Move the selection by a delta, wrapping around the list.
    func moveSelection(delta: Int) {
        selectedIndex = TaskListCoordinator.moveSelection(
            tasks: tasks,
            selectedIndex: selectedIndex,
            delta: delta
        )
    }

    /// Keep selection within bounds after tasks update.
    func syncSelectionAfterTasksUpdate() {
        selectedIndex = TaskListCoordinator.syncSelection(tasks: tasks, selectedIndex: selectedIndex)
    }

    /// Sort tasks by urgency, highest first, keeping nil urgency last.
    func sortTasksByUrgency(_ items: [ApiTask]) -> [ApiTask] {
        TaskListCoordinator.sortTasksByUrgency(items)
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

    // MARK: - Completion Methods

    /// Load all completion data from the API at startup.
    func loadCompletionData() async {
        guard !completionsLoaded else { return }
        completionsLoaded = true

        do {
            completionCache = try await actionService.fetchCompletions()
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
