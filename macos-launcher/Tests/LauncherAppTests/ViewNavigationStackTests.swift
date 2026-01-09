import XCTest

@testable import LauncherApp

/// Tests for ViewNavigationStack - the navigation history manager.
final class ViewNavigationStackTests: XCTestCase {
    // MARK: - Initial State Tests

    func testInitialStateIsTaskList() {
        let stack = ViewNavigationStack()

        XCTAssertEqual(stack.current, .taskList)
        XCTAssertEqual(stack.currentMode, .list)
        XCTAssertFalse(stack.canGoBack)
        XCTAssertEqual(stack.depth, 1)
    }

    // MARK: - Push Tests

    func testPushTaskDetail() {
        let stack = ViewNavigationStack()

        stack.push(.taskDetail(uuid: "task-1", previousSelectedIndex: 0))

        XCTAssertEqual(stack.depth, 2)
        XCTAssertTrue(stack.canGoBack)
        XCTAssertEqual(stack.currentMode, .detail)
        XCTAssertTrue(stack.current.isDetailFor(uuid: "task-1"))
    }

    func testPushProjectOverview() {
        let stack = ViewNavigationStack()

        stack.push(.projectOverview)

        XCTAssertEqual(stack.depth, 2)
        XCTAssertTrue(stack.canGoBack)
        XCTAssertEqual(stack.currentMode, .projectOverview)
    }

    func testPushMultipleTaskDetails() {
        let stack = ViewNavigationStack()

        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 0))
        stack.push(.taskDetail(uuid: "B", previousSelectedIndex: 1))
        stack.push(.taskDetail(uuid: "C", previousSelectedIndex: 2))

        XCTAssertEqual(stack.depth, 4) // root + 3 details
        XCTAssertTrue(stack.current.isDetailFor(uuid: "C"))
    }

    func testPushDoesNotDuplicateConsecutiveEntries() {
        let stack = ViewNavigationStack()

        let entry = NavigationEntry.taskDetail(uuid: "A", previousSelectedIndex: 0)
        stack.push(entry)
        stack.push(entry) // Same entry again

        XCTAssertEqual(stack.depth, 2) // Only one detail entry added
    }

    func testPushDifferentEntriesWithSameUUID() {
        let stack = ViewNavigationStack()

        // Different previousSelectedIndex makes them different entries
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 0))
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 1))

        XCTAssertEqual(stack.depth, 3) // Both should be added
    }

    // MARK: - Pop Tests

    func testPopReturnsLastEntry() {
        let stack = ViewNavigationStack()
        stack.push(.taskDetail(uuid: "task-1", previousSelectedIndex: 5))

        let popped = stack.pop()

        XCTAssertEqual(popped, .taskDetail(uuid: "task-1", previousSelectedIndex: 5))
        XCTAssertEqual(stack.current, .taskList)
        XCTAssertFalse(stack.canGoBack)
    }

    func testPopAtRootReturnsNil() {
        let stack = ViewNavigationStack()

        let popped = stack.pop()

        XCTAssertNil(popped)
        XCTAssertEqual(stack.current, .taskList)
    }

    func testPopSequence() {
        let stack = ViewNavigationStack()
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 0))
        stack.push(.taskDetail(uuid: "B", previousSelectedIndex: 1))
        stack.push(.taskDetail(uuid: "C", previousSelectedIndex: 2))

        // Pop C -> B
        _ = stack.pop()
        XCTAssertTrue(stack.current.isDetailFor(uuid: "B"))

        // Pop B -> A
        _ = stack.pop()
        XCTAssertTrue(stack.current.isDetailFor(uuid: "A"))

        // Pop A -> List
        _ = stack.pop()
        XCTAssertEqual(stack.current, .taskList)

        // Cannot pop past root
        XCTAssertNil(stack.pop())
    }

    // MARK: - Reset Tests

    func testResetClearsToRoot() {
        let stack = ViewNavigationStack()
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 0))
        stack.push(.taskDetail(uuid: "B", previousSelectedIndex: 1))
        stack.push(.projectOverview)

        stack.reset()

        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.current, .taskList)
        XCTAssertFalse(stack.canGoBack)
    }

    // MARK: - Remove Entries For Task Tests

    func testRemoveEntriesForTaskRemovesMatchingEntries() {
        let stack = ViewNavigationStack()
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 0))
        stack.push(.taskDetail(uuid: "B", previousSelectedIndex: 1))
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 2)) // Another A

        stack.removeEntriesForTask(uuid: "A")

        XCTAssertEqual(stack.depth, 2) // root + B
        XCTAssertTrue(stack.current.isDetailFor(uuid: "B"))
    }

    func testRemoveEntriesForTaskKeepsRoot() {
        let stack = ViewNavigationStack()
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 0))

        stack.removeEntriesForTask(uuid: "A")

        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.current, .taskList)
    }

    func testRemoveEntriesForTaskDoesNotAffectOtherTasks() {
        let stack = ViewNavigationStack()
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 0))
        stack.push(.taskDetail(uuid: "B", previousSelectedIndex: 1))

        stack.removeEntriesForTask(uuid: "C") // Non-existent

        XCTAssertEqual(stack.depth, 3) // Unchanged
    }

    func testRemoveEntriesForTaskDoesNotAffectProjectOverview() {
        let stack = ViewNavigationStack()
        stack.push(.projectOverview)

        stack.removeEntriesForTask(uuid: "A")

        XCTAssertEqual(stack.depth, 2) // root + projectOverview
        XCTAssertEqual(stack.currentMode, .projectOverview)
    }

    // MARK: - Max Depth Tests

    func testMaxDepthEnforced() {
        let stack = ViewNavigationStack()

        // Push more than max depth
        for i in 0 ..< 30 {
            stack.push(.taskDetail(uuid: "task-\(i)", previousSelectedIndex: i))
        }

        XCTAssertEqual(stack.depth, ViewNavigationStack.maxDepth)
        // Root should still be preserved
        XCTAssertEqual(stack.entries.first, .taskList)
    }

    // MARK: - PopUntil Tests

    func testPopUntilStopsAtMatchingEntry() {
        let stack = ViewNavigationStack()
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 0))
        stack.push(.projectOverview)
        stack.push(.taskDetail(uuid: "B", previousSelectedIndex: 1))

        let result = stack.popUntil { entry in
            if case .projectOverview = entry { return true }
            return false
        }

        XCTAssertEqual(result, .projectOverview)
        XCTAssertEqual(stack.currentMode, .projectOverview)
    }

    func testPopUntilStopsAtRoot() {
        let stack = ViewNavigationStack()
        stack.push(.taskDetail(uuid: "A", previousSelectedIndex: 0))

        let result = stack.popUntil { _ in false } // Never matches

        XCTAssertEqual(result, .taskList)
    }
}

