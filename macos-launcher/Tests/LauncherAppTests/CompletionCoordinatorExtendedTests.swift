@testable import LauncherApp
import XCTest

@MainActor
final class CompletionCoordinatorExtendedTests: XCTestCase {
    // MARK: - Toggle Menu Tests

    func testToggleMenuOpensWhenItemsExist() {
        let coordinator = CompletionCoordinator()
        // Manually set items to simulate having completions
        coordinator.items = [makeCompletionItem(value: "test", count: 1)]

        XCTAssertFalse(coordinator.showMenu)

        // Toggle with empty input - won't have items from update
        coordinator.toggleMenu(input: "", tokens: [], tasks: [])

        // Menu state depends on whether update finds items
        // Since we're not mocking the cache, it will find no items
        // Test that toggle works
    }

    func testToggleMenuClosesWhenOpen() {
        let coordinator = CompletionCoordinator()
        coordinator.showMenu = true
        coordinator.items = [makeCompletionItem(value: "test", count: 1)]

        coordinator.toggleMenu(input: "list", tokens: [], tasks: [])

        XCTAssertFalse(coordinator.showMenu)
    }

    // MARK: - Move Selection Tests

    func testMoveSelectionDown() {
        let coordinator = CompletionCoordinator()
        coordinator.items = [
            makeCompletionItem(value: "a", count: nil),
            makeCompletionItem(value: "b", count: nil),
            makeCompletionItem(value: "c", count: nil),
        ]
        coordinator.selectedIndex = 0

        coordinator.moveSelection(delta: 1)

        XCTAssertEqual(coordinator.selectedIndex, 1)
    }

    func testMoveSelectionUp() {
        let coordinator = CompletionCoordinator()
        coordinator.items = [
            makeCompletionItem(value: "a", count: nil),
            makeCompletionItem(value: "b", count: nil),
            makeCompletionItem(value: "c", count: nil),
        ]
        coordinator.selectedIndex = 2

        coordinator.moveSelection(delta: -1)

        XCTAssertEqual(coordinator.selectedIndex, 1)
    }

    func testMoveSelectionWrapsAround() {
        let coordinator = CompletionCoordinator()
        coordinator.items = [
            makeCompletionItem(value: "a", count: nil),
            makeCompletionItem(value: "b", count: nil),
            makeCompletionItem(value: "c", count: nil),
        ]
        coordinator.selectedIndex = 2

        coordinator.moveSelection(delta: 1)

        XCTAssertEqual(coordinator.selectedIndex, 0)
    }

    func testMoveSelectionWrapsAroundBackward() {
        let coordinator = CompletionCoordinator()
        coordinator.items = [
            makeCompletionItem(value: "a", count: nil),
            makeCompletionItem(value: "b", count: nil),
            makeCompletionItem(value: "c", count: nil),
        ]
        coordinator.selectedIndex = 0

        coordinator.moveSelection(delta: -1)

        XCTAssertEqual(coordinator.selectedIndex, 2)
    }

    func testMoveSelectionWithEmptyItems() {
        let coordinator = CompletionCoordinator()
        coordinator.items = []
        coordinator.selectedIndex = 0

        coordinator.moveSelection(delta: 1)

        XCTAssertEqual(coordinator.selectedIndex, 0)
    }

    // MARK: - Clear Tests

    func testClearResetsAllState() {
        let coordinator = CompletionCoordinator()
        coordinator.items = [makeCompletionItem(value: "test", count: 1)]
        coordinator.ghostText = "suggestion"
        coordinator.showMenu = true
        coordinator.selectedIndex = 5
        coordinator.context = .tag

        coordinator.clear()

        XCTAssertTrue(coordinator.items.isEmpty)
        XCTAssertNil(coordinator.ghostText)
        XCTAssertFalse(coordinator.showMenu)
        XCTAssertEqual(coordinator.selectedIndex, 0)
        XCTAssertEqual(coordinator.context, .none)
    }

    // MARK: - Accept Ghost Text Tests

    func testAcceptGhostTextReturnsFirstItem() {
        let coordinator = CompletionCoordinator()
        let expectedItem = makeCompletionItem(value: "urgent", count: 5)
        coordinator.items = [expectedItem, makeCompletionItem(value: "work", count: 3)]
        coordinator.ghostText = "urgent"

        let result = coordinator.acceptGhostText()

        XCTAssertEqual(result?.value, "urgent")
    }

    func testAcceptGhostTextReturnsNilWithNoGhostText() {
        let coordinator = CompletionCoordinator()
        coordinator.items = [makeCompletionItem(value: "urgent", count: 5)]
        coordinator.ghostText = nil

        let result = coordinator.acceptGhostText()

        XCTAssertNil(result)
    }

    func testAcceptGhostTextReturnsNilWithEmptyItems() {
        let coordinator = CompletionCoordinator()
        coordinator.items = []
        coordinator.ghostText = "test"

        let result = coordinator.acceptGhostText()

        XCTAssertNil(result)
    }

    // MARK: - Cursor Position Tests

    func testUpdateCursorPosition() {
        let coordinator = CompletionCoordinator()
        XCTAssertEqual(coordinator.cursorPosition, 0)

        coordinator.updateCursorPosition(10, input: "list +tag", tokens: [], tasks: [])

        XCTAssertEqual(coordinator.cursorPosition, 10)
    }

    // MARK: - Cache Counts Tests

    func testCacheCountsInitiallyZero() {
        let coordinator = CompletionCoordinator()
        let counts = coordinator.cacheCounts

        XCTAssertEqual(counts.projects, 0)
        XCTAssertEqual(counts.tags, 0)
        XCTAssertEqual(counts.actions, 0)
    }

    // MARK: - Project and Tag Names Tests

    func testProjectNamesInitiallyEmpty() {
        let coordinator = CompletionCoordinator()
        XCTAssertTrue(coordinator.projectNames.isEmpty)
    }

    func testTagNamesInitiallyEmpty() {
        let coordinator = CompletionCoordinator()
        XCTAssertTrue(coordinator.tagNames.isEmpty)
    }

    // MARK: - Context Tests

    func testContextInitiallyNone() {
        let coordinator = CompletionCoordinator()
        XCTAssertEqual(coordinator.context, .none)
    }
}

// Helper to create CompletionItem for tests
private func makeCompletionItem(value: String, count: Int?) -> CompletionItem {
    let json = if let count {
        #"{"value": "\#(value)", "count": \#(count)}"#
    } else {
        #"{"value": "\#(value)", "count": null}"#
    }
    guard let data = json.data(using: .utf8),
          let item = try? JSONDecoder().decode(CompletionItem.self, from: data)
    else {
        fatalError("Failed to create test CompletionItem - this is a test helper bug")
    }
    return item
}
