import SnapshotTesting
import SwiftUI
@testable import LauncherApp
import XCTest

/// Snapshot tests for TaskListView in various states.
///
/// Tests the main task list interface including search input,
/// report selector, task rows, and grouping.
@MainActor
final class TaskListViewSnapshotTests: SnapshotTestCase {
    // MARK: - Test Setup

    private var viewModel: LauncherViewModel!
    private var mockApiClient: MockApiClient!

    override func setUp() async throws {
        try await super.setUp()
        mockApiClient = MockApiClient()
        viewModel = LauncherViewModel(apiClient: mockApiClient)
        // Set up default config
        viewModel.reportConfig = MockApiClient.sampleConfig.report
        viewModel.availableReports = MockApiClient.sampleConfig.reports
    }

    override func tearDown() async throws {
        viewModel = nil
        mockApiClient = nil
        try await super.tearDown()
    }

    // MARK: - Empty States

    func testEmptyState() {
        viewModel.tasks = []
        viewModel.input = ""
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    // MARK: - With Tasks

    func testWithTasks() {
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    func testWithManyTasks() {
        // Create more tasks for a fuller list
        viewModel.tasks = [
            TestHelpers.makeTask(id: "1", project: "api", status: "active", summary: "Implement REST endpoints"),
            TestHelpers.makeTask(id: "2", project: "api", status: "pending", summary: "Add authentication"),
            TestHelpers.makeTask(id: "3", project: "frontend", status: "active", summary: "Create dashboard"),
            TestHelpers.makeTask(id: "4", project: "frontend", status: "pending", summary: "Add charts"),
            TestHelpers.makeTask(id: "5", project: "infra", status: "completed", summary: "Set up CI/CD"),
        ]
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    // MARK: - Search Input States

    func testWithSearchInput() {
        viewModel.input = "list +work"
        viewModel.tokens = [
            TokenSpan(tokenType: .wordString, literal: "list", start: 0, end: 4),
            TokenSpan(tokenType: .blank, literal: " ", start: 4, end: 5),
            TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 5, end: 6),
            TokenSpan(tokenType: .wordString, literal: "work", start: 6, end: 10),
        ]
        viewModel.actionName = "list"
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    func testInsertModeActive() {
        viewModel.isInsertMode = true
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    func testNormalModeInactive() {
        viewModel.isInsertMode = false
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    // MARK: - Report and Filters

    func testWithReportBadge() {
        viewModel.selectedReportName = "all"
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    func testWithProjectScope() {
        viewModel.projectScope = "my-project"
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    func testWithCriteriaChips() {
        viewModel.reportFilterChips = TestHelpers.sampleFilterChips
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    // MARK: - Grouping

    func testWithGroupedTasks() {
        viewModel.tasks = [
            TestHelpers.makeTask(id: "1", project: "api", summary: "Task in API project"),
            TestHelpers.makeTask(id: "2", project: "api", summary: "Another API task"),
            TestHelpers.makeTask(id: "3", project: "frontend", summary: "Frontend task"),
        ]
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    // MARK: - Expanded Task

    func testWithExpandedTask() {
        let task = TestHelpers.makeTask(id: "task-1", summary: "Expandable task")
        viewModel.tasks = [task]
        viewModel.expandedTasks = Set(["task-1"])
        viewModel.taskExpandedData = [
            "task-1": TaskExpandedContent(
                links: [
                    TestHelpers.makeGitLabMRLink(title: "Add feature"),
                ],
                annotations: [
                    TestHelpers.makeAnnotation(value: "Follow up needed"),
                ]
            ),
        ]
        let view = makeTaskListView()
        assertViewSnapshot(view, size: CGSize(width: 600, height: 300))
    }

    // MARK: - Completion Menu

    func testWithCompletionMenu() {
        viewModel.input = "+"
        viewModel.completion.items = TestHelpers.makeCompletionItems(["work", "urgent", "personal"])
        viewModel.completion.showMenu = true
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    // MARK: - Status Message

    func testWithStatusMessage() {
        viewModel.statusMessage = "3 tasks completed"
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListView)
    }

    // MARK: - Compact Size

    func testCompactSize() {
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeTaskListView()
        assertViewSnapshot(view, size: TestSizes.taskListViewCompact)
    }

    // MARK: - Helper

    private func makeTaskListView() -> some View {
        TaskListView(viewModel: viewModel, completion: viewModel.completion)
            .frame(width: 600, height: 500)
            .background(ThemeManager.current.base)
    }
}
