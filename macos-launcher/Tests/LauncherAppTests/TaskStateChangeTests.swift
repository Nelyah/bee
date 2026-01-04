import XCTest

@testable import LauncherApp

/// Tests for task state change behavior in LauncherViewModel.
@MainActor
final class TaskStateChangeTests: XCTestCase {
    // MARK: - Complete Action Tests

    func testCompleteActionKeepsDetailViewOpen() async {
        // Given: A view model in detail mode showing a task
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        let task = TestHelpers.makeTask(id: "test-uuid", status: "active")
        viewModel.tasks = [task]
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(taskUUID: "test-uuid", detail: nil)

        // When: We complete the task
        viewModel.handleTaskStateChange(.complete, taskUUID: "test-uuid")

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Detail view should remain open (mode should still be .detail)
        XCTAssertEqual(viewModel.mode, .detail, "Detail view should stay open after completing task")
        XCTAssertEqual(viewModel.taskDetailState.taskUUID, "test-uuid", "Task detail state should remain for the same task")
    }

    func testCompleteActionUpdatesTaskStatusLocally() async {
        // Given: A view model with an active task
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        let task = TestHelpers.makeTask(id: "test-uuid", status: "active")
        viewModel.tasks = [task]

        // When: We complete the task
        viewModel.handleTaskStateChange(.complete, taskUUID: "test-uuid")

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Task status should be updated to completed
        XCTAssertEqual(viewModel.tasks.first?.status, "completed", "Task status should be updated to completed")
    }

    // MARK: - Delete Action Tests

    func testDeleteActionClosesDetailView() async {
        // Given: A view model in detail mode showing a task
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        let task = TestHelpers.makeTask(id: "test-uuid", status: "active")
        viewModel.tasks = [task]
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(taskUUID: "test-uuid", detail: nil)

        // When: We delete the task
        viewModel.handleTaskStateChange(.delete, taskUUID: "test-uuid")

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Detail view should close (mode should be .list)
        XCTAssertEqual(viewModel.mode, .list, "Detail view should close after deleting task")
    }

    func testDeleteActionRemovesTaskFromList() async {
        // Given: A view model with a task
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        let task = TestHelpers.makeTask(id: "test-uuid", status: "active")
        viewModel.tasks = [task]

        // When: We delete the task
        viewModel.handleTaskStateChange(.delete, taskUUID: "test-uuid")

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Task should be removed from list
        XCTAssertTrue(viewModel.tasks.isEmpty, "Task should be removed from list after delete")
    }

    // MARK: - Start/Stop Action Tests

    func testStartActionKeepsDetailViewOpen() async {
        // Given: A view model in detail mode showing a pending task
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        let task = TestHelpers.makeTask(id: "test-uuid", status: "pending")
        viewModel.tasks = [task]
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(taskUUID: "test-uuid", detail: nil)

        // When: We start the task
        viewModel.handleTaskStateChange(.start, taskUUID: "test-uuid")

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Detail view should remain open
        XCTAssertEqual(viewModel.mode, .detail, "Detail view should stay open after starting task")
        XCTAssertEqual(viewModel.tasks.first?.status, "active", "Task status should be updated to active")
    }

    func testStopActionKeepsDetailViewOpen() async {
        // Given: A view model in detail mode showing an active task
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        let task = TestHelpers.makeTask(id: "test-uuid", status: "active")
        viewModel.tasks = [task]
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(taskUUID: "test-uuid", detail: nil)

        // When: We stop the task
        viewModel.handleTaskStateChange(.stop, taskUUID: "test-uuid")

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Detail view should remain open
        XCTAssertEqual(viewModel.mode, .detail, "Detail view should stay open after stopping task")
        XCTAssertEqual(viewModel.tasks.first?.status, "pending", "Task status should be updated to pending")
    }
}
