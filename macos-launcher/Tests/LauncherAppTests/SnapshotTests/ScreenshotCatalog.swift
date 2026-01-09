@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Centralized screenshot catalog for UI/UX review workflow.
///
/// This test class generates screenshots for all major views and states.
/// Images are saved to `__Snapshots__/ScreenshotCatalog/` with predictable names.
///
/// ## Usage by UI/UX Review Agent
///
/// 1. Run specific tests to generate screenshots:
///    ```bash
///    swift test --filter "ScreenshotCatalog/testContentView_listWithTasks"
///    ```
///
/// 2. Or run all catalog screenshots:
///    ```bash
///    swift test --filter "ScreenshotCatalog"
///    ```
///
/// 3. Screenshots are saved to:
///    `Tests/LauncherAppTests/SnapshotTests/__Snapshots__/ScreenshotCatalog/`
///
/// ## Available Screenshots
///
/// ### Content View (Full App)
/// - testContentView_empty
/// - testContentView_listWithTasks
/// - testContentView_listWithSearch
/// - testContentView_detailMode
/// - testContentView_commandPalette
/// - testContentView_withToast
///
/// ### Task List
/// - testTaskList_empty
/// - testTaskList_singleTask
/// - testTaskList_manyTasks
/// - testTaskList_withSelectedTask
///
/// ### Task Row
/// - testTaskRow_pending
/// - testTaskRow_active
/// - testTaskRow_completed
/// - testTaskRow_withTags
/// - testTaskRow_withDueDate
/// - testTaskRow_selected
/// - testTaskRow_expanded
///
/// ### Task Detail
/// - testTaskDetail_basic
/// - testTaskDetail_withAnnotations
/// - testTaskDetail_withExternalLinks
/// - testTaskDetail_loading
///
/// ### Command Palette
/// - testCommandPalette_default
/// - testCommandPalette_withSearch
///
/// ### Components
/// - testComponent_tokenInput_empty
/// - testComponent_tokenInput_withTokens
/// - testComponent_criteriaStrip
/// - testComponent_completionMenu
/// - testComponent_reportMenuButton
///
@MainActor
final class ScreenshotCatalog: SnapshotTestCase {
    // MARK: - Setup

    private var viewModel: LauncherViewModel!
    private var mockApiClient: MockApiClient!

    override func setUp() async throws {
        try await super.setUp()
        mockApiClient = MockApiClient()
        // Use MockSettingsService to avoid reading from real UserDefaults,
        // which could have leftover state from previous test runs
        viewModel = LauncherViewModel(apiClient: mockApiClient, settingsService: MockSettingsService())
        viewModel.reportConfig = MockApiClient.sampleConfig.report
        viewModel.availableReports = MockApiClient.sampleConfig.reports
    }

    override func tearDown() async throws {
        viewModel = nil
        mockApiClient = nil
        try await super.tearDown()
    }

    // MARK: - Content View (Full App)

