import XCTest

@testable import LauncherAppKit

/// Tests for Cmd+P contextual menu trigger behavior.
/// Verifies that Cmd+P dispatches to the correct menu based on current mode.
@MainActor
final class CommandPTriggerTests: XCTestCase {
    // MARK: - Mode-Based Dispatch Tests

    func testCmdPInListModeTriggersReportMenu() {
        // Given: A view model in list mode with report menu trigger set
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        viewModel.setModeForTesting(.list)

        var reportMenuTriggered = false
        viewModel.reportMenuTrigger = { reportMenuTriggered = true }
        viewModel.taskStateMenuTrigger = { XCTFail("Task state menu should not be triggered in list mode") }

        // When: We handle Cmd+P
        viewModel.handleContextualMenu()

        // Then: Report menu trigger should be called
        XCTAssertTrue(reportMenuTriggered, "Report menu should be triggered in list mode")
    }

    func testCmdPInDetailModeTriggersTaskStateMenu() {
        // Given: A view model in detail mode with task state menu trigger set
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        viewModel.setModeForTesting(.detail)

        var taskStateMenuTriggered = false
        viewModel.reportMenuTrigger = { XCTFail("Report menu should not be triggered in detail mode") }
        viewModel.taskStateMenuTrigger = { taskStateMenuTriggered = true }

        // When: We handle Cmd+P
        viewModel.handleContextualMenu()

        // Then: Task state menu trigger should be called
        XCTAssertTrue(taskStateMenuTriggered, "Task state menu should be triggered in detail mode")
    }

    // MARK: - Repeated Trigger Tests

    func testCmdPCanBeTriggeredMultipleTimesInListMode() {
        // Given: A view model in list mode
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        viewModel.setModeForTesting(.list)

        var triggerCount = 0
        viewModel.reportMenuTrigger = { triggerCount += 1 }

        // When: We trigger Cmd+P multiple times
        viewModel.handleContextualMenu()
        viewModel.handleContextualMenu()
        viewModel.handleContextualMenu()

        // Then: Trigger should be called each time
        XCTAssertEqual(triggerCount, 3, "Report menu should be triggered 3 times")
    }

    func testCmdPCanBeTriggeredMultipleTimesInDetailMode() {
        // Given: A view model in detail mode
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        viewModel.setModeForTesting(.detail)

        var triggerCount = 0
        viewModel.taskStateMenuTrigger = { triggerCount += 1 }

        // When: We trigger Cmd+P multiple times
        viewModel.handleContextualMenu()
        viewModel.handleContextualMenu()
        viewModel.handleContextualMenu()

        // Then: Trigger should be called each time
        XCTAssertEqual(triggerCount, 3, "Task state menu should be triggered 3 times")
    }

    // MARK: - Mode Switch Tests

    func testCmdPDispatchesCorrectlyAfterModeChange() {
        // Given: A view model with both triggers set
        let viewModel = LauncherViewModel(apiClient: MockApiClient())

        var reportCount = 0
        var taskStateCount = 0
        viewModel.reportMenuTrigger = { reportCount += 1 }
        viewModel.taskStateMenuTrigger = { taskStateCount += 1 }

        // When: We trigger in list mode
        viewModel.setModeForTesting(.list)
        viewModel.handleContextualMenu()

        // Then switch to detail mode and trigger again
        viewModel.setModeForTesting(.detail)
        viewModel.handleContextualMenu()

        // And switch back to list mode
        viewModel.setModeForTesting(.list)
        viewModel.handleContextualMenu()

        // Then: Each trigger should be called the correct number of times
        XCTAssertEqual(reportCount, 2, "Report menu should be triggered twice (list mode)")
        XCTAssertEqual(taskStateCount, 1, "Task state menu should be triggered once (detail mode)")
    }

    // MARK: - Nil Trigger Tests

    func testCmdPHandlesNilReportMenuTriggerGracefully() {
        // Given: A view model in list mode with no trigger set
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        viewModel.setModeForTesting(.list)
        viewModel.reportMenuTrigger = nil

        // When: We handle Cmd+P - should not crash
        viewModel.handleContextualMenu()

        // Then: No crash (test passes if we get here)
    }

    func testCmdPHandlesNilTaskStateMenuTriggerGracefully() {
        // Given: A view model in detail mode with no trigger set
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        viewModel.setModeForTesting(.detail)
        viewModel.taskStateMenuTrigger = nil

        // When: We handle Cmd+P - should not crash
        viewModel.handleContextualMenu()

        // Then: No crash (test passes if we get here)
    }

    // MARK: - Same Task Multiple State Changes Tests

    func testMultipleStateChangesOnSameTaskWorkCorrectly() async {
        // Given: A view model with a task in detail mode
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        let task = TestHelpers.makeTask(id: "test-uuid", status: "pending")
        viewModel.tasks = [task]
        viewModel.setModeForTesting(.detail)
        viewModel.taskDetailState = TaskDetailState(taskUUID: "test-uuid", detail: nil)

        // When: We change state multiple times (pending -> active -> pending -> active)
        viewModel.handleTaskStateChange(.start, taskUUID: "test-uuid")
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.tasks.first?.status, "active", "First state change: pending -> active")
        XCTAssertEqual(viewModel.mode, .detail, "Detail view should remain open after start")

        viewModel.handleTaskStateChange(.stop, taskUUID: "test-uuid")
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.tasks.first?.status, "pending", "Second state change: active -> pending")
        XCTAssertEqual(viewModel.mode, .detail, "Detail view should remain open after stop")

        viewModel.handleTaskStateChange(.start, taskUUID: "test-uuid")
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.tasks.first?.status, "active", "Third state change: pending -> active")
        XCTAssertEqual(viewModel.mode, .detail, "Detail view should remain open after second start")
    }

    func testCompleteAfterMultipleStateChanges() async {
        // Given: A view model with a task that has been started/stopped multiple times
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        let task = TestHelpers.makeTask(id: "test-uuid", status: "pending")
        viewModel.tasks = [task]
        viewModel.setModeForTesting(.detail)
        viewModel.taskDetailState = TaskDetailState(taskUUID: "test-uuid", detail: nil)

        // Start and stop multiple times
        viewModel.handleTaskStateChange(.start, taskUUID: "test-uuid")
        try? await Task.sleep(nanoseconds: 100_000_000)
        viewModel.handleTaskStateChange(.stop, taskUUID: "test-uuid")
        try? await Task.sleep(nanoseconds: 100_000_000)
        viewModel.handleTaskStateChange(.start, taskUUID: "test-uuid")
        try? await Task.sleep(nanoseconds: 100_000_000)

        // When: We complete the task
        viewModel.handleTaskStateChange(.complete, taskUUID: "test-uuid")
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then: Task should be marked complete and detail view should stay open
        XCTAssertEqual(viewModel.tasks.first?.status, "completed", "Task should be marked completed")
        XCTAssertEqual(viewModel.mode, .detail, "Detail view should remain open after complete")
    }
}