// MARK: - NavigationEntry Tests

final class NavigationEntryTests: XCTestCase {
    func testModeConversion() {
        XCTAssertEqual(NavigationEntry.taskList.mode, .list)
        XCTAssertEqual(NavigationEntry.taskDetail(uuid: "x", previousSelectedIndex: nil).mode, .detail)
        XCTAssertEqual(NavigationEntry.projectOverview.mode, .projectOverview)
    }

    func testIsDetailForUUID() {
        let entry = NavigationEntry.taskDetail(uuid: "test-uuid", previousSelectedIndex: 0)

        XCTAssertTrue(entry.isDetailFor(uuid: "test-uuid"))
        XCTAssertFalse(entry.isDetailFor(uuid: "other-uuid"))
    }

    func testIsDetailForUUIDReturnsFalseForOtherTypes() {
        XCTAssertFalse(NavigationEntry.taskList.isDetailFor(uuid: "any"))
        XCTAssertFalse(NavigationEntry.projectOverview.isDetailFor(uuid: "any"))
    }

    func testTaskUUIDExtraction() {
        let detailEntry = NavigationEntry.taskDetail(uuid: "test-uuid", previousSelectedIndex: 0)
        XCTAssertEqual(detailEntry.taskUUID, "test-uuid")

        XCTAssertNil(NavigationEntry.taskList.taskUUID)
        XCTAssertNil(NavigationEntry.projectOverview.taskUUID)
    }

    func testEquality() {
        let entry1 = NavigationEntry.taskDetail(uuid: "A", previousSelectedIndex: 0)
        let entry2 = NavigationEntry.taskDetail(uuid: "A", previousSelectedIndex: 0)
        let entry3 = NavigationEntry.taskDetail(uuid: "A", previousSelectedIndex: 1)
        let entry4 = NavigationEntry.taskDetail(uuid: "B", previousSelectedIndex: 0)

        XCTAssertEqual(entry1, entry2)
        XCTAssertNotEqual(entry1, entry3) // Different previousSelectedIndex
        XCTAssertNotEqual(entry1, entry4) // Different uuid
    }
}
