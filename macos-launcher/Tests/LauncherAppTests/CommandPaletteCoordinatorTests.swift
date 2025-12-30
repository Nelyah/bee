import XCTest
@testable import LauncherApp

@MainActor
final class CommandPaletteCoordinatorTests: XCTestCase {
    func testOpenRequiresSelectedTask() {
        let coordinator = CommandPaletteCoordinator()
        let message = coordinator.open(hasSelectedTask: false)
        XCTAssertEqual(message, "Select a task to add a link.")
        XCTAssertFalse(coordinator.isPresented)
    }

    func testOpenResetsState() {
        let coordinator = CommandPaletteCoordinator()
        coordinator.mode = .addGitlab
        coordinator.query = "foo"
        coordinator.selectionIndex = 2

        let message = coordinator.open(hasSelectedTask: true)
        XCTAssertNil(message)
        XCTAssertTrue(coordinator.isPresented)
        XCTAssertEqual(coordinator.mode, .root)
        XCTAssertEqual(coordinator.query, "")
        XCTAssertEqual(coordinator.selectionIndex, 0)
    }

    func testFilteredSuggestionsAddsRawInput() {
        let coordinator = CommandPaletteCoordinator()
        coordinator.mode = .addJira
        coordinator.query = "ABC-1"
        coordinator.setJiraSuggestions([
            JiraIssueSuggestion(
                key: "ABC-1",
                summary: "Fix regression",
                status: "In Progress",
                webURL: "https://example.com",
                updatedAt: "2025-01-01T00:00:00Z"
            )
        ])

        let suggestions = coordinator.filteredSuggestions
        XCTAssertEqual(suggestions.first?.id, "raw-ABC-1")
        XCTAssertEqual(suggestions.count, 2)
    }

    func testMoveSelectionClampsToBounds() {
        let coordinator = CommandPaletteCoordinator()
        coordinator.selectionIndex = 0
        coordinator.moveSelection(delta: -1, maxCount: 3)
        XCTAssertEqual(coordinator.selectionIndex, 0)

        coordinator.selectionIndex = 2
        coordinator.moveSelection(delta: 1, maxCount: 3)
        XCTAssertEqual(coordinator.selectionIndex, 2)
    }
}
