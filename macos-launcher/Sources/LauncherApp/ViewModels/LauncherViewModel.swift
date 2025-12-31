import AppKit
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
    @Published private(set) var interactionContext: InteractionContext = .list(selection: .none, isInsertMode: true)
    @Published private(set) var hintModel: BottomHintModel = BottomHintModelBuilder.model(
        for: .list(selection: .none, isInsertMode: true)
    )
    @Published var reportConfig: ReportConfig?
    @Published var availableReports: [ReportSummary] = []
    @Published var selectedReportName: String = UserDefaults.standard
        .string(forKey: UserDefaultsKeys.selectedReportName) ?? ""
    @Published private(set) var reportFilterChips: [CriteriaChip] = []
    @Published private(set) var taskDetailState = TaskDetailState()
    @Published private(set) var externalLinksState = ExternalLinksState()
    @Published var toasts: [ToastMessage] = []
    let commandPalette: CommandPaletteCoordinator

    // MARK: - Completion State

    let completion: CompletionCoordinator

    // MARK: - Grouping State

    /// The current grouping strategy.
    @Published var groupingStrategy: TaskGroupingStrategy = ProjectGroupingStrategy()
    /// Set of collapsed group keys.
    @Published var collapsedGroups: Set<String?> = []

    // MARK: - Task Expansion State

    /// Set of expanded task UUIDs (for inline link/annotation preview).
    @Published var expandedTasks: Set<String> = []
    /// Loaded expanded content per task UUID.
    @Published var taskExpandedData: [String: TaskExpandedContent] = [:]

    // MARK: - Project Scope State
    /// The currently scoped project (layers on top of report filters).
    @Published var projectScope: String?

    /// The current grouping option for UI display.
    var currentGroupByOption: GroupByOption {
        switch groupingStrategy {
        case is ProjectGroupingStrategy: .project
        case is DueDateGroupingStrategy: .dueDate
        case is TagGroupingStrategy: .tag
        case is NoGroupingStrategy: .none
        default: .project
        }
    }

    /// Currently hovered row index (for collapse toggle).
    @Published var hoveredRowIndex: Int?
    /// Currently selected row index in grouped view.
    @Published var selectedRowIndex: Int?
    private var lastSelectedRowIndex: Int?

    private let actionService: LauncherActionService
    private let apiClient: ApiClientProtocol
    private var requestCounter: Int = 0
    private var latestParse: ParseResponse?
    private var lastSuccessfulParse: ParseResponse?
    private var lastParseErrorMessage: String?
    private let logger = Logger(subsystem: "bee.macos-launcher", category: "view-model")
    private var suppressInputHandling = false
    private var configLoaded = false
    private let unexpectedTokenToastDelay: TimeInterval
    private var cancellables: Set<AnyCancellable> = []
    let windowClose = PassthroughSubject<Void, Never>()
    private lazy var parseErrorToastScheduler = ParseErrorToastScheduler(
        delay: unexpectedTokenToastDelay,
        shouldDefer: { [weak self] in
            self?.completion.showMenu ?? false
        },
        isRequestCurrent: { [weak self] requestId in
            guard let self else { return false }
            return requestId == requestCounter
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
        commandPalette = CommandPaletteCoordinator()
        completion = CompletionCoordinator()

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

        loadGroupingStrategy()
        setupInteractionContextUpdates()
        setupCommandPaletteContributors()
    }

    private func setupCommandPaletteContributors() {
        // Register the shortcuts section (always visible)
        commandPalette.dataSource.register(ShortcutsSectionContributor())

        // Register the actions section with handlers
        let actionHandler = CommandPaletteActionHandler(viewModel: self, apiClient: apiClient)
        commandPalette.dataSource.register(ActionsSectionContributor(actionHandler: actionHandler))

        // Register the group-by section
        commandPalette.dataSource.register(GroupBySectionContributor(
            currentGroupBy: { [weak self] in self?.currentGroupByOption ?? .project },
            onGroupBySelect: { [weak self] option in self?.setGroupingStrategy(option) }
        ))

        // Register the go-to section for project navigation
        commandPalette.dataSource.register(GoToSectionContributor(
            currentProjectScope: { [weak self] in self?.projectScope },
            onProjectSelect: { [weak self] project in
                self?.setProjectScope(project)
                self?.closeCommandPalette()
            }
        ))
    }

    private func setupInteractionContextUpdates() {
        let baseContextPublisher = Publishers.CombineLatest4(
            $mode,
            $selectedRowIndex,
            $tasks,
            $collapsedGroups
        )
        .map { [weak self] mode, selectedRowIndex, tasks, collapsedGroups in
            guard let self else {
                return BaseInteractionContext.list(selection: .none)
            }
            let rows = TaskListCoordinator.groupTasks(
                tasks,
                using: groupingStrategy,
                collapsedKeys: collapsedGroups
            )
            return InteractionContextCoordinator.baseContext(
                mode: mode,
                selectedRowIndex: selectedRowIndex,
                rows: rows
            )
        }

        Publishers.CombineLatest4(
            baseContextPublisher,
            completion.$showMenu,
            commandPalette.$isPresented,
            $isInsertMode
        )
        .map { baseContext, showCompletionMenu, commandPalettePresented, isInsertMode in
            InteractionContextCoordinator.interactionContext(
                base: baseContext,
                showCompletionMenu: showCompletionMenu,
                commandPalettePresented: commandPalettePresented,
                isInsertMode: isInsertMode
            )
        }
        .removeDuplicates()
        .sink { [weak self] context in
            self?.interactionContext = context
            self?.hintModel = BottomHintModelBuilder.model(for: context)
        }
        .store(in: &cancellables)
    }

    /// Fetch the report configuration from the API.
    func loadConfig() async {
        guard !configLoaded else { return }
        configLoaded = true
        do {
            let configResponse = try await actionService.loadFullConfig()
            availableReports = configResponse.reports

            // Determine which report to use
            let reportName = selectedReportName.isEmpty
                ? configResponse.reports.first(where: { $0.isDefault })?.name ?? ""
                : selectedReportName

            if let selected = configResponse.reports.first(where: { $0.name == reportName }) {
                reportConfig = ReportConfig(
                    filters: selected.filters,
                    columns: selected.columns,
                    columnNames: selected.columnNames
                )
                selectedReportName = reportName
            } else {
                reportConfig = configResponse.report
            }

            actionService.setReportConfig(reportConfig)
            await refreshReportFilterChips()
            logger.info("Config loaded: \(self.reportConfig?.columns.count ?? 0) columns, \(self.availableReports.count) reports")
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
            // Use default config on failure
            reportConfig = ReportConfig(
                filters: ["status:pending or status:active"],
                columns: ["id", "summary", "tags", "status"],
                columnNames: ["ID", "Summary", "Tags", "Status"]
            )
            await refreshReportFilterChips()
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
            lastSuccessfulParse = parsed
            lastParseErrorMessage = nil
            tokens = parsed.tokens
            actionName = parsed.action
            cancelPendingParseErrorToast()
            logger.debug("Parse request done. id=\(requestId), action=\(parsed.action)")

            if shouldAutoList(actionName: parsed.action) {
                await runAction(from: parsed, requestId: requestId, resetInput: false, updateStatus: false)
            } else if shouldPreviewList(actionName: parsed.action) {
                let preview = ParseResponse(
                    action: "list",
                    properties: nil,
                    filter: parsed.filter,
                    tokens: parsed.tokens
                )
                await runAction(from: preview, requestId: requestId, resetInput: false, updateStatus: false)
            }
        } catch {
            guard requestId == requestCounter else { return }
            latestParse = nil
            lastParseErrorMessage = error.localizedDescription
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
            let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedInput.isEmpty, latestParse == nil {
                cancelPendingParseErrorToast()
                showToast(message: lastParseErrorMessage ?? "Invalid request")
                return
            }
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
            let response = try await actionService.runAction(
                parsed: parsed,
                actionName: actionName,
                projectScope: projectScope
            )
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
            logger
                .error("Action request failed. id=\(requestId), error=\(error.localizedDescription, privacy: .public)")
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

    func copyBranchNameToClipboard(_ branch: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(branch, forType: .string)
        showToast(message: "Copied branch name to clipboard", icon: .gitlab)
    }

    func copyLinkToClipboard(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        showToast(message: "Copied link to clipboard", icon: .gitlab)
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
        exitInsertMode(restoreSelection: false)
        let rows = groupedRows
        let nextIndex = TaskListCoordinator.moveGroupedSelection(
            rows: rows,
            currentRowIndex: selectedRowIndex,
            delta: delta
        )
        updateSelection(rowIndex: nextIndex, rows: rows)
    }

    /// Select the first row in the list.
    func selectFirstRow() {
        let rows = groupedRows
        guard !rows.isEmpty else { return }
        exitInsertMode(restoreSelection: false)
        updateSelection(rowIndex: 0, rows: rows)
    }

    /// Select the last row in the list.
    func selectLastRow() {
        let rows = groupedRows
        guard !rows.isEmpty else { return }
        exitInsertMode(restoreSelection: false)
        updateSelection(rowIndex: rows.count - 1, rows: rows)
    }

    /// Enter insert mode, focusing the text input.
    func enterInsertMode() {
        lastSelectedRowIndex = selectedRowIndex
        isInsertMode = true
        updateSelection(rowIndex: nil)
    }

    func exitInsertMode(restoreSelection: Bool = true) {
        guard isInsertMode else { return }
        isInsertMode = false
        if restoreSelection, selectedRowIndex == nil, let lastSelectedRowIndex {
            updateSelection(rowIndex: lastSelectedRowIndex)
        }
    }

    func selectRow(_ rowIndex: Int) {
        exitInsertMode(restoreSelection: false)
        updateSelection(rowIndex: rowIndex)
    }

    func activatePrimary(at rowIndex: Int) {
        let rows = groupedRows
        guard rowIndex >= 0, rowIndex < rows.count else { return }
        exitInsertMode(restoreSelection: false)
        updateSelection(rowIndex: rowIndex, rows: rows)
        switch rows[rowIndex] {
        case let .header(header):
            toggleGroupCollapse(header.key)
        case .task:
            openDetail()
        }
    }

    private func updateSelection(rowIndex: Int?, rows: [GroupedListRow]? = nil) {
        let currentRows = rows ?? groupedRows
        selectedRowIndex = rowIndex
        if let rowIndex, rowIndex < currentRows.count {
            if case let .task(item) = currentRows[rowIndex] {
                selectedIndex = item.flatIndex
            }
        } else {
            selectedIndex = nil
        }
        if !isInsertMode {
            lastSelectedRowIndex = rowIndex
        }
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
        guard let idx,
              idx < rows.count,
              case let .header(h) = rows[idx]
        else {
            return false
        }
        toggleGroupCollapse(h.key)
        return true
    }

    func canToggleSelectedOrHoveredGroupCollapse() -> Bool {
        let rows = groupedRows
        let idx = selectedRowIndex ?? hoveredRowIndex
        guard let idx, idx < rows.count else { return false }
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

    /// Set the grouping strategy and persist the selection.
    func setGroupingStrategy(_ option: GroupByOption) {
        // Clear collapsed state - keys won't match new strategy
        collapsedGroups.removeAll()

        groupingStrategy = option.makeStrategy()

        // Persist selection
        UserDefaults.standard.set(option.rawValue, forKey: UserDefaultsKeys.selectedGroupBy)

        // Clear old collapsed state persistence
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.collapsedGroups)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.collapsedNilGroup)

        // Close command palette after selection
        commandPalette.close()
    }

    /// Load the persisted grouping strategy.
    func loadGroupingStrategy() {
        let rawValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedGroupBy)
        let option = rawValue.flatMap { GroupByOption(rawValue: $0) } ?? .project
        groupingStrategy = option.makeStrategy()
    }

    // MARK: - Task Expansion Methods

    /// Toggle expansion for a task. If expanding and data not loaded, triggers load.
    func toggleTaskExpansion(_ taskUUID: String) {
        if expandedTasks.contains(taskUUID) {
            expandedTasks.remove(taskUUID)
        } else {
            expandedTasks.insert(taskUUID)
            // Load data if not already loaded
            if taskExpandedData[taskUUID] == nil {
                loadExpandedContent(for: taskUUID)
            }
        }
    }

    /// Check if a task is expanded.
    func isTaskExpanded(_ taskUUID: String) -> Bool {
        expandedTasks.contains(taskUUID)
    }

    /// Toggle expansion for the currently selected or hovered task. Returns true if toggled.
    func toggleSelectedOrHoveredTaskExpansion() -> Bool {
        let rows = groupedRows
        let idx = selectedRowIndex ?? hoveredRowIndex
        guard let idx,
              idx < rows.count,
              case let .task(item) = rows[idx]
        else {
            return false
        }
        toggleTaskExpansion(item.task.uuid)
        return true
    }

    /// Check if the currently selected or hovered row is an expandable task.
    func canToggleSelectedOrHoveredTaskExpansion() -> Bool {
        let rows = groupedRows
        let idx = selectedRowIndex ?? hoveredRowIndex
        guard let idx, idx < rows.count else { return false }
        if case .task = rows[idx] {
            return true
        }
        return false
    }

    /// Load expanded content (links + annotations) for a task.
    private func loadExpandedContent(for taskUUID: String) {
        // Mark as loading with timestamp for delayed indicator
        taskExpandedData[taskUUID] = TaskExpandedContent(isLoading: true, loadingStartedAt: Date())

        Task {
            do {
                // Load both detail (for annotations) and external links in parallel
                async let detailTask = apiClient.fetchTaskDetail(taskUUID: taskUUID)
                async let linksTask = apiClient.fetchExternalLinks(taskUUID: taskUUID)

                let detail = try await detailTask
                let links = try await linksTask

                taskExpandedData[taskUUID] = TaskExpandedContent(
                    isLoading: false,
                    links: links,
                    annotations: detail.annotations,
                    errorMessage: nil
                )
            } catch {
                taskExpandedData[taskUUID] = TaskExpandedContent(
                    isLoading: false,
                    links: [],
                    annotations: [],
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    // MARK: - Project Scope Methods

    /// Set the project scope and refresh the task list.
    func setProjectScope(_ project: String) {
        projectScope = project
        handleInputChange(input)
    }

    /// Clear the project scope and refresh the task list.
    func clearProjectScope() {
        projectScope = nil
        handleInputChange(input)
    }

    /// Keep selection within bounds after tasks update.
    func syncSelectionAfterTasksUpdate() {
        selectedIndex = TaskListCoordinator.syncSelection(tasks: tasks, selectedIndex: selectedIndex)
        if let selectedIndex {
            let rows = groupedRows
            let rowIndex = rows.firstIndex { row in
                if case let .task(item) = row {
                    return item.flatIndex == selectedIndex
                }
                return false
            }
            updateSelection(rowIndex: rowIndex, rows: rows)
        } else {
            updateSelection(rowIndex: nil)
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
            if let task = selectedTask {
                loadTaskDetail(taskUUID: task.uuid)
                loadExternalLinks(taskUUID: task.uuid)
            }
        }
    }

    /// Close the detail view and return to the list.
    func closeDetail() {
        mode = NavigationCoordinator.modeForCloseDetail()
        taskDetailState = TaskDetailState()
        externalLinksState = ExternalLinksState()
    }

    /// Return the currently selected task.
    var selectedTask: ApiTask? {
        TaskListCoordinator.selectedTask(tasks: tasks, selectedIndex: selectedIndex)
    }

    /// Display name for the current report.
    var currentReportDisplayName: String {
        if selectedReportName.isEmpty {
            return availableReports.first(where: { $0.isDefault })?.name ?? "default"
        }
        return selectedReportName
    }

    var criteriaFilterChips: [CriteriaChip] {
        var chips = reportFilterChips
        if let parsed = lastSuccessfulParse {
            let parsedChips = CriteriaChipBuilder.filterChips(from: parsed.filter)
            if parsedChips.isEmpty, shouldAutoList(actionName: parsed.action) {
                chips.append(contentsOf: CriteriaChipBuilder.filterChips(
                    from: parsed.tokens,
                    actionName: parsed.action
                ))
            } else if !parsedChips.isEmpty {
                chips.append(contentsOf: parsedChips)
            }
        }
        return deduplicateChips(chips)
    }

    var criteriaPropertyChips: [CriteriaChip] {
        guard let parsed = lastSuccessfulParse else { return [] }
        return CriteriaChipBuilder.propertyChips(from: parsed.properties)
    }

    /// Chip representing the current project scope, if any.
    var projectScopeChip: CriteriaChip? {
        guard let project = projectScope else { return nil }
        return CriteriaChip(kind: .filter, label: project, systemImage: "folder", tone: .teal)
    }

    func refreshReportFilterChips() async {
        guard let reportConfig else {
            reportFilterChips = []
            return
        }
        let filterExpr = reportConfig.filters.joined(separator: " or ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filterExpr.isEmpty else {
            reportFilterChips = []
            return
        }

        do {
            let parsed = try await actionService.parse(input: "list \(filterExpr)")
            let parsedChips = CriteriaChipBuilder.filterChips(from: parsed.filter)
            let fallbackChips = CriteriaChipBuilder.filterChips(from: parsed.tokens, actionName: parsed.action)
            reportFilterChips = deduplicateChips(parsedChips.isEmpty ? fallbackChips : parsedChips)
        } catch {
            logger.error("Failed to parse report filters: \(error.localizedDescription, privacy: .public)")
            reportFilterChips = CriteriaChipBuilder.reportFilterChips(from: reportConfig)
        }
    }

    private func deduplicateChips(_ chips: [CriteriaChip]) -> [CriteriaChip] {
        var seen = Set<String>()
        var result: [CriteriaChip] = []
        for chip in chips {
            if seen.insert(chip.id).inserted {
                result.append(chip)
            }
        }
        return result
    }

    /// Select a report by name and refresh the task list.
    func selectReport(_ name: String) {
        guard let report = availableReports.first(where: { $0.name == name }) else { return }
        selectedReportName = name
        UserDefaults.standard.set(name, forKey: UserDefaultsKeys.selectedReportName)
        reportConfig = ReportConfig(
            filters: report.filters,
            columns: report.columns,
            columnNames: report.columnNames
        )
        actionService.setReportConfig(reportConfig)
        Task {
            await refreshReportFilterChips()
        }
        // Refresh task list with new report filters
        handleInputChange(input)
    }

    func loadTaskDetail(taskUUID: String) {
        if taskDetailState.isLoading, taskDetailState.detail?.uuid == taskUUID {
            return
        }
        let currentDetail = taskDetailState.detail?.uuid == taskUUID ? taskDetailState.detail : nil
        taskDetailState = TaskDetailState(
            isLoading: true,
            taskUUID: taskUUID,
            detail: currentDetail,
            errorMessage: nil
        )
        Task {
            do {
                let detail = try await apiClient.fetchTaskDetail(taskUUID: taskUUID)
                taskDetailState = TaskDetailState(
                    isLoading: false,
                    taskUUID: taskUUID,
                    detail: detail,
                    errorMessage: nil
                )
            } catch {
                taskDetailState = TaskDetailState(
                    isLoading: false,
                    taskUUID: taskUUID,
                    detail: nil,
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    func loadExternalLinks(taskUUID: String) {
        if externalLinksState.isLoading, externalLinksState.taskUUID == taskUUID {
            return
        }
        externalLinksState = ExternalLinksState(isLoading: true, taskUUID: taskUUID)
        Task {
            do {
                let links = try await apiClient.fetchExternalLinks(taskUUID: taskUUID)
                externalLinksState = ExternalLinksState(
                    isLoading: false,
                    taskUUID: taskUUID,
                    links: links,
                    errorMessage: nil,
                    refreshingProviders: []
                )
            } catch {
                externalLinksState = ExternalLinksState(
                    isLoading: false,
                    taskUUID: taskUUID,
                    links: [],
                    errorMessage: error.localizedDescription,
                    refreshingProviders: []
                )
            }
        }
    }

    func refreshExternalLinks(provider: ExternalLinkProvider) {
        guard let task = selectedTask else { return }
        if externalLinksState.taskUUID != task.uuid {
            loadExternalLinks(taskUUID: task.uuid)
            return
        }
        let linksToSync = externalLinksState.links.filter { $0.provider.lowercased() == provider.rawValue }
        guard !linksToSync.isEmpty else { return }

        externalLinksState.refreshingProviders.insert(provider)
        Task {
            defer {
                externalLinksState.refreshingProviders.remove(provider)
            }
            do {
                for link in linksToSync {
                    _ = try await apiClient.syncExternalLink(linkId: link.id, force: true)
                }
                loadExternalLinks(taskUUID: task.uuid)
            } catch {
                externalLinksState.errorMessage = error.localizedDescription
            }
        }
    }

    /// Return true if we should automatically run the list action while typing.
    func shouldAutoList(actionName: String) -> Bool {
        actionName.isEmpty || actionName.lowercased() == "list"
    }

    /// Return true if we should preview a list while typing a non-list action.
    func shouldPreviewList(actionName: String) -> Bool {
        !shouldAutoList(actionName: actionName)
    }

    /// Build a status message from API events.
    func buildStatusMessage(from events: [ApiEvent]) -> String? {
        guard !events.isEmpty else { return nil }
        return events.map(\.message).joined(separator: " ")
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
        lastSuccessfulParse = nil
        clearCompletions()
        suppressInputHandling = false
    }

    // MARK: - Command Palette

    func openCommandPalette() {
        let context = CommandPaletteContext(
            hasSelectedTask: selectedTask != nil,
            selectedTaskUUID: selectedTask?.uuid,
            currentReportName: selectedReportName,
            availableReports: availableReports,
            projects: completion.projectNames,
            tags: completion.tagNames,
            currentProjectScope: projectScope
        )
        if let message = commandPalette.open(context: context) {
            showToast(message: message)
        }
    }

    func closeCommandPalette() {
        commandPalette.close()
    }

    func submitCommandPaletteSelection() {
        commandPalette.handleEnter()
    }

    func moveCommandPaletteSelection(delta: Int) {
        commandPalette.moveSelection(delta: delta)
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
        if interactionContext == .commandPalette {
            if commandPalette.handleEscape() {
                return true
            }
            closeCommandPalette()
            return true
        }

        let action = InteractionCoordinator.escapeAction(for: interactionContext)
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
            exitInsertMode()
            return true
        case .closeWindow:
            windowClose.send()
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
        case let .moveSelection(delta):
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
        case .toggleTaskExpansion:
            return toggleSelectedOrHoveredTaskExpansion()
        case .openDetail:
            openDetail()
            return true
        case .openCommandPalette:
            openCommandPalette()
            return true
        case .none:
            return false
        }
    }
}

struct TaskDetailState {
    var isLoading: Bool = false
    var taskUUID: String?
    var detail: ApiTaskDetail?
    var errorMessage: String?
}

struct ExternalLinksState {
    var isLoading: Bool = false
    var taskUUID: String?
    var links: [ExternalLinkDto] = []
    var errorMessage: String?
    var refreshingProviders: Set<ExternalLinkProvider> = []
}

/// Content loaded for an expanded task row (inline preview of links/annotations).
struct TaskExpandedContent {
    var isLoading: Bool = true
    var loadingStartedAt: Date?
    var links: [ExternalLinkDto] = []
    var annotations: [TaskAnnotationDto] = []
    var errorMessage: String?

    var isEmpty: Bool {
        links.isEmpty && annotations.isEmpty
    }

    /// Only show loading indicator after 1 second to avoid flicker for fast responses
    var shouldShowLoading: Bool {
        guard isLoading, let startedAt = loadingStartedAt else { return false }
        return Date().timeIntervalSince(startedAt) >= 1.0
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
