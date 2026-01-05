@testable import LauncherApp
import XCTest

@MainActor
final class MultiSelectTests: XCTestCase {
    func testMultiSelectPersistsDuringTyping() {
        // Regression test: multi-selection should NOT be cleared when typing in input
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            TestHelpers.makeTask(id: "task-a"),
            TestHelpers.makeTask(id: "task-b"),
            TestHelpers.makeTask(id: "task-c"),
        ]

        // Navigate to first task and multi-select it (toggle also moves down)
        viewModel.moveSelection(delta: 1) // header
        viewModel.moveSelection(delta: 1) // task-a
        _ = viewModel.toggleMultiSelectAtCursor() // selects task-a, moves to task-b

        // Toggle again - now on task-b, which gets selected and moves to task-c
        _ = viewModel.toggleMultiSelectAtCursor()

        // Verify 2 tasks are selected
        XCTAssertEqual(viewModel.multiSelectCount, 2)
        XCTAssertTrue(viewModel.isMultiSelected(uuid: "task-a"))
        XCTAssertTrue(viewModel.isMultiSelected(uuid: "task-b"))

        // Type something - this should NOT clear the multi-selection
        viewModel.handleInputChange("done")

        // Multi-selection should still be present
        XCTAssertEqual(viewModel.multiSelectCount, 2, "Multi-selection should persist while typing")
        XCTAssertTrue(viewModel.isMultiSelected(uuid: "task-a"))
        XCTAssertTrue(viewModel.isMultiSelected(uuid: "task-b"))
    }

    func testMultiSelectClearsOnEscape() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            TestHelpers.makeTask(id: "task-a"),
            TestHelpers.makeTask(id: "task-b"),
        ]

        // Navigate and select
        viewModel.moveSelection(delta: 1) // header
        viewModel.moveSelection(delta: 1) // task-a
        _ = viewModel.toggleMultiSelectAtCursor()

        XCTAssertEqual(viewModel.multiSelectCount, 1)

        // Escape should clear multi-selection
        _ = viewModel.handleEscape()

        XCTAssertEqual(viewModel.multiSelectCount, 0, "Escape should clear multi-selection")
    }

    func testToggleMultiSelectAtCursor() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            TestHelpers.makeTask(id: "task-a"),
            TestHelpers.makeTask(id: "task-b"),
        ]

        // Navigate to task-a
        viewModel.moveSelection(delta: 1) // header
        viewModel.moveSelection(delta: 1) // task-a

        // Toggle on task-a (cursor moves to task-b after)
        let toggled = viewModel.toggleMultiSelectAtCursor()
        XCTAssertTrue(toggled)
        XCTAssertTrue(viewModel.isMultiSelected(uuid: "task-a"))

        // Toggle on task-b (cursor moves but we're at last task)
        _ = viewModel.toggleMultiSelectAtCursor()
        XCTAssertTrue(viewModel.isMultiSelected(uuid: "task-b"))

        // Both tasks should now be selected
        XCTAssertEqual(viewModel.multiSelectCount, 2)

        // Toggle off task-a directly
        viewModel.toggleMultiSelect(uuid: "task-a")
        XCTAssertFalse(viewModel.isMultiSelected(uuid: "task-a"))
        XCTAssertEqual(viewModel.multiSelectCount, 1)
    }

    func testToggleMultiSelectOnHeaderReturnsFalse() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [TestHelpers.makeTask(id: "task-a")]

        // Navigate to header (row 0)
        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedRowIndex, 0)

        // Toggle should fail on header
        let toggled = viewModel.toggleMultiSelectAtCursor()
        XCTAssertFalse(toggled, "Toggle should return false when on group header")
        XCTAssertEqual(viewModel.multiSelectCount, 0)
    }

    func testToggleMultiSelectMovesCursorDown() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            TestHelpers.makeTask(id: "task-a"),
            TestHelpers.makeTask(id: "task-b"),
            TestHelpers.makeTask(id: "task-c"),
        ]

        // Navigate to task-a (row index 1, after header)
        viewModel.moveSelection(delta: 1) // header (row 0)
        viewModel.moveSelection(delta: 1) // task-a (row 1)
        XCTAssertEqual(viewModel.selectedRowIndex, 1)

        // Toggle should select task-a and move cursor to task-b
        _ = viewModel.toggleMultiSelectAtCursor()
        XCTAssertTrue(viewModel.isMultiSelected(uuid: "task-a"))
        XCTAssertEqual(viewModel.selectedRowIndex, 2, "Cursor should move down after toggle")

        // Toggle again should select task-b and move to task-c
        _ = viewModel.toggleMultiSelectAtCursor()
        XCTAssertTrue(viewModel.isMultiSelected(uuid: "task-b"))
        XCTAssertEqual(viewModel.selectedRowIndex, 3, "Cursor should move down after toggle")

        // Toggle at last task should still work (cursor stays at last)
        _ = viewModel.toggleMultiSelectAtCursor()
        XCTAssertTrue(viewModel.isMultiSelected(uuid: "task-c"))
        XCTAssertEqual(viewModel.multiSelectCount, 3)
    }
}