    func testContentView_empty() {
        viewModel.mode = .list
        viewModel.tasks = []
        let view = ContentView(viewModel: viewModel)
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    func testContentView_listWithTasks() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        let view = ContentView(viewModel: viewModel)
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    func testContentView_listWithSearch() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.input = "list +work status:pending"
        viewModel.tokens = TestHelpers.sampleTokens
        viewModel.actionName = "list"
        let view = ContentView(viewModel: viewModel)
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    func testContentView_detailMode() {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(
            isLoading: false,
            taskUUID: MockApiClient.sampleTasks[0].uuid,
            detail: MockApiClient.sampleTaskDetail
        )
        viewModel.externalLinksState = ExternalLinksState(
            isLoading: false,
            taskUUID: MockApiClient.sampleTasks[0].uuid,
            links: MockApiClient.sampleExternalLinks
        )
        let view = ContentView(viewModel: viewModel)
        assertViewSnapshot(view, size: CGSize(width: 800, height: 600))
    }

    func testContentView_commandPalette() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.openCommandPalette()
        let view = ContentView(viewModel: viewModel)
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    func testContentView_withToast() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.toasts = [
            ToastMessage(id: UUID(), message: "Task marked as done!", icon: .success),
        ]
        let view = ContentView(viewModel: viewModel)
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    // MARK: - Task List

    func testTaskList_empty() {
        viewModel.tasks = []
        let view = TaskListView(viewModel: viewModel, completion: viewModel.completion)
            .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    func testTaskList_singleTask() {
        viewModel.tasks = [MockApiClient.sampleTasks[0]]
        let view = TaskListView(viewModel: viewModel, completion: viewModel.completion)
            .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    func testTaskList_manyTasks() {
        viewModel.tasks = MockApiClient.sampleTasks
        let view = TaskListView(viewModel: viewModel, completion: viewModel.completion)
            .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    func testTaskList_withSelectedTask() {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedRowIndex = 1
        let view = TaskListView(viewModel: viewModel, completion: viewModel.completion)
            .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    func testTaskList_sortedBySummaryAscending() {
        // Tasks in intentionally random order to test sorting
        viewModel.tasks = [
            TestHelpers.makeTask(id: "1", summary: "Zebra task"),
            TestHelpers.makeTask(id: "2", summary: "Apple task"),
            TestHelpers.makeTask(id: "3", summary: "Banana task"),
            TestHelpers.makeTask(id: "4", summary: "cherry task"), // lowercase to test case-insensitivity
            TestHelpers.makeTask(id: "5", summary: "Draft integration"),
            TestHelpers.makeTask(id: "6", summary: "foo wafeowaihf"),
            TestHelpers.makeTask(id: "7", summary: "Create API endpoint"),
        ]
        // Apply ascending sort by summary
        viewModel.sortState = ColumnSortState(column: "summary", direction: .ascending)

        // Wait for Combine to process
        let expectation = XCTestExpectation(description: "Wait for sort")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let view = TaskListView(viewModel: viewModel, completion: viewModel.completion)
            .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    // MARK: - Task Row

    func testTaskRow_pending() {
        let task = TestHelpers.makeTask(id: "1", status: "pending", summary: "Pending task example")
        let view = TaskRow(
            task: task,
            columnConfigs: TestHelpers.standardColumnConfigs,
            isSelected: false
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRow_active() {
        let task = TestHelpers.makeTask(id: "1", status: "active", summary: "Active task example")
        let view = TaskRow(
            task: task,
            columnConfigs: TestHelpers.standardColumnConfigs,
            isSelected: false
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRow_completed() {
        let task = TestHelpers.makeTask(
            id: "1",
            status: "completed",
            summary: "Completed task example",
            dateCompleted: "2024-01-15T10:30:00Z"
        )
        let view = TaskRow(
            task: task,
            columnConfigs: TestHelpers.standardColumnConfigs,
            isSelected: false
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRow_withTags() {
        let task = TestHelpers.makeTask(id: "1", tags: ["urgent", "bug", "frontend"], summary: "Task with tags")
        let view = TaskRow(
            task: task,
            columnConfigs: TestHelpers.standardColumnConfigs,
            isSelected: false
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRow_withDueDate() {
        let task = TestHelpers.makeTask(id: "1", dateDue: "2024-12-31T23:59:59Z", summary: "Task with due date")
        let view = TaskRow(
            task: task,
            columnConfigs: TestHelpers.standardColumnConfigs,
            isSelected: false
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRow_selected() {
        let task = TestHelpers.makeTask(id: "1", summary: "Selected task")
        let view = TaskRow(
            task: task,
            columnConfigs: TestHelpers.standardColumnConfigs,
            isSelected: true
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRow_expanded() {
        let task = TestHelpers.makeTask(
            id: "1",
            project: "backend",
            tags: ["api", "refactor"],
            summary: "Expanded task"
        )
        let expandedContent = TaskExpandedContent(
            isLoading: false,
            loadingStartedAt: nil,
            links: [TestHelpers.makeGitLabMRLink(title: "Add feature")],
            annotations: [TestHelpers.makeAnnotation(value: "Follow up needed")],
            errorMessage: nil
        )
        let view = TaskRow(
            task: task,
            columnConfigs: TestHelpers.standardColumnConfigs,
            isSelected: false,
            isExpanded: true,
            expandedContent: expandedContent,
            onChevronTap: {}
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.taskRowExpanded)
    }

    // MARK: - Task Detail

    func testTaskDetail_basic() {
        let task = MockApiClient.sampleTasks[0]
        let detailState = TaskDetailState()
        let linksState = ExternalLinksState()
        let view = TaskDetailView(
            task: task,
            detailState: detailState,
            externalLinksState: linksState,
            onRetryDetail: {},
            onRefreshLinks: { _ in },
            onCopyBranch: { _ in },
            onCopyLink: { _ in },
            onCopyUUID: { _ in },
            onClose: {},
            annotationInput: .constant(""),
            taskNameEditInput: .constant(""),
            annotationEditInput: .constant(""),
            projectEditInput: .constant(""),
            tagAddQuery: .constant(""),
            dueDateEditSelection: .constant(Date()),
            importantLinkUrlInput: .constant(""),
            importantLinkTitleInput: .constant("")
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.detailViewWide)
    }

    func testTaskDetail_withAnnotations() {
        let task = MockApiClient.sampleTasks[0]
        let detail = TestHelpers.makeTaskDetail(
            id: task.uuid,
            summary: task.summary,
            annotations: [
                TestHelpers.makeAnnotation(value: "Code review complete", time: "2024-01-16T14:30:00Z"),
                TestHelpers.makeAnnotation(value: "Tests passing", time: "2024-01-15T10:00:00Z"),
            ],
            history: [
                TaskHistoryDto(value: "Status changed to active", datetime: "2024-01-14T09:00:00Z"),
            ]
        )
        var detailState = TaskDetailState()
        detailState.taskUUID = task.uuid
        detailState.detail = detail
        let linksState = ExternalLinksState()
        let view = TaskDetailView(
            task: task,
            detailState: detailState,
            externalLinksState: linksState,
            onRetryDetail: {},
            onRefreshLinks: { _ in },
            onCopyBranch: { _ in },
            onCopyLink: { _ in },
            onCopyUUID: { _ in },
            onClose: {},
            annotationInput: .constant(""),
            taskNameEditInput: .constant(""),
            annotationEditInput: .constant(""),
            projectEditInput: .constant(""),
            tagAddQuery: .constant(""),
            dueDateEditSelection: .constant(Date()),
            importantLinkUrlInput: .constant(""),
            importantLinkTitleInput: .constant("")
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.detailViewWide)
    }

    func testTaskDetail_withExternalLinks() {
        let task = MockApiClient.sampleTasks[0]
        let detailState = TaskDetailState()
        var linksState = ExternalLinksState()
        linksState.taskUUID = task.uuid
        linksState.links = MockApiClient.sampleExternalLinks
        let view = TaskDetailView(
            task: task,
            detailState: detailState,
            externalLinksState: linksState,
            onRetryDetail: {},
            onRefreshLinks: { _ in },
            onCopyBranch: { _ in },
            onCopyLink: { _ in },
            onCopyUUID: { _ in },
            onClose: {},
            annotationInput: .constant(""),
            taskNameEditInput: .constant(""),
            annotationEditInput: .constant(""),
            projectEditInput: .constant(""),
            tagAddQuery: .constant(""),
            dueDateEditSelection: .constant(Date()),
            importantLinkUrlInput: .constant(""),
            importantLinkTitleInput: .constant("")
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.detailViewWide)
    }

    func testTaskDetail_loading() {
        let task = MockApiClient.sampleTasks[0]
        var detailState = TaskDetailState()
        detailState.isLoading = true
        detailState.taskUUID = task.uuid
        var linksState = ExternalLinksState()
        linksState.isLoading = true
        linksState.taskUUID = task.uuid
        let view = TaskDetailView(
            task: task,
            detailState: detailState,
            externalLinksState: linksState,
            onRetryDetail: {},
            onRefreshLinks: { _ in },
            onCopyBranch: { _ in },
            onCopyLink: { _ in },
            onCopyUUID: { _ in },
            onClose: {},
            annotationInput: .constant(""),
            taskNameEditInput: .constant(""),
            annotationEditInput: .constant(""),
            projectEditInput: .constant(""),
            tagAddQuery: .constant(""),
            dueDateEditSelection: .constant(Date()),
            importantLinkUrlInput: .constant(""),
            importantLinkTitleInput: .constant("")
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.detailViewWide)
    }

    func testTaskDetail_projectEditing() {
        let task = MockApiClient.sampleTasks[0]
        let detailState = TaskDetailState()
        var linksState = ExternalLinksState()
        linksState.taskUUID = task.uuid
        linksState.links = MockApiClient.sampleExternalLinks
        let sampleProjects = TestHelpers.makeCompletionItems([
            "work",
            "personal",
            "hobby",
            "home",
            "health",
            "hobbies-misc",
            "homework",
        ])
        let view = TaskDetailView(
            task: task,
            detailState: detailState,
            externalLinksState: linksState,
            onRetryDetail: {},
            onRefreshLinks: { _ in },
            onCopyBranch: { _ in },
            onCopyLink: { _ in },
            onCopyUUID: { _ in },
            onClose: {},
            annotationInput: .constant(""),
            taskNameEditInput: .constant(""),
            annotationEditInput: .constant(""),
            isEditingProject: true,
            projectEditInput: .constant("hobby"),
            filteredProjects: sampleProjects,
            tagAddQuery: .constant(""),
            dueDateEditSelection: .constant(Date()),
            importantLinkUrlInput: .constant(""),
            importantLinkTitleInput: .constant("")
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.detailViewWide)
    }

    // MARK: - Command Palette

    func testCommandPalette_default() {
        viewModel.openCommandPalette()
        let view = CommandPaletteView(viewModel: viewModel, commandPalette: viewModel.commandPalette)
        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    func testCommandPalette_withSearch() {
        viewModel.openCommandPalette()
        viewModel.commandPalette.query = "report"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let view = CommandPaletteView(viewModel: viewModel, commandPalette: viewModel.commandPalette)
        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    // MARK: - Components

    func testComponent_tokenInput_empty() {
        let view = StatefulTokenHighlightWrapper(
            initialText: "",
            tokens: [],
            actionName: ""
        )
        .background(ThemeManager.current.surface0)
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    func testComponent_tokenInput_withTokens() {
        let view = StatefulTokenHighlightWrapper(
            initialText: "list +work project:api",
            tokens: TestHelpers.sampleTokens,
            actionName: "list"
        )
        .background(ThemeManager.current.surface0)
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    func testComponent_criteriaStrip() {
        let reportChips = TestHelpers.sampleReportFilterChips
        let manualChips = TestHelpers.sampleManualFilterChips
        let propertyChips = TestHelpers.samplePropertyChips
        let view = CriteriaStripView(
            activeReportName: "Sprint 42",
            reportFilterChips: reportChips,
            manualFilterChips: manualChips,
            propertyChips: propertyChips
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    func testComponent_completionMenu() {
        let items = TestHelpers.makeCompletionItems(["project:backend", "project:frontend", "project:api"])
        let view = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.completionMenu)
    }

    func testComponent_reportMenuButton() {
        let view = StatefulReportMenuButtonWrapper(
            name: "default",
            reports: MockApiClient.sampleConfig.reports
        )
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: TestSizes.reportMenuButton)
    }

    func testComponent_largeCalendarPicker() {
        // Calendar intrinsic size ~232x180, scaled 1.8x = ~418x324
        // Use a fixed date (Jan 15, 2020) to avoid flakiness from "today" highlighting
        let fixedDate = DateComponents(calendar: .current, year: 2020, month: 1, day: 15).date!
        let view = LargeCalendarPicker(selection: .constant(fixedDate))
            .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: CGSize(width: 420, height: 326))
    }

    // MARK: - Attachment Row States

    func testComponent_attachmentRow_default() {
        let attachment = TaskAttachmentDto(
            id: 1,
            uuid: "attach-001",
            filename: "design-spec.pdf",
            mimeType: "application/pdf",
            sizeBytes: 245_760,
            createdAt: "2024-01-17T14:30:00Z"
        )
        let view = AttachmentRow(
            attachment: attachment,
            isFocused: false,
            isConfirmingDelete: false,
            onSelect: {},
            onOpen: {},
            onDelete: {},
            onConfirmDelete: {},
            onCancelDelete: {}
        )
        .frame(width: 350)
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: CGSize(width: 350, height: 40))
    }

    func testComponent_attachmentRow_focused() {
        let attachment = TaskAttachmentDto(
            id: 1,
            uuid: "attach-001",
            filename: "design-spec.pdf",
            mimeType: "application/pdf",
            sizeBytes: 245_760,
            createdAt: "2024-01-17T14:30:00Z"
        )
        // isFocused: true shows the same UI as hover (delete button visible + focus ring)
        let view = AttachmentRow(
            attachment: attachment,
            isFocused: true,
            isConfirmingDelete: false,
            onSelect: {},
            onOpen: {},
            onDelete: {},
            onConfirmDelete: {},
            onCancelDelete: {}
        )
        .frame(width: 350)
        .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: CGSize(width: 350, height: 40))
    }

    // MARK: - Email Link Row States

    func testComponent_emailLinkRow_default() {
        let link = EmailLinkDto(
            id: 1,
            uuid: "link-001",
            messageId: "<test@example.com>",
            subject: "Meeting notes from standup",
            sender: "alice@example.com",
            sentDate: "2024-01-17T14:30:00Z",
            createdAt: "2024-01-17T15:00:00Z",
            mailUrl: "message://%3ctest%40example.com%3e"
        )
        let view = EmailLinkRow(link: link, onOpen: {})
            .frame(width: 350)
            .background(ThemeManager.current.base)
        assertViewSnapshot(view, size: CGSize(width: 350, height: 50))
    }
}

// MARK: - Helper Views

/// Wrapper view for TokenHighlightTextView that provides @State for the text binding.
private struct StatefulTokenHighlightWrapper: View {
    @State private var text: String

    let tokens: [TokenSpan]
    let actionName: String

    init(
        initialText: String,
        tokens: [TokenSpan],
        actionName: String
    ) {
        _text = State(initialValue: initialText)
        self.tokens = tokens
        self.actionName = actionName
    }

    var body: some View {
        TokenHighlightTextView(
            text: $text,
            tokens: tokens,
            actionName: actionName,
            isFocused: false,
            ghostText: nil,
            cursorPosition: text.count,
            showCompletionMenu: false,
            onSubmit: {},
            onEscape: {},
            onMoveSelection: { _ in },
            onCursorChange: { _ in },
            onToggleMenu: {},
            onAcceptGhost: {},
            onMenuNavigation: { _ in },
            onAcceptCompletion: {},
            onRequestFocus: { true }
        )
        .frame(height: 40)
        .padding(.horizontal, 8)
    }
}

/// Wrapper view for ReportMenuButton that provides @State for the flash binding.
private struct StatefulReportMenuButtonWrapper: View {
    let name: String
    let reports: [ReportSummary]
    @State private var flash: Bool = false

    var body: some View {
        ReportMenuButton(
            name: name,
            reports: reports,
            flash: $flash,
            onSelect: { _ in }
        )
    }
}
