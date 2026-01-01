@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for ContentView using ViewInspector.
///
/// These tests verify the root view's structure and content display
/// based on the application mode and state.
///
/// Note: Keyboard event monitors (escape, normal mode navigation) cannot be
/// tested directly with ViewInspector - those are tested via ViewModel unit tests.
@MainActor
final class ContentViewUITests: XCTestCase {
    // MARK: - Test Setup

    private var viewModel: LauncherViewModel!
    private var mockApiClient: MockApiClient!

    override func setUp() async throws {
        try await super.setUp()
        mockApiClient = MockApiClient()
        viewModel = LauncherViewModel(apiClient: mockApiClient)
        viewModel.reportConfig = MockApiClient.sampleConfig.report
        viewModel.availableReports = MockApiClient.sampleConfig.reports
    }

    override func tearDown() async throws {
        viewModel = nil
        mockApiClient = nil
        try await super.tearDown()
    }

    // MARK: - Mode Switching Tests

    func testDisplaysTaskListInListMode() throws {
        viewModel.mode = .list
        let sut = ContentView(viewModel: viewModel)
        let view = try sut.inspect()

        // Find TaskListView in list mode
        _ = try view.find(TaskListView.self)
    }

    func testDisplaysTaskDetailInDetailMode() throws {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(
            isLoading: false,
            taskUUID: MockApiClient.sampleTasks[0].uuid,
            detail: MockApiClient.sampleTaskDetail
        )
        let sut = ContentView(viewModel: viewModel)
        let view = try sut.inspect()

        // Find TaskDetailView in detail mode
        _ = try view.find(TaskDetailView.self)
    }

    func testHidesTaskListInDetailMode() throws {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(
            isLoading: false,
            taskUUID: MockApiClient.sampleTasks[0].uuid,
            detail: MockApiClient.sampleTaskDetail
        )
        let sut = ContentView(viewModel: viewModel)
        let view = try sut.inspect()

        // TaskListView should not be present in detail mode
        XCTAssertThrowsError(try view.find(TaskListView.self))
    }

    // MARK: - Bottom Hint Bar Tests

    func testDisplaysBottomHintBar() throws {
        let sut = ContentView(viewModel: viewModel)
        let view = try sut.inspect()

        // BottomHintBar is always present as an overlay
        _ = try view.find(BottomHintBar.self)
    }

    // MARK: - Toast Stack Tests

    func testDisplaysToastStack() throws {
        let sut = ContentView(viewModel: viewModel)
        let view = try sut.inspect()

        // ToastStackView is always present (may be empty)
        _ = try view.find(ToastStackView.self)
    }

    func testToastStackShowsToasts() throws {
        viewModel.toasts = [
            ToastMessage(id: UUID(), message: "Task completed!", icon: .success),
        ]
        let sut = ContentView(viewModel: viewModel)
        let view = try sut.inspect()

        // Find the toast message text
        _ = try view.find(text: "Task completed!")
    }

    // MARK: - Command Palette Tests

    func testDisplaysCommandPalette() throws {
        viewModel.commandPalette.isPresented = true
        let sut = ContentView(viewModel: viewModel)
        let view = try sut.inspect()

        // Find CommandPaletteView when presented
        _ = try view.find(CommandPaletteView.self)
    }

    func testHidesCommandPaletteWhenNotPresented() throws {
        viewModel.commandPalette.isPresented = false
        let sut = ContentView(viewModel: viewModel)
        let view = try sut.inspect()

        // CommandPaletteView should not be present when not shown
        XCTAssertThrowsError(try view.find(CommandPaletteView.self))
    }
}
