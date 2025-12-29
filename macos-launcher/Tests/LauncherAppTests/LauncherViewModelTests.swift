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

    func testBuildHighlightSpansActionProjectTag() {
        let tokens = [
            TokenSpan(tokenType: "WordString", literal: "this", start: 0, end: 4),
            TokenSpan(tokenType: "Blank", literal: " ", start: 4, end: 5),
            TokenSpan(tokenType: "WordString", literal: "is", start: 5, end: 7),
            TokenSpan(tokenType: "Blank", literal: " ", start: 7, end: 8),
            TokenSpan(tokenType: "WordString", literal: "add", start: 8, end: 11),
            TokenSpan(tokenType: "Blank", literal: " ", start: 11, end: 12),
            TokenSpan(tokenType: "ProjectPrefix", literal: "proj:", start: 12, end: 17),
            TokenSpan(tokenType: "WordString", literal: "abc", start: 17, end: 20),
            TokenSpan(tokenType: "Blank", literal: " ", start: 20, end: 21),
            TokenSpan(tokenType: "TagPlusPrefix", literal: "+", start: 21, end: 22),
            TokenSpan(tokenType: "WordString", literal: "tag", start: 22, end: 25)
        ]

        let spans = buildHighlightSpans(tokens: tokens, actionName: "add")
        XCTAssertEqual(spans.count, 3)

        XCTAssertTrue(spans.contains { $0.start == 8 && $0.end == 11 && $0.kind == .action })
        XCTAssertTrue(spans.contains { $0.start == 12 && $0.end == 20 && $0.kind == .project })
        XCTAssertTrue(spans.contains { $0.start == 21 && $0.end == 25 && $0.kind == .tag })
        XCTAssertFalse(spans.contains { $0.start == 0 && $0.end == 4 })
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
