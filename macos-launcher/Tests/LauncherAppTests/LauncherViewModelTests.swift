import AppKit
@testable import LauncherApp
import XCTest

@MainActor
final class LauncherViewModelTests: XCTestCase {
    func testMoveSelectionClampsAtEnd() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [
            makeTask(id: "a"),
            makeTask(id: "b"),
            makeTask(id: "c"),
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
            makeTask(id: "b"),
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
            makeTask(id: "b"),
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

    func testSetGroupingStrategyClearsCollapsedState() {
        defer { clearGroupingDefaults() }
        let viewModel = LauncherViewModel()

        viewModel.collapsedGroups = ["work", "personal", nil]
        viewModel.setGroupingStrategy(.dueDate)

        XCTAssertTrue(viewModel.collapsedGroups.isEmpty)
    }

    func testSetGroupingStrategyPersistsSelection() {
        defer { clearGroupingDefaults() }
        let viewModel = LauncherViewModel()

        viewModel.setGroupingStrategy(.tag)

        let saved = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedGroupBy)
        XCTAssertEqual(saved, "tag")
    }

    func testLoadGroupingStrategyRestoresSelection() {
        defer { clearGroupingDefaults() }
        UserDefaults.standard.set("dueDate", forKey: UserDefaultsKeys.selectedGroupBy)

        let viewModel = LauncherViewModel()

        XCTAssertEqual(viewModel.currentGroupByOption, .dueDate)
        XCTAssertTrue(viewModel.groupingStrategy is DueDateGroupingStrategy)
    }

    func testLoadGroupingStrategyDefaultsToProject() {
        defer { clearGroupingDefaults() }
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedGroupBy)

        let viewModel = LauncherViewModel()

