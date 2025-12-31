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

    // MARK: - Selection Navigation Tests (for scroll behavior)

    /// Tests that selection navigation updates selectionIndex correctly through items.
    /// The view uses selectionIndex changes to trigger scrollTo for keyboard navigation.
    func testMoveSelectionUpdatesIndexForScrolling() {
        let coordinator = CommandPaletteCoordinator()

        // Register a contributor with multiple items
        coordinator.dataSource.register(TestMultiItemContributor())
        _ = coordinator.open(context: CommandPaletteContext())

        let items = coordinator.selectableItems
        XCTAssertEqual(items.count, 5, "Should have 5 test items")

        // Verify initial state
        XCTAssertEqual(coordinator.selectionIndex, 0)

        // Navigate down through items
        coordinator.moveSelection(delta: 1)
        XCTAssertEqual(coordinator.selectionIndex, 1)

        coordinator.moveSelection(delta: 1)
        XCTAssertEqual(coordinator.selectionIndex, 2)

        // Navigate up
        coordinator.moveSelection(delta: -1)
        XCTAssertEqual(coordinator.selectionIndex, 1)
    }

    /// Tests that each selectable item has a unique ID for scroll targeting.
    func testSelectableItemsHaveUniqueIdsForScrolling() {
        let coordinator = CommandPaletteCoordinator()
        coordinator.dataSource.register(TestMultiItemContributor())
        _ = coordinator.open(context: CommandPaletteContext())

        let items = coordinator.selectableItems
        let ids = items.map(\.id)

        // All IDs should be unique
        XCTAssertEqual(Set(ids).count, ids.count, "All item IDs must be unique for scrollTo to work")

        // All IDs should be non-empty
        for id in ids {
            XCTAssertFalse(id.isEmpty, "Item IDs must not be empty")
        }
    }

    /// Tests that selection clamps at boundaries (doesn't scroll past edges).
    func testSelectionClampsAtBoundariesForScrolling() {
        let coordinator = CommandPaletteCoordinator()
        coordinator.dataSource.register(TestMultiItemContributor())
        _ = coordinator.open(context: CommandPaletteContext())

        let itemCount = coordinator.selectableItems.count
        XCTAssertEqual(itemCount, 5)

        // Start at first item
        XCTAssertEqual(coordinator.selectionIndex, 0)

        // Navigate up at top should stay at 0 (clamped)
        coordinator.moveSelection(delta: -1)
        XCTAssertEqual(coordinator.selectionIndex, 0, "Selection should clamp at top")

        // Navigate to last item
        coordinator.selectionIndex = itemCount - 1
        XCTAssertEqual(coordinator.selectionIndex, 4)

        // Navigate down at bottom should stay at last (clamped)
        coordinator.moveSelection(delta: 1)
        XCTAssertEqual(coordinator.selectionIndex, 4, "Selection should clamp at bottom")
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

// MARK: - Test Helpers

/// Test contributor that provides multiple items for selection/scroll testing.
private struct TestMultiItemContributor: CommandPaletteSectionContributor {
    var contributorId: String { "test-multi" }
    var priority: Int { 0 }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        let items: [CommandPaletteItem] = (1 ... 5).map { index in
            .action(CommandPaletteActionItem(
                id: "test-item-\(index)",
                title: "Test Item \(index)",
                subtitle: nil,
                icon: .system("circle"),
                handler: {}
            ))
        }
        return [CommandPaletteSection(id: "test-section", title: "Test", items: items)]
    }
}
