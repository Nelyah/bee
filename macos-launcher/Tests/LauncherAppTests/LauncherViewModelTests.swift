import AppKit
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

    func testBuildStatusMessageConcatenatesEvents() {
        let viewModel = LauncherViewModel()
        let events = [
            ApiEvent(kind: "info", message: "Added task."),
            ApiEvent(kind: "info", message: "Undo recorded.")
        ]

        let status = viewModel.buildStatusMessage(from: events)
        XCTAssertEqual(status, "Added task. Undo recorded.")
    }

    func testShouldAutoList() {
        let viewModel = LauncherViewModel()
        XCTAssertTrue(viewModel.shouldAutoList(actionName: ""))
        XCTAssertTrue(viewModel.shouldAutoList(actionName: "list"))
        XCTAssertFalse(viewModel.shouldAutoList(actionName: "add"))
    }

    func testShowToastAddsAndRemoves() async {
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        viewModel.showToast(message: "Boom", duration: 0.01)
        XCTAssertEqual(viewModel.toasts.count, 1)

        try? await Task.sleep(for: .milliseconds(20))
        XCTAssertTrue(viewModel.toasts.isEmpty)
    }

    func testLoadConfigErrorShowsToast() async {
        let mock = MockApiClient()
        mock.configResult = .failure(SampleError(message: "Config failed"))
        let viewModel = LauncherViewModel(apiClient: mock)

        await viewModel.loadConfig()

        XCTAssertEqual(viewModel.toasts.first?.message, "Config failed")
    }

    func testGhostTextAttributesUsesOverlayColorAndFont() {
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let attributes = ghostTextAttributes(font: font)

        XCTAssertEqual(attributes[.foregroundColor] as? NSColor, CatppuccinTheme.overlay0NS)
        XCTAssertEqual(attributes[.font] as? NSFont, font)
    }

    func testParseErrorToastIsDebounced() async {
        let mock = MockApiClient()
        let viewModel = LauncherViewModel(apiClient: mock, unexpectedTokenToastDelay: 0.05)

        mock.parseResult = .failure(SampleError(message: "Unexpected token A"))
        viewModel.handleInputChange("a")
        try? await Task.sleep(for: .milliseconds(20))

        mock.parseResult = .failure(SampleError(message: "could not parse the task property expression"))
        viewModel.handleInputChange("ab")
        try? await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(viewModel.toasts.count, 1)
        XCTAssertEqual(viewModel.toasts.first?.message, "could not parse the task property expression")
    }

    func testParseErrorToastWaitsUntilMenuCloses() async {
        let mock = MockApiClient()
        let viewModel = LauncherViewModel(apiClient: mock, unexpectedTokenToastDelay: 0.05)
        viewModel.showCompletionMenu = true

        mock.parseResult = .failure(SampleError(message: "parse error"))
        viewModel.handleInputChange("a")
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(viewModel.toasts.isEmpty)

        viewModel.clearCompletions()
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(viewModel.toasts.count, 1)
        XCTAssertEqual(viewModel.toasts.first?.message, "parse error")
    }

    func testDetectCompletionContextDetectsDatePrefixWithValue() {
        let viewModel = LauncherViewModel()
        viewModel.input = "due:tom"
        viewModel.cursorPosition = viewModel.input.count

        XCTAssertEqual(viewModel.detectCompletionContext(), .date)
    }

    func testSortTasksByUrgencyOrdersHighFirstAndNilLast() {
        let viewModel = LauncherViewModel()
        let tasks = [
            makeTask(id: "c", urgency: nil),
            makeTask(id: "a", urgency: 9),
            makeTask(id: "b", urgency: 2),
            makeTask(id: "d", urgency: nil),
            makeTask(id: "e", urgency: 9)
        ]

        let sorted = viewModel.sortTasksByUrgency(tasks)
        let ids = sorted.map { $0.uuid }

        XCTAssertEqual(ids, ["a", "e", "b", "c", "d"])
    }
}

/// Simple error for testing toast messaging.
private struct SampleError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

/// Build a minimal ApiTask for view model tests.
private func makeTask(id: String, urgency: Int? = nil) -> ApiTask {
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
        urgency: urgency
    )
}
