@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for TaskListView using ViewInspector.
///
/// These tests verify the view's structure, content display, and component
/// visibility without requiring a full UI test target.
@MainActor
final class TaskListViewUITests: XCTestCase {
    // MARK: - Test Setup

    private var viewModel: LauncherViewModel!
    private var mockApiClient: MockApiClient!

    override func setUp() async throws {
        try await super.setUp()
        mockApiClient = MockApiClient()
        viewModel = LauncherViewModel(apiClient: mockApiClient)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockApiClient = nil
        try await super.tearDown()
    }

    // MARK: - Search Input Tests

    func testDisplaysSearchMagnifyingGlass() throws {
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Find the magnifying glass icon
        _ = try view.find(ViewType.Image.self, where: { image in
            (try? image.actualImage().name()) == "magnifyingglass"
        })
    }

    func testDisplaysSearchPlaceholder() throws {
        viewModel.input = ""
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Find placeholder text when input is empty
        _ = try view.find(text: "Search tasks…")
    }

    func testHidesPlaceholderWhenInputNotEmpty() throws {
        viewModel.input = "test query"
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Placeholder should not be visible when there's input
        XCTAssertThrowsError(try view.find(text: "Search tasks…"))
    }

    // MARK: - Report Menu Tests

    func testDisplaysReportMenuWhenReportsAvailable() throws {
        viewModel.availableReports = [
            TestHelpers.makeReportSummary(name: "default", isDefault: true),
            TestHelpers.makeReportSummary(name: "all", isDefault: false),
        ]
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Find ReportMenuButton in the view hierarchy
        _ = try view.find(ReportMenuButton.self)
    }

    func testHidesReportMenuWhenNoReports() throws {
        viewModel.availableReports = []
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Report menu should not be present
        XCTAssertThrowsError(try view.find(ReportMenuButton.self))
    }

    // MARK: - Project Scope Tests

    func testDisplaysProjectScopeChip() throws {
        viewModel.projectScope = "my-project"
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Find ProjectScopeChipView
        _ = try view.find(ProjectScopeChipView.self)
    }

    func testHidesProjectScopeWhenNil() throws {
        viewModel.projectScope = nil
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Project scope chip should not be present
        XCTAssertThrowsError(try view.find(ProjectScopeChipView.self))
    }

    // MARK: - Criteria Strip Tests

    func testDisplaysCriteriaStrip() throws {
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // CriteriaStripView is always present (shows "No filters/No properties" when empty)
        _ = try view.find(CriteriaStripView.self)
    }

    // MARK: - Column Headers Tests

    func testDisplaysColumnHeadersWithTasks() throws {
        viewModel.reportConfig = MockApiClient.sampleConfig.report
        viewModel.tasks = MockApiClient.sampleTasks
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // With reportConfig set and tasks, column headers should be visible
        // Find the HStack containing column headers by looking for the ID column
        _ = try view.find(text: "ID")
    }

    // MARK: - Task Row Tests

    func testDisplaysTaskRows() throws {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.reportConfig = MockApiClient.sampleConfig.report
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Find TaskRow components
        _ = try view.find(TaskRow.self)
    }

    func testDisplaysEmptyListWhenNoTasks() throws {
        viewModel.tasks = []
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // No TaskRow should be present
        XCTAssertThrowsError(try view.find(TaskRow.self))
    }

    // MARK: - Group Header Tests

    func testDisplaysGroupHeaders() throws {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.reportConfig = MockApiClient.sampleConfig.report
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Find GroupHeaderRow for project grouping
        _ = try view.find(GroupHeaderRow.self)
    }

    // MARK: - Completion Menu Tests

    func testDisplaysCompletionMenu() throws {
        viewModel.completion.items = TestHelpers.makeCompletionItems(["work", "urgent", "home"])
        viewModel.completion.showMenu = true
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Find CompletionMenuView
        _ = try view.find(CompletionMenuView.self)
    }

    func testHidesCompletionMenuWhenNotShown() throws {
        viewModel.completion.showMenu = false
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Completion menu should not be visible
        XCTAssertThrowsError(try view.find(CompletionMenuView.self))
    }

    // MARK: - Status Message Tests

    func testDisplaysStatusMessage() throws {
        viewModel.statusMessage = "3 tasks completed"
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Find status message text
        _ = try view.find(text: "3 tasks completed")
    }

    func testHidesStatusMessageWhenNil() throws {
        viewModel.statusMessage = nil
        let sut = TaskListView(viewModel: viewModel, completion: viewModel.completion)
        let view = try sut.inspect()

        // Status message should not be present
        XCTAssertThrowsError(try view.find(text: "3 tasks completed"))
    }
}
