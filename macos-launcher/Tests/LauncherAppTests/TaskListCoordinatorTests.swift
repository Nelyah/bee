@testable import LauncherApp
import XCTest

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
            makeTask(id: "e", urgency: 9),
        ]

        let sorted = TaskListCoordinator.sortTasksByUrgency(tasks)
        let ids = sorted.map(\.uuid)

        XCTAssertEqual(ids, ["a", "e", "b", "c", "d"])
    }

    // MARK: - Grouped Selection Tests

    func testMoveGroupedSelectionClampsAtEnd() {
        let rows: [GroupedListRow] = [
            .header(GroupHeader(key: "A", displayName: "A", taskCount: 2, isCollapsed: false)),
            .task(GroupedTask(task: makeTask(id: "a"), flatIndex: 0, groupKey: "A")),
            .task(GroupedTask(task: makeTask(id: "b"), flatIndex: 1, groupKey: "A")),
        ]

        // At last row, moving forward should stay at last row (clamp)
        let selection = TaskListCoordinator.moveGroupedSelection(
            rows: rows,
            currentRowIndex: 2,
            delta: 1
        )
        XCTAssertEqual(selection, 2) // Clamped, not wrapped to 0
    }

    func testMoveGroupedSelectionClampsAtStart() {
        let rows: [GroupedListRow] = [
            .header(GroupHeader(key: "A", displayName: "A", taskCount: 2, isCollapsed: false)),
            .task(GroupedTask(task: makeTask(id: "a"), flatIndex: 0, groupKey: "A")),
        ]

        // At first row, moving backward should stay at first row (clamp)
        let selection = TaskListCoordinator.moveGroupedSelection(
            rows: rows,
            currentRowIndex: 0,
            delta: -1
        )
        XCTAssertEqual(selection, 0) // Clamped, not wrapped to last
    }

    func testMoveGroupedSelectionNavigatesNormally() {
        let rows: [GroupedListRow] = [
            .header(GroupHeader(key: "A", displayName: "A", taskCount: 2, isCollapsed: false)),
            .task(GroupedTask(task: makeTask(id: "a"), flatIndex: 0, groupKey: "A")),
            .task(GroupedTask(task: makeTask(id: "b"), flatIndex: 1, groupKey: "A")),
        ]

        var selection = TaskListCoordinator.moveGroupedSelection(
            rows: rows,
            currentRowIndex: 0,
            delta: 1
        )
        XCTAssertEqual(selection, 1)

        selection = TaskListCoordinator.moveGroupedSelection(
            rows: rows,
            currentRowIndex: selection,
            delta: 1
        )
        XCTAssertEqual(selection, 2)
    }

    func testMoveGroupedSelectionInitialSelection() {
        let rows: [GroupedListRow] = [
            .header(GroupHeader(key: "A", displayName: "A", taskCount: 2, isCollapsed: false)),
            .task(GroupedTask(task: makeTask(id: "a"), flatIndex: 0, groupKey: "A")),
        ]

        // Initial selection when moving down
        var selection = TaskListCoordinator.moveGroupedSelection(
            rows: rows,
            currentRowIndex: nil,
            delta: 1
        )
        XCTAssertEqual(selection, 0)

        // Initial selection when moving up
        selection = TaskListCoordinator.moveGroupedSelection(
            rows: rows,
            currentRowIndex: nil,
            delta: -1
        )
        XCTAssertEqual(selection, 1)
    }

    // MARK: - Grouped Rows Tests

    func testGroupTasksOrdersGroupsAndTasks() {
        let tasks = [
            makeTask(id: "a", urgency: 1, project: "beta"),
            makeTask(id: "b", urgency: 5, project: nil),
            makeTask(id: "c", urgency: 3, project: "alpha"),
            makeTask(id: "d", urgency: 2, project: "alpha"),
        ]

        let rows = TaskListCoordinator.groupTasks(
            tasks,
            using: ProjectGroupingStrategy(),
            collapsedKeys: []
        )

        let rowDescriptions = rows.map { row in
            switch row {
            case let .header(header): "header:\(header.displayName)"
            case let .task(item): "task:\(item.task.uuid)"
            }
        }

        XCTAssertEqual(
            rowDescriptions,
            [
                "header:No Project",
                "task:b",
                "header:alpha",
                "task:c",
                "task:d",
                "header:beta",
                "task:a",
            ]
        )
    }

    func testGroupTasksSkipsCollapsedParentGroups() {
        let tasks = [
            makeTask(id: "a", project: "work.client1"),
            makeTask(id: "b", project: "work.client2"),
            makeTask(id: "c", project: "personal"),
        ]

        let rows = TaskListCoordinator.groupTasks(
            tasks,
            using: ProjectGroupingStrategy(),
            collapsedKeys: ["work"]
        )

        XCTAssertEqual(rows.count, 2)
        guard case let .header(header) = rows[0],
              case let .task(item) = rows[1]
        else {
            XCTFail("Expected header and task rows")
            return
        }
        XCTAssertEqual(header.displayName, "personal")
        XCTAssertEqual(item.task.uuid, "c")
    }
}

private func makeTask(id: String, urgency: Int? = nil, project: String? = nil) -> ApiTask {
    TestHelpers.makeTask(id: id, urgency: urgency, project: project)
}