        XCTAssertEqual(viewModel.currentGroupByOption, .project)
        XCTAssertTrue(viewModel.groupingStrategy is ProjectGroupingStrategy)
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
            TokenSpan(tokenType: .wordString, literal: "tag", start: 22, end: 25),
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
            ApiEvent(kind: "info", message: "Undo recorded."),
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
            makeTask(id: "e", urgency: 9),
        ]

        let sorted = viewModel.sortTasksByUrgency(tasks)
        let ids = sorted.map(\.uuid)

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
            staticFilters: ["status:pending or status:active"],
            columns: ["id"],
            columnNames: ["ID"]
        ))
        let viewModel = LauncherViewModel(apiClient: mock, actionService: service)

        let parsed = ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
        await viewModel.runAction(from: parsed, requestId: 1, resetInput: false, updateStatus: false)

        XCTAssertEqual(mock.lastParseInput, "list status:pending or status:active")
        switch mock.lastRunActionFilter {
        case let .string(value):
            XCTAssertEqual(value, "default-filter")
        default:
            XCTFail("Expected default filter to be passed to runAction")
        }
    }

    // MARK: - Task Expansion Tests

    func testToggleTaskExpansion() {
        let viewModel = LauncherViewModel()
        let taskUUID = "test-task-uuid"

        // Initially not expanded
        XCTAssertFalse(viewModel.isTaskExpanded(taskUUID))
        XCTAssertTrue(viewModel.expandedTasks.isEmpty)

        // Toggle on
        viewModel.toggleTaskExpansion(taskUUID)
        XCTAssertTrue(viewModel.isTaskExpanded(taskUUID))
        XCTAssertTrue(viewModel.expandedTasks.contains(taskUUID))

        // Toggle off
        viewModel.toggleTaskExpansion(taskUUID)
        XCTAssertFalse(viewModel.isTaskExpanded(taskUUID))
        XCTAssertFalse(viewModel.expandedTasks.contains(taskUUID))
    }

    func testToggleSelectedTaskExpansion() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [makeTask(id: "a"), makeTask(id: "b")]
        // Grouped rows: [header("No Project"), task(a,0), task(b,1)]

        // Select task row (index 1 is the first task)
        viewModel.selectedRowIndex = 1

        // Toggle expansion
        let result = viewModel.toggleSelectedOrHoveredTaskExpansion()
        XCTAssertTrue(result)
        XCTAssertTrue(viewModel.isTaskExpanded("a"))
    }

    func testToggleExpansionOnHeaderReturnsFalse() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [makeTask(id: "a")]
        // Grouped rows: [header("No Project"), task(a,0)]

        // Select header row (index 0)
        viewModel.selectedRowIndex = 0

        // Toggle expansion should fail on header
        let result = viewModel.toggleSelectedOrHoveredTaskExpansion()
        XCTAssertFalse(result)
    }

    func testCanToggleExpansionOnTask() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [makeTask(id: "a")]
        // Grouped rows: [header("No Project"), task(a,0)]

        // Select task row
        viewModel.selectedRowIndex = 1
        XCTAssertTrue(viewModel.canToggleSelectedOrHoveredTaskExpansion())

        // Select header row
        viewModel.selectedRowIndex = 0
        XCTAssertFalse(viewModel.canToggleSelectedOrHoveredTaskExpansion())

        // No selection
        viewModel.selectedRowIndex = nil
        XCTAssertFalse(viewModel.canToggleSelectedOrHoveredTaskExpansion())
    }

    // MARK: - TaskExpandedContent Tests

    func testTaskExpandedContentIsEmpty() {
        let emptyContent = TaskExpandedContent(isLoading: false, links: [], annotations: [])
        XCTAssertTrue(emptyContent.isEmpty)

        let withLinks = TaskExpandedContent(
            isLoading: false,
            links: [ExternalLinkDto(
                id: 1,
                provider: "gitlab",
                url: "https://example.com",
                externalKey: "key",
                cachedResponse: nil,
                lastSyncedAt: nil,
                syncError: nil
            )],
            annotations: []
        )
        XCTAssertFalse(withLinks.isEmpty)

        let withAnnotations = TaskExpandedContent(
            isLoading: false,
            links: [],
            annotations: [TaskAnnotationDto(value: "note", time: "2025-01-01T00:00:00Z")]
        )
        XCTAssertFalse(withAnnotations.isEmpty)
    }

    func testTaskExpandedContentShouldShowLoadingFalseWhenNotLoading() {
        let content = TaskExpandedContent(isLoading: false, loadingStartedAt: Date())
        XCTAssertFalse(content.shouldShowLoading)
    }

    func testTaskExpandedContentShouldShowLoadingFalseWithoutTimestamp() {
        let content = TaskExpandedContent(isLoading: true, loadingStartedAt: nil)
        XCTAssertFalse(content.shouldShowLoading)
    }

    func testTaskExpandedContentShouldShowLoadingFalseBeforeOneSecond() {
        let content = TaskExpandedContent(isLoading: true, loadingStartedAt: Date())
        XCTAssertFalse(content.shouldShowLoading)
    }

    func testTaskExpandedContentShouldShowLoadingTrueAfterOneSecond() {
        let pastDate = Date().addingTimeInterval(-1.5) // 1.5 seconds ago
        let content = TaskExpandedContent(isLoading: true, loadingStartedAt: pastDate)
        XCTAssertTrue(content.shouldShowLoading)
    }

    // MARK: - HandleEscape SaveReportSheet Tests

    func testHandleEscapeClosesSaveReportSheet() {
        let viewModel = LauncherViewModel()
        viewModel.showingSaveReportSheet = true

        let result = viewModel.handleEscape()

        XCTAssertTrue(result, "handleEscape should return true when closing SaveReportSheet")
        XCTAssertFalse(viewModel.showingSaveReportSheet, "SaveReportSheet should be closed after handleEscape")
    }

    func testHandleEscapeReturnsEarlyWhenSaveReportSheetOpen() {
        let viewModel = LauncherViewModel()
        viewModel.showingSaveReportSheet = true
        // Set up a state that would normally be handled by escape
        viewModel.completion.showMenu = true

        let result = viewModel.handleEscape()

        XCTAssertTrue(result, "handleEscape should return true")
        XCTAssertFalse(viewModel.showingSaveReportSheet, "SaveReportSheet should be closed")
        // Verify other states were NOT processed (early return)
        XCTAssertTrue(viewModel.completion.showMenu, "Completion menu should still be showing (early return)")
    }

    func testHandleEscapeDoesNotCloseSaveReportSheetWhenNotShowing() {
        let viewModel = LauncherViewModel()
        viewModel.showingSaveReportSheet = false
        viewModel.tasks = [makeTask(id: "a")]
        // Put in insert mode so escape has something to do
        viewModel.exitInsertMode()
        viewModel.enterInsertMode()

        let result = viewModel.handleEscape()

        // Should proceed to other escape handlers
        XCTAssertTrue(result, "handleEscape should return true from other handler")
        XCTAssertFalse(viewModel.showingSaveReportSheet, "SaveReportSheet should remain closed")
    }

    // MARK: - HandleEscape Annotation Input Tests

    func testHandleEscapeCancelsAnnotationInput() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [makeTask(id: "a")]
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
        viewModel.isAddingAnnotation = true
        viewModel.annotationInput = "Some annotation text"

        let result = viewModel.handleEscape()

        XCTAssertTrue(result, "handleEscape should return true when canceling annotation")
        XCTAssertFalse(viewModel.isAddingAnnotation, "isAddingAnnotation should be false after escape")
        XCTAssertEqual(viewModel.annotationInput, "", "annotationInput should be cleared")
    }

    func testHandleEscapeAnnotationTakesPriorityOverDetailClose() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [makeTask(id: "a")]
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
        viewModel.isAddingAnnotation = true

        _ = viewModel.handleEscape()

        // Should cancel annotation but NOT close detail view
        XCTAssertFalse(viewModel.isAddingAnnotation)
        XCTAssertEqual(viewModel.mode, .detail, "Should remain in detail mode")
    }

    // MARK: - Annotation Filter Format Tests

    func testSubmitAnnotationSendsCorrectFilterFormat() async {
        // Arrange: Set up a ViewModel with MockApiClient to capture the filter
        let mock = MockApiClient()
        let viewModel = LauncherViewModel(apiClient: mock)

        // Set up task and select it
        viewModel.tasks = [makeTask(id: "test-task-uuid")]
        viewModel.selectedIndex = 0
        viewModel.mode = .detail

        // Set up annotation input
        viewModel.isAddingAnnotation = true
        viewModel.annotationInput = "Test annotation text"

        // Act: Submit the annotation
        viewModel.submitAnnotation()

        // Wait for async task to complete
        try? await Task.sleep(for: .milliseconds(50))

        // Assert: Verify the filter format includes "type" discriminator
        // The Rust backend uses typetag::serde which requires {"type": "UuidFilter", "uuid": "..."}
        guard let filter = mock.lastRunActionFilter,
              case let .object(dict) = filter else {
            XCTFail("Expected filter to be an object, got: \(String(describing: mock.lastRunActionFilter))")
            return
        }

        // Verify "type" field is present (required by typetag::serde)
        guard case let .string(typeValue) = dict["type"] else {
            XCTFail("Filter must contain 'type' field for typetag::serde deserialization. Got: \(dict)")
            return
        }
        XCTAssertEqual(typeValue, "UuidFilter", "Type discriminator should be 'UuidFilter'")

        // Verify "uuid" field is present
        guard case let .string(uuidValue) = dict["uuid"] else {
            XCTFail("Filter must contain 'uuid' field. Got: \(dict)")
            return
        }
        XCTAssertEqual(uuidValue, "test-task-uuid")
    }
}

private func clearCollapsedDefaults() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: UserDefaultsKeys.collapsedGroups)
    defaults.removeObject(forKey: UserDefaultsKeys.collapsedNilGroup)
}

private func clearGroupingDefaults() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: UserDefaultsKeys.selectedGroupBy)
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
    TestHelpers.makeTask(id: id, urgency: urgency)
}
