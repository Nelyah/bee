@testable import LauncherApp
import XCTest

@MainActor
final class CommandPaletteCoordinatorTests: XCTestCase {
    // MARK: - Lifecycle Tests

    func testOpenWithContextInitializesStack() {
        let coordinator = CommandPaletteCoordinator()
        let context = CommandPaletteContext(hasSelectedTask: true)

        _ = coordinator.open(context: context)

        XCTAssertTrue(coordinator.isPresented)
        XCTAssertFalse(coordinator.navigationStack.stack.isEmpty)
        XCTAssertTrue(coordinator.isAtRoot)
    }

    func testOpenResetsState() {
        let coordinator = CommandPaletteCoordinator()
        coordinator.query = "foo"
        coordinator.selectionIndex = 2

        _ = coordinator.open(context: CommandPaletteContext())

        XCTAssertTrue(coordinator.isPresented)
        XCTAssertEqual(coordinator.query, "")
        XCTAssertEqual(coordinator.selectionIndex, 0)
    }

    func testClosesClearsStack() {
        let coordinator = CommandPaletteCoordinator()
        _ = coordinator.open(context: CommandPaletteContext())

        coordinator.close()

        XCTAssertFalse(coordinator.isPresented)
        XCTAssertTrue(coordinator.navigationStack.stack.isEmpty)
    }

    // MARK: - Navigation Tests

    func testHandleEscapeAtRootReturnsFalse() {
        let coordinator = CommandPaletteCoordinator()
        _ = coordinator.open(context: CommandPaletteContext())

        let handled = coordinator.handleEscape()

        XCTAssertFalse(handled)
        XCTAssertTrue(coordinator.isAtRoot)
    }

    func testHandleEscapeFromNestedMenuPopsStack() {
        let coordinator = CommandPaletteCoordinator()
        _ = coordinator.open(context: CommandPaletteContext())

        // Push a submenu
        let submenu = CommandPaletteMenu(
            id: "submenu",
            title: "Submenu",
            sections: []
        )
        coordinator.pushMenu(submenu)
        XCTAssertFalse(coordinator.isAtRoot)
        XCTAssertEqual(coordinator.navigationStack.depth, 2)

        // Escape should pop back to root
        let handled = coordinator.handleEscape()

        XCTAssertTrue(handled)
        XCTAssertTrue(coordinator.isAtRoot)
        XCTAssertEqual(coordinator.query, "")
        XCTAssertEqual(coordinator.selectionIndex, 0)
    }

    func testNavigateBackPopsStack() {
        let coordinator = CommandPaletteCoordinator()
        _ = coordinator.open(context: CommandPaletteContext())

        let submenu = CommandPaletteMenu(id: "sub", title: "Sub", sections: [])
        coordinator.pushMenu(submenu)
        coordinator.query = "test"
        coordinator.selectionIndex = 3

        coordinator.navigateBack()

        XCTAssertTrue(coordinator.isAtRoot)
        XCTAssertEqual(coordinator.query, "")
        XCTAssertEqual(coordinator.selectionIndex, 0)
    }

    func testPushMenuAddsToStack() {
        let coordinator = CommandPaletteCoordinator()
        _ = coordinator.open(context: CommandPaletteContext())

        let menu = CommandPaletteMenu(id: "new", title: "New Menu", sections: [])
        coordinator.pushMenu(menu)

        XCTAssertEqual(coordinator.navigationStack.depth, 2)
        XCTAssertEqual(coordinator.breadcrumb, ["Command Palette", "New Menu"])
    }

    // MARK: - Selection Tests

    func testMoveSelectionWithEmptyItems() {
        let coordinator = CommandPaletteCoordinator()
        coordinator.selectionIndex = 0

        // Without any items, should stay at 0
        coordinator.moveSelection(delta: 1)
        XCTAssertEqual(coordinator.selectionIndex, 0)
    }

    func testResetSelection() {
        let coordinator = CommandPaletteCoordinator()
        coordinator.selectionIndex = 5

        coordinator.resetSelection()

        XCTAssertEqual(coordinator.selectionIndex, 0)
    }

    // MARK: - Context Tests

    func testContextIsUpdated() {
        let coordinator = CommandPaletteCoordinator()
        let context1 = CommandPaletteContext(hasSelectedTask: false)
        let context2 = CommandPaletteContext(hasSelectedTask: true, selectedTaskUUID: "abc-123")

        _ = coordinator.open(context: context1)
        XCTAssertFalse(coordinator.context.hasSelectedTask)

        coordinator.updateContext(context2)
        XCTAssertTrue(coordinator.context.hasSelectedTask)
        XCTAssertEqual(coordinator.context.selectedTaskUUID, "abc-123")
    }
}
