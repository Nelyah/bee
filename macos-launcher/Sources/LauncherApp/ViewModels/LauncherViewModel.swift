import AppKit
import Combine
import Foundation
import OSLog

import SwiftUI

@MainActor
final class LauncherViewModel: ObservableObject {
    private enum Constants {
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
    @Published var reportFilterChips: [CriteriaChip] = []
    @Published var taskDetailState = TaskDetailState()
    @Published var externalLinksState = ExternalLinksState()
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

    // MARK: - Save Report Sheet State

    /// Whether to show the save report sheet.
    @Published var showingSaveReportSheet: Bool = false

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
    var lastSelectedRowIndex: Int?

    let actionService: LauncherActionService
    let apiClient: ApiClientProtocol
    private var requestCounter: Int = 0
    private var latestParse: ParseResponse?
    var lastSuccessfulParse: ParseResponse?
    private var lastParseErrorMessage: String?
    let logger = Logger(subsystem: "bee.macos-launcher", category: "view-model")
    var suppressInputHandling = false
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

        // Register the save report section
        commandPalette.dataSource.register(SaveReportSectionContributor(
            actionHandler: actionHandler,
            getCurrentFilters: { [weak self] in self?.criteriaFilterChips.map(\.label) ?? [] },
            getUserReports: { [weak self] in self?.availableReports ?? [] }
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
                    staticFilters: selected.staticFilters,
                    userFilter: selected.userFilter,
                    columns: selected.columns,
                    columnNames: selected.columnNames
                )
                selectedReportName = reportName
            } else {
                reportConfig = configResponse.report
            }

            actionService.setReportConfig(reportConfig)
            await refreshReportFilterChips()
            let columnsCount = reportConfig?.columns.count ?? 0
            let reportsCount = availableReports.count
            logger.info("Config loaded: \(columnsCount) columns, \(reportsCount) reports")
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
            // Use default config on failure
            reportConfig = ReportConfig(
                staticFilters: ["status:pending or status:active"],
                columns: ["id", "summary", "tags", "status"],
                columnNames: ["ID", "Summary", "Tags", "Status"]
            )
            await refreshReportFilterChips()
        }
    }

    /// Force-reload the configuration (used after saving/deleting reports).
    func refreshConfig() async {
        do {
            let configResponse = try await actionService.loadFullConfig()
            availableReports = configResponse.reports

            // Preserve current selection if still valid
            if let selected = configResponse.reports.first(where: { $0.name == selectedReportName }) {
                reportConfig = ReportConfig(
                    staticFilters: selected.staticFilters,
                    userFilter: selected.userFilter,
                    columns: selected.columns,
                    columnNames: selected.columnNames
                )
            } else if let defaultReport = configResponse.reports.first(where: { $0.isDefault }) {
                // Fall back to default if current selection no longer exists
                reportConfig = ReportConfig(
                    staticFilters: defaultReport.staticFilters,
                    userFilter: defaultReport.userFilter,
                    columns: defaultReport.columns,
                    columnNames: defaultReport.columnNames
                )
                selectedReportName = defaultReport.name
            }

            actionService.setReportConfig(reportConfig)
            await refreshReportFilterChips()
        } catch {
            logger.error("Failed to refresh config: \(error.localizedDescription, privacy: .public)")
            showToast(message: "Failed to refresh reports: \(error.localizedDescription)")
        }
    }

    /// Save the current filter configuration as a named report.
    func saveReport(
        name: String,
        filter: JSONValue?,
        columns: [String],
        columnNames: [String],
        isUpdate: Bool
    ) async {
        let request = UserReportRequest(
            name: name,
            filter: filter,
            columns: columns,
            columnNames: columnNames
        )

        do {
            if isUpdate {
                _ = try await apiClient.updateUserReport(name: name, request)
            } else {
                _ = try await apiClient.createUserReport(request)
            }
            showToast(message: "Report '\(name)' saved", icon: .success)
            await refreshConfig()
        } catch {
            showToast(message: "Failed to save report: \(error.localizedDescription)")
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

    // MARK: - Parse Error Toast Scheduling

    /// Cancel any pending delayed toast for parse errors.
    private func cancelPendingParseErrorToast() {
        parseErrorToastScheduler.cancel()
    }

    /// Schedule a delayed toast for parse errors if typing has paused.
    private func scheduleParseErrorToast(message: String, requestId: Int) {
        parseErrorToastScheduler.schedule(message: message, requestId: requestId)
    }

    /// If a parse error is pending, schedule it once the menu closes.
    func schedulePendingParseErrorAfterMenuClose() {
        parseErrorToastScheduler.scheduleAfterMenuClose()
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

    // MARK: - Utility Methods

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

    // MARK: - Keyboard Handlers

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

// MARK: - Supporting Types

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
