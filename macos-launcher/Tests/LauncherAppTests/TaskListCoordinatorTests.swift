import XCTest
@testable import LauncherApp

final class TaskListCoordinatorTests: XCTestCase {
    func testMoveSelectionWrapsForward() {
        let tasks = [makeTask(id: "a"), makeTask(id: "b"), makeTask(id: "c")]

        var selection = TaskListCoordinator.moveSelection(tasks: tasks, selectedIndex: nil, delta: 1)
        XCTAssertEqual(selection, 0)

        selection = TaskListCoordinator.moveSelection(tasks: tasks, selectedIndex: selection, delta: 1)
        XCTAssertEqual(selection, 1)

        selection = TaskListCoordinator.moveSelection(tasks: tasks, selectedIndex: selection, delta: 1)
        XCTAssertEqual(selection, 2)

        selection = TaskListCoordinator.moveSelection(tasks: tasks, selectedIndex: selection, delta: 1)
        XCTAssertEqual(selection, 0)
    }

    func testMoveSelectionWrapsBackward() {
        let tasks = [makeTask(id: "a"), makeTask(id: "b")]

        var selection = TaskListCoordinator.moveSelection(tasks: tasks, selectedIndex: nil, delta: -1)
        XCTAssertEqual(selection, 1)

        selection = TaskListCoordinator.moveSelection(tasks: tasks, selectedIndex: selection, delta: -1)
        XCTAssertEqual(selection, 0)
    }

    func testSyncSelectionAfterTasksUpdate() {
        let tasks = [makeTask(id: "a"), makeTask(id: "b")]

        var selection = TaskListCoordinator.syncSelection(tasks: tasks, selectedIndex: 1)
        XCTAssertEqual(selection, 1)

        selection = TaskListCoordinator.syncSelection(tasks: [makeTask(id: "a")], selectedIndex: 1)
        XCTAssertEqual(selection, 0)

        selection = TaskListCoordinator.syncSelection(tasks: [], selectedIndex: 0)
        XCTAssertNil(selection)
    }

    func testSortTasksByUrgencyOrdersHighFirstAndNilLast() {
        let tasks = [
            makeTask(id: "c", urgency: nil),
            makeTask(id: "a", urgency: 9),
            makeTask(id: "b", urgency: 2),
            makeTask(id: "d", urgency: nil),
            makeTask(id: "e", urgency: 9)
        ]

        let sorted = TaskListCoordinator.sortTasksByUrgency(tasks)
        let ids = sorted.map { $0.uuid }

        XCTAssertEqual(ids, ["a", "e", "b", "c", "d"])
    }
}

private func makeTask(id: String, urgency: Int? = nil) -> ApiTask {
    ApiTask(
        dbId: nil,
        uuid: id,
        status: "pending",
        summary: "Task \(id)",
        project: nil,
        tags: [],
        dateCreated: "2024-01-01T00:00:00Z",
        dateCompleted: nil,
        dateDue: nil,
        urgency: urgency
    )
}
