import AppKit
import XCTest
@testable import LauncherApp

@MainActor
final class LauncherViewModelTests: XCTestCase {
    func testMoveSelectionClampsAtEnd() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            makeTask(id: "a"),
            makeTask(id: "b"),
            makeTask(id: "c")
        ]
        // Grouped rows: [header("No Project"), task(a,0), task(b,1), task(c,2)]
        // Navigation now includes headers

        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedRowIndex, 0) // header
        XCTAssertNil(viewModel.selectedIndex) // no task selected yet

        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedRowIndex, 1) // task a
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedRowIndex, 2) // task b
        XCTAssertEqual(viewModel.selectedIndex, 1)

        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedRowIndex, 3) // task c
        XCTAssertEqual(viewModel.selectedIndex, 2)

        viewModel.moveSelection(delta: 1)
        XCTAssertEqual(viewModel.selectedRowIndex, 3) // clamped at last row
        XCTAssertEqual(viewModel.selectedIndex, 2) // stays at last task
    }

    func testMoveSelectionClampsAtStart() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            makeTask(id: "a"),
            makeTask(id: "b")
        ]
        // Grouped rows: [header("No Project"), task(a,0), task(b,1)]

        viewModel.moveSelection(delta: -1)
        XCTAssertEqual(viewModel.selectedRowIndex, 2) // last row (task b)
        XCTAssertEqual(viewModel.selectedIndex, 1)

        viewModel.moveSelection(delta: -1)
        XCTAssertEqual(viewModel.selectedRowIndex, 1) // task a
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.moveSelection(delta: -1)
        XCTAssertEqual(viewModel.selectedRowIndex, 0) // header
        XCTAssertEqual(viewModel.selectedIndex, 0) // stays at task a

        viewModel.moveSelection(delta: -1)
        XCTAssertEqual(viewModel.selectedRowIndex, 0) // clamped at first row
        XCTAssertEqual(viewModel.selectedIndex, 0) // stays at task a
    }

    func testSubmitInvalidParseKeepsInputAndShowsToast() {
        let viewModel = LauncherViewModel()
        viewModel.input = "bad query"

        viewModel.handleSubmit()

        XCTAssertEqual(viewModel.input, "bad query")
        XCTAssertEqual(viewModel.toasts.count, 1)
        XCTAssertEqual(viewModel.toasts.first?.message, "Invalid request")
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

    func testLoadCollapsedStateRestoresKeys() {
        let defaults = UserDefaults.standard
        defaults.set(["work", "personal"], forKey: UserDefaultsKeys.collapsedGroups)
        defaults.set(true, forKey: UserDefaultsKeys.collapsedNilGroup)
        defer { clearCollapsedDefaults() }

        let viewModel = LauncherViewModel()
        viewModel.loadCollapsedState()

        XCTAssertTrue(viewModel.collapsedGroups.contains("work"))
        XCTAssertTrue(viewModel.collapsedGroups.contains("personal"))
        XCTAssertTrue(viewModel.collapsedGroups.contains(nil))
    }

    func testToggleGroupCollapsePersistsKeys() {
        defer { clearCollapsedDefaults() }
        let viewModel = LauncherViewModel()

        viewModel.toggleGroupCollapse("work")
        let saved = Set(UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.collapsedGroups) ?? [])
        XCTAssertEqual(saved, ["work"])
        XCTAssertFalse(UserDefaults.standard.bool(forKey: UserDefaultsKeys.collapsedNilGroup))

        viewModel.toggleGroupCollapse(nil)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: UserDefaultsKeys.collapsedNilGroup))
    }

    func testBuildHighlightSpansActionProjectTag() {
        let tokens = [
            TokenSpan(tokenType: .wordString, literal: "this", start: 0, end: 4),
            TokenSpan(tokenType: .blank, literal: " ", start: 4, end: 5),
            TokenSpan(tokenType: .wordString, literal: "is", start: 5, end: 7),
            TokenSpan(tokenType: .blank, literal: " ", start: 7, end: 8),
            TokenSpan(tokenType: .wordString, literal: "add", start: 8, end: 11),
            TokenSpan(tokenType: .blank, literal: " ", start: 11, end: 12),
            TokenSpan(tokenType: .projectPrefix, literal: "proj:", start: 12, end: 17),
            TokenSpan(tokenType: .wordString, literal: "abc", start: 17, end: 20),
            TokenSpan(tokenType: .blank, literal: " ", start: 20, end: 21),
            TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 21, end: 22),
            TokenSpan(tokenType: .wordString, literal: "tag", start: 22, end: 25)
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

        XCTAssertEqual(attributes[.foregroundColor] as? NSColor, ThemeManager.current.overlay0NS)
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
        viewModel.completion.showMenu = true

        mock.parseResult = .failure(SampleError(message: "parse error"))
        viewModel.handleInputChange("a")
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(viewModel.toasts.isEmpty)

        viewModel.clearCompletions()
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(viewModel.toasts.count, 1)
        XCTAssertEqual(viewModel.toasts.first?.message, "parse error")
    }

    func testSubmitCommandPaletteSelectionWithoutTaskShowsToast() {
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        viewModel.commandPalette.isPresented = true
        viewModel.commandPalette.mode = .addGitlab

        viewModel.submitCommandPaletteSelection()

        XCTAssertEqual(viewModel.toasts.first?.message, "Select a task to add a link.")
        XCTAssertFalse(viewModel.commandPalette.isPresented)
    }

    func testDetectCompletionContextDetectsDatePrefixWithValue() {
        let viewModel = LauncherViewModel()
        viewModel.input = "due:tom"
        viewModel.completion.cursorPosition = viewModel.input.count
        viewModel.updateCompletions()

        XCTAssertEqual(viewModel.completion.context, .date)
    }

    func testDetectCompletionContextDetectsProjectPrefix() {
        let viewModel = LauncherViewModel()
        viewModel.input = "proj:work"
        viewModel.completion.cursorPosition = viewModel.input.count
        viewModel.updateCompletions()

        XCTAssertEqual(viewModel.completion.context, .project)
    }

    func testDetectCompletionContextDetectsStatusPrefix() {
        let viewModel = LauncherViewModel()
        viewModel.input = "status:pen"
        viewModel.completion.cursorPosition = viewModel.input.count
        viewModel.updateCompletions()

        XCTAssertEqual(viewModel.completion.context, .status)
    }

    func testDetectCompletionContextDetectsDependsPrefix() {
        let viewModel = LauncherViewModel()
        viewModel.input = "depends:abcd"
        viewModel.completion.cursorPosition = viewModel.input.count
        viewModel.updateCompletions()

        XCTAssertEqual(viewModel.completion.context, .taskRef)
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

    func testRunActionAppliesDefaultFiltersWhenMissing() async {
        let mock = MockApiClient()
        mock.parseResult = .success(ParseResponse(
            action: "list",
            properties: nil,
            filter: .string("default-filter"),
            tokens: []
        ))
        let service = LauncherActionService(apiClient: mock)
        service.setReportConfig(ReportConfig(
            filters: ["status:pending or status:active"],
            columns: ["id"],
            columnNames: ["ID"]
        ))
        let viewModel = LauncherViewModel(apiClient: mock, actionService: service)

        let parsed = ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
        await viewModel.runAction(from: parsed, requestId: 1, resetInput: false, updateStatus: false)

        XCTAssertEqual(mock.lastParseInput, "list status:pending or status:active")
        switch mock.lastRunActionFilter {
        case .string(let value):
            XCTAssertEqual(value, "default-filter")
        default:
            XCTFail("Expected default filter to be passed to runAction")
        }
    }
}

private func clearCollapsedDefaults() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: UserDefaultsKeys.collapsedGroups)
    defaults.removeObject(forKey: UserDefaultsKeys.collapsedNilGroup)
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
