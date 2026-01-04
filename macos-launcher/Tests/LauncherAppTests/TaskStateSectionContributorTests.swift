import XCTest

@testable import LauncherApp

@MainActor
final class TaskStateSectionContributorTests: XCTestCase {
    // MARK: - Section Building Tests

    func testReturnsEmptyWhenNoTaskSelected() {
        let contributor = TaskStateSectionContributor(
            onTaskStateChange: { _, _ in }
        )

        // Context with no selected task
        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertTrue(sections.isEmpty, "Should return empty sections when no task is selected")
    }

    func testReturnsFourItemsWhenTaskSelected() {
        let contributor = TaskStateSectionContributor(
            onTaskStateChange: { _, _ in }
        )

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid-123"
        )
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].id, "taskState")
        XCTAssertEqual(sections[0].title, "Mark task as...")
        XCTAssertEqual(sections[0].items.count, 4)
    }

    func testItemsHaveCorrectIdsAndTitles() {
        let contributor = TaskStateSectionContributor(
            onTaskStateChange: { _, _ in }
        )

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid-123"
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let items = sections.first?.items else {
            return XCTFail("Expected items in section")
        }

        // Check item IDs and titles
        let expectedItems: [(id: String, title: String)] = [
            ("task-complete", "Completed"),
            ("task-active", "Active"),
            ("task-pending", "Pending"),
            ("task-delete", "Deleted"),
        ]

        for (index, expected) in expectedItems.enumerated() {
            if case let .action(actionItem) = items[index] {
                XCTAssertEqual(actionItem.id, expected.id, "Item \(index) should have id '\(expected.id)'")
                XCTAssertEqual(actionItem.title, expected.title, "Item \(index) should have title '\(expected.title)'")
            } else {
                XCTFail("Item \(index) should be an action item")
            }
        }
    }

    func testItemsHaveCorrectIcons() {
        let contributor = TaskStateSectionContributor(
            onTaskStateChange: { _, _ in }
        )

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid-123"
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let items = sections.first?.items else {
            return XCTFail("Expected items in section")
        }

        let expectedIcons: [CommandPaletteIcon] = [
            .system("checkmark.circle"),
            .system("play.circle"),
            .system("pause.circle"),
            .system("trash"),
        ]

        for (index, expectedIcon) in expectedIcons.enumerated() {
            if case let .action(actionItem) = items[index] {
                XCTAssertEqual(actionItem.icon, expectedIcon, "Item \(index) should have expected icon")
            }
        }
    }

    func testCompleteActionCallsHandler() {
        var receivedAction: TaskStateAction?
        var receivedUUID: String?

        let contributor = TaskStateSectionContributor(
            onTaskStateChange: { action, uuid in
                receivedAction = action
                receivedUUID = uuid
            }
        )

        let testUUID = "test-uuid-complete"
        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: testUUID
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let items = sections.first?.items,
              case let .action(actionItem) = items[0]
        else {
            return XCTFail("Expected action item at index 0")
        }

        actionItem.handler()

        XCTAssertEqual(receivedAction, .complete)
        XCTAssertEqual(receivedUUID, testUUID)
    }

    func testActiveActionCallsHandler() {
        var receivedAction: TaskStateAction?
        var receivedUUID: String?

        let contributor = TaskStateSectionContributor(
            onTaskStateChange: { action, uuid in
                receivedAction = action
                receivedUUID = uuid
            }
        )

        let testUUID = "test-uuid-active"
        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: testUUID
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let items = sections.first?.items,
              case let .action(actionItem) = items[1]
        else {
            return XCTFail("Expected action item at index 1")
        }

        actionItem.handler()

        XCTAssertEqual(receivedAction, .start)
        XCTAssertEqual(receivedUUID, testUUID)
    }

    func testPendingActionCallsHandler() {
        var receivedAction: TaskStateAction?
        var receivedUUID: String?

        let contributor = TaskStateSectionContributor(
            onTaskStateChange: { action, uuid in
                receivedAction = action
                receivedUUID = uuid
            }
        )

        let testUUID = "test-uuid-pending"
        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: testUUID
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let items = sections.first?.items,
              case let .action(actionItem) = items[2]
        else {
            return XCTFail("Expected action item at index 2")
        }

        actionItem.handler()

        XCTAssertEqual(receivedAction, .stop)
        XCTAssertEqual(receivedUUID, testUUID)
    }

    func testDeleteActionCallsHandler() {
        var receivedAction: TaskStateAction?
        var receivedUUID: String?

        let contributor = TaskStateSectionContributor(
            onTaskStateChange: { action, uuid in
                receivedAction = action
                receivedUUID = uuid
            }
        )

        let testUUID = "test-uuid-delete"
        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: testUUID
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let items = sections.first?.items,
              case let .action(actionItem) = items[3]
        else {
            return XCTFail("Expected action item at index 3")
        }

        actionItem.handler()

        XCTAssertEqual(receivedAction, .delete)
        XCTAssertEqual(receivedUUID, testUUID)
    }

    func testContributorPriority() {
        let contributor = TaskStateSectionContributor(
            onTaskStateChange: { _, _ in }
        )

        XCTAssertEqual(contributor.contributorId, "taskState")
        XCTAssertEqual(contributor.priority, 3)
    }
}

// MARK: - TaskStateAction Tests

final class TaskStateActionTests: XCTestCase {
    func testApiActionMapping() {
        XCTAssertEqual(TaskStateAction.complete.apiAction, "done")
        XCTAssertEqual(TaskStateAction.delete.apiAction, "delete")
        XCTAssertEqual(TaskStateAction.start.apiAction, "start")
        XCTAssertEqual(TaskStateAction.stop.apiAction, "stop")
    }

    func testSuccessMessageMapping() {
        XCTAssertEqual(TaskStateAction.complete.successMessage, "Task marked complete")
        XCTAssertEqual(TaskStateAction.delete.successMessage, "Task deleted")
        XCTAssertEqual(TaskStateAction.start.successMessage, "Task started")
        XCTAssertEqual(TaskStateAction.stop.successMessage, "Task set to pending")
    }
}
