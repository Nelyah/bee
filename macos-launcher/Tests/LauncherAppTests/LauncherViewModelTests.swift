import XCTest
@testable import LauncherApp

@MainActor
final class LauncherViewModelTests: XCTestCase {
    func testMoveSelectionWrapsForward() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            makeTask(id: "a"),
            makeTask(id: "b"),
            makeTask(id: "c")
        ]

        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedIndex, 1)

        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedIndex, 2)

        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testMoveSelectionWrapsBackward() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            makeTask(id: "a"),
            makeTask(id: "b")
        ]

        viewModel.moveSelection(delta: -1)
        XCTAssertEqual(viewModel.selectedIndex, 1)

        viewModel.moveSelection(delta: -1)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testSyncSelectionAfterTasksUpdate() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            makeTask(id: "a"),
            makeTask(id: "b")
        ]
        viewModel.selectedIndex = 1

        viewModel.tasks = [makeTask(id: "a")]
        viewModel.syncSelectionAfterTasksUpdate()
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.tasks = []
        viewModel.syncSelectionAfterTasksUpdate()
        XCTAssertNil(viewModel.selectedIndex)
    }
}

/// Build a minimal ApiTask for view model tests.
private func makeTask(id: String) -> ApiTask {
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
        urgency: nil
    )
}
