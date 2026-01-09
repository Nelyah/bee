import XCTest

@testable import LauncherAppKit

/// Integration tests for navigation stack behavior in LauncherViewModel.
@MainActor
final class NavigationIntegrationTests: XCTestCase {
    private var viewModel: LauncherViewModel!

    override func setUp() {
        super.setUp()
        viewModel = LauncherViewModel(apiClient: MockApiClient())
        viewModel.tasks = MockApiClient.sampleTasks
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Basic Navigation Tests

    func testOpenDetailPushesOntoStack() {
        viewModel.selectedIndex = 0

        viewModel.openDetail()

        XCTAssertEqual(viewModel.mode, .detail)
        XCTAssertEqual(viewModel.navigationStack.depth, 2)
        XCTAssertTrue(viewModel.navigationStack.canGoBack)
    }

    func testCloseDetailPopsStack() {
        viewModel.selectedIndex = 0
        viewModel.openDetail()

        viewModel.closeDetail()

        XCTAssertEqual(viewModel.mode, .list)
        XCTAssertEqual(viewModel.navigationStack.depth, 1)
        XCTAssertFalse(viewModel.navigationStack.canGoBack)
    }

    func testNavigateBackReturnsToPreviousView() {
        viewModel.selectedIndex = 0
        viewModel.openDetail()

        let didNavigate = viewModel.navigateBack()

        XCTAssertTrue(didNavigate)
        XCTAssertEqual(viewModel.mode, .list)
    }

    func testNavigateBackAtRootReturnsFalse() {
        let didNavigate = viewModel.navigateBack()

        XCTAssertFalse(didNavigate)
        XCTAssertEqual(viewModel.mode, .list)
    }

    // MARK: - Linked Task Navigation Tests

    func testNavigateToLinkedTaskPushesOntoStack() {
        // Open first task
        viewModel.selectedIndex = 0
        viewModel.openDetail()
        let firstTaskUUID = viewModel.tasks[0].uuid

        // Navigate to second task (simulating clicking a linked task)
        let secondTaskUUID = viewModel.tasks[1].uuid
        viewModel.navigateToTask(uuid: secondTaskUUID)

        XCTAssertEqual(viewModel.mode, .detail)
        XCTAssertEqual(viewModel.navigationStack.depth, 3) // root + first + second
        XCTAssertEqual(viewModel.selectedIndex, 1)

        // Navigate back should return to first task
        _ = viewModel.navigateBack()
        XCTAssertTrue(viewModel.navigationStack.current.isDetailFor(uuid: firstTaskUUID))
    }

    func testLinkedTaskNavigationChain() {
        guard viewModel.tasks.count >= 3 else {
            XCTFail("Need at least 3 tasks for this test")
            return
        }

        // Navigate: List -> Task0 -> Task1 -> Task2
        viewModel.selectedIndex = 0
        viewModel.openDetail()
        viewModel.navigateToTask(uuid: viewModel.tasks[1].uuid)
        viewModel.navigateToTask(uuid: viewModel.tasks[2].uuid)

        XCTAssertEqual(viewModel.navigationStack.depth, 4)

        // Navigate back: Task2 -> Task1 -> Task0 -> List
        _ = viewModel.navigateBack()
        XCTAssertTrue(viewModel.navigationStack.current.isDetailFor(uuid: viewModel.tasks[1].uuid))

        _ = viewModel.navigateBack()
        XCTAssertTrue(viewModel.navigationStack.current.isDetailFor(uuid: viewModel.tasks[0].uuid))

        _ = viewModel.navigateBack()
        XCTAssertEqual(viewModel.mode, .list)
    }

    func testNavigateToNonExistentTaskShowsToast() {
        viewModel.selectedIndex = 0
        viewModel.openDetail()
        let initialDepth = viewModel.navigationStack.depth

        viewModel.navigateToTask(uuid: "non-existent-uuid")

        // Should not have pushed onto stack
        XCTAssertEqual(viewModel.navigationStack.depth, initialDepth)
        // Toast should be shown (can't easily verify content, but check it was added)
        XCTAssertFalse(viewModel.toasts.isEmpty)
    }

    // MARK: - Project Overview Navigation Tests

    func testNavigateToProjectOverviewPushesOntoStack() {
        viewModel.navigateToProjectOverview()

        XCTAssertEqual(viewModel.mode, .projectOverview)
        XCTAssertEqual(viewModel.navigationStack.depth, 2)
        XCTAssertTrue(viewModel.navigationStack.canGoBack)
    }

    func testExitProjectOverviewPopsStack() {
        viewModel.navigateToProjectOverview()

        viewModel.exitProjectOverview()

        XCTAssertEqual(viewModel.mode, .list)
        XCTAssertFalse(viewModel.navigationStack.canGoBack)
    }

    func testProjectOverviewFromDetailReturnsToDetail() {
        // Open task detail first
        viewModel.selectedIndex = 0
        viewModel.openDetail()
        let taskUUID = viewModel.tasks[0].uuid

        // Navigate to project overview
        viewModel.navigateToProjectOverview()
        XCTAssertEqual(viewModel.mode, .projectOverview)

        // Navigate back should return to detail, not list
        viewModel.exitProjectOverview()
        XCTAssertEqual(viewModel.mode, .detail)
        XCTAssertTrue(viewModel.navigationStack.current.isDetailFor(uuid: taskUUID))
    }

    // MARK: - Navigate To Root Tests

    func testNavigateToRootClearsStack() {
        viewModel.selectedIndex = 0
        viewModel.openDetail()
        viewModel.navigateToTask(uuid: viewModel.tasks[1].uuid)
        viewModel.navigateToProjectOverview()

        viewModel.navigateToRoot()

        XCTAssertEqual(viewModel.mode, .list)
        XCTAssertEqual(viewModel.navigationStack.depth, 1)
        XCTAssertFalse(viewModel.navigationStack.canGoBack)
    }

    // MARK: - Selection Restoration Tests

    func testNavigateBackRestoresSelectedIndex() {
        // Select task at index 2
        viewModel.selectedIndex = 2
        viewModel.openDetail()

        // Navigate to different task
        viewModel.navigateToTask(uuid: viewModel.tasks[0].uuid)
        XCTAssertEqual(viewModel.selectedIndex, 0)

        // Navigate back should restore index 2
        _ = viewModel.navigateBack()
        XCTAssertEqual(viewModel.selectedIndex, 2)
    }

    // MARK: - Escape Handler Integration Tests

    func testEscapeInDetailModeNavigatesBack() {
        viewModel.selectedIndex = 0
        viewModel.openDetail()

        let handled = viewModel.handleEscape()

        XCTAssertTrue(handled)
        XCTAssertEqual(viewModel.mode, .list)
    }

    func testEscapeInListModeAtRootDoesNotNavigate() {
        // In list mode at root, escape should trigger window close (not navigation)
        // The handleEscape returns true because it sends windowClose signal
        let handled = viewModel.handleEscape()

        XCTAssertTrue(handled) // Window close is handled
        XCTAssertEqual(viewModel.mode, .list) // Still in list mode
    }

    // MARK: - Can Navigate Back Tests

    func testCanNavigateBackProperty() {
        XCTAssertFalse(viewModel.canNavigateBack)

        viewModel.selectedIndex = 0
        viewModel.openDetail()

        XCTAssertTrue(viewModel.canNavigateBack)

        viewModel.closeDetail()

        XCTAssertFalse(viewModel.canNavigateBack)
    }
}
