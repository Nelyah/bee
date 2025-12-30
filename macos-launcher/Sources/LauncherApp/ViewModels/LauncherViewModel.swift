import Combine
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
    let commandPalette: CommandPaletteCoordinator

    // MARK: - Completion State
    let completion: CompletionCoordinator

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
    private var cancellables: Set<AnyCancellable> = []
    private lazy var parseErrorToastScheduler = ParseErrorToastScheduler(
        delay: unexpectedTokenToastDelay,
        shouldDefer: { [weak self] in
            self?.completion.showMenu ?? false
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

    init(
        apiClient: ApiClientProtocol = ApiClient(),
        actionService: LauncherActionService? = nil,
        unexpectedTokenToastDelay: TimeInterval = Constants.defaultUnexpectedTokenToastDelay
    ) {
        self.apiClient = apiClient
        self.actionService = actionService ?? LauncherActionService(apiClient: apiClient)
        self.unexpectedTokenToastDelay = unexpectedTokenToastDelay
        self.commandPalette = CommandPaletteCoordinator()
        self.completion = CompletionCoordinator()

        commandPalette.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        completion.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
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
    @discardableResult
    func showToast(
        message: String,
        icon: ToastIcon = .warning,
        duration: TimeInterval = Constants.defaultToastDuration
    ) -> UUID {
        let toast = ToastMessage(message: message, icon: icon)
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
        return toast.id
    }

    func removeToast(id: UUID) {
        withAnimation(.easeInOut(duration: Constants.toastAnimationDuration)) {
            toasts.removeAll { $0.id == id }
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

    func canToggleSelectedOrHoveredGroupCollapse() -> Bool {
        let rows = groupedRows
        let idx = selectedRowIndex ?? hoveredRowIndex
        guard let idx = idx, idx < rows.count else { return false }
        if case .header = rows[idx] {
            return true
        }
        return false
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
        if let message = commandPalette.open(hasSelectedTask: selectedTask != nil) {
            showToast(message: message)
        }
    }

    func closeCommandPalette() {
        commandPalette.close()
    }

    var filteredCommandPaletteActions: [CommandPaletteAction] {
        commandPalette.filteredActions
    }

    var filteredCommandPaletteSuggestions: [CommandPaletteSuggestion] {
        commandPalette.filteredSuggestions
    }

    func loadCommandPaletteSuggestions() {
        guard commandPalette.mode != .root else { return }

        Task {
            if let errorMessage = await commandPalette.loadSuggestions(apiClient: apiClient) {
                showToast(message: errorMessage)
            }
        }
    }

    func selectCommandPaletteAction(_ action: CommandPaletteAction) {
        commandPalette.selectAction(action)
        loadCommandPaletteSuggestions()
    }

    func submitCommandPaletteSelection() {
        guard let task = selectedTask else {
            showToast(message: "Select a task to add a link.")
            closeCommandPalette()
            return
        }

        switch commandPalette.mode {
        case .root:
            let actions = filteredCommandPaletteActions
            guard let action = actions[safe: commandPalette.selectionIndex] else { return }
            selectCommandPaletteAction(action)
        case .addGitlab:
            let items = filteredCommandPaletteSuggestions
            guard let item = items[safe: commandPalette.selectionIndex] else { return }
            handleCommandPaletteSelection(item: item, provider: .gitlab, taskUUID: task.uuid)
        case .addJira:
            let items = filteredCommandPaletteSuggestions
            guard let item = items[safe: commandPalette.selectionIndex] else { return }
            handleCommandPaletteSelection(item: item, provider: .jira, taskUUID: task.uuid)
        }
    }

    func moveCommandPaletteSelection(delta: Int, maxCount: Int) {
        commandPalette.moveSelection(delta: delta, maxCount: maxCount)
    }

    private func handleCommandPaletteSelection(
        item: CommandPaletteSuggestion,
        provider: ExternalLinkProvider,
        taskUUID: String
    ) {
        let pendingToastId = showToast(
            message: provider == .gitlab ? "Adding Gitlab link…" : "Adding link…",
            icon: provider == .gitlab ? .gitlab : .warning,
            duration: Constants.defaultToastDuration
        )
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
                removeToast(id: pendingToastId)
                if provider == .gitlab {
                    showToast(message: "Gitlab link added", icon: .gitlab)
                } else {
                    showToast(message: "Link added.")
                }
                closeCommandPalette()
            } catch {
                removeToast(id: pendingToastId)
                showToast(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Completion Methods

    /// Load all completion data from the API at startup.
    func loadCompletionData() async {
        if let errorMessage = await completion.loadData(actionService: actionService) {
            logger.error("Failed to load completions: \(errorMessage, privacy: .public)")
            return
        }
        completion.update(input: input, tokens: tokens, tasks: tasks)
        let counts = completion.cacheCounts
        logger.info("Completions loaded: \(counts.projects) projects, \(counts.tags) tags, \(counts.actions) actions")
    }

    /// Update completions based on the current context and prefix.
    func updateCompletions() {
        completion.update(input: input, tokens: tokens, tasks: tasks)
    }

    /// Accept the currently selected completion.
    func acceptCompletion(_ item: CompletionItem? = nil) {
        guard let result = completion.applyCompletion(item, input: input) else { return }
        suppressInputHandling = true
        input = result.text
        completion.cursorPosition = result.cursorPosition
        suppressInputHandling = false

        clearCompletions()

        // Re-parse after completion
        handleInputChange(input)
    }

    /// Accept the ghost text completion (Tab key).
    func acceptGhostText() {
        if let item = completion.acceptGhostText() {
            acceptCompletion(item)
        }
    }

    /// Toggle the completion menu visibility.
    func toggleCompletionMenu() {
        completion.toggleMenu(input: input, tokens: tokens, tasks: tasks)
    }

    /// Move completion selection up/down.
    func moveCompletionSelection(delta: Int) {
        completion.moveSelection(delta: delta)
    }

    /// Clear all completion state.
    func clearCompletions() {
        completion.clear()
        schedulePendingParseErrorAfterMenuClose()
    }

    /// Handle cursor position changes from the text view.
    func handleCursorChange(_ position: Int) {
        completion.updateCursorPosition(position, input: input, tokens: tokens, tasks: tasks)
    }

    @discardableResult
    func handleEscape() -> Bool {
        let action = InteractionCoordinator.escapeAction(
            isCommandPalettePresented: commandPalette.isPresented,
            showCompletionMenu: completion.showMenu,
            mode: mode
        )
        switch action {
        case .closeCommandPalette:
            closeCommandPalette()
            return true
        case .clearCompletions:
            clearCompletions()
            return true
        case .closeDetail:
            closeDetail()
            return true
        case .exitInsertMode:
            isInsertMode = false
            return true
        case .none:
            return false
        }
    }

    @discardableResult
    func handleNormalModeAction(_ action: NormalModeAction) -> Bool {
        let effect = InteractionCoordinator.normalModeEffect(
            action: action,
            canToggleGroupCollapse: canToggleSelectedOrHoveredGroupCollapse()
        )
        switch effect {
        case .enterInsertMode:
            enterInsertMode()
            return true
        case .moveSelection(let delta):
            moveSelection(delta: delta)
            return true
        case .selectFirst:
            selectFirstRow()
            return true
        case .selectLast:
            selectLastRow()
            return true
        case .toggleGroupCollapse:
            return toggleSelectedOrHoveredGroupCollapse()
        case .openDetail:
            openDetail()
            return true
        case .none:
            return false
        }
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
