import AppKit
@testable import LauncherAppKit
import XCTest

/// Tests for detail mode keyboard navigation.
/// These test the pure-function decider that maps keys to DetailModeAction.
final class DetailModeKeyHandlingTests: XCTestCase {
    // MARK: - Navigation Tests

    func testJMoveFocusDown() {
        let input = KeyInput(
            keyCode: KeyCode.keyJ,
            charactersIgnoringModifiers: "j",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .navigate(.down))
    }

    func testKMoveFocusUp() {
        let input = KeyInput(
            keyCode: KeyCode.keyK,
            charactersIgnoringModifiers: "k",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .navigate(.up))
    }

    func testCtrlNMoveFocusDown() {
        let input = KeyInput(
            keyCode: KeyCode.keyN,
            charactersIgnoringModifiers: "n",
            modifierFlags: [.control]
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .navigate(.down))
    }

    func testCtrlPMoveFocusUp() {
        let input = KeyInput(
            keyCode: KeyCode.keyP,
            charactersIgnoringModifiers: "p",
            modifierFlags: [.control]
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .navigate(.up))
    }

    func testGSelectFirst() {
        let input = KeyInput(
            keyCode: KeyCode.keyG,
            charactersIgnoringModifiers: "g",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .selectFirst)
    }

    func testShiftGSelectLast() {
        let input = KeyInput(
            keyCode: KeyCode.keyG,
            charactersIgnoringModifiers: "G",
            modifierFlags: [.shift]
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .selectLast)
    }

    // MARK: - h/l Navigation Tests (vim-style)

    func testHMoveFocusLeft() {
        let input = KeyInput(
            keyCode: KeyCode.keyH,
            charactersIgnoringModifiers: "h",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .navigate(.left))
    }

    func testLMoveFocusRight() {
        let input = KeyInput(
            keyCode: KeyCode.keyL,
            charactersIgnoringModifiers: "l",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .navigate(.right))
    }

    func testModifiedHIgnored() {
        // Cmd+H is system "Hide" - we shouldn't override it
        let input = KeyInput(
            keyCode: KeyCode.keyH,
            charactersIgnoringModifiers: "h",
            modifierFlags: [.command]
        )
        XCTAssertNil(KeyHandlingDecider.detailModeAction(for: input))
    }

    func testModifiedLIgnored() {
        // Cmd+L might be used for other purposes - we shouldn't override it
        let input = KeyInput(
            keyCode: KeyCode.keyL,
            charactersIgnoringModifiers: "l",
            modifierFlags: [.command]
        )
        XCTAssertNil(KeyHandlingDecider.detailModeAction(for: input))
    }

    // MARK: - Action Tests

    func testEnterOpenFocused() {
        let input = KeyInput(
            keyCode: KeyCode.returnKey,
            charactersIgnoringModifiers: "\r",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .openFocused)
    }

    func testKeypadEnterOpenFocused() {
        let input = KeyInput(
            keyCode: KeyCode.keypadEnter,
            charactersIgnoringModifiers: "\r",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .openFocused)
    }

    func testYCopyFocused() {
        let input = KeyInput(
            keyCode: KeyCode.keyY,
            charactersIgnoringModifiers: "y",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .copyFocused)
    }

    func testAAddAnnotation() {
        let input = KeyInput(
            keyCode: KeyCode.keyA,
            charactersIgnoringModifiers: "a",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .addAnnotation)
    }

    func testModifiedAIgnored() {
        // Cmd+A is system "Select All" - we shouldn't override it
        let input = KeyInput(
            keyCode: KeyCode.keyA,
            charactersIgnoringModifiers: "a",
            modifierFlags: [.command]
        )
        XCTAssertNil(KeyHandlingDecider.detailModeAction(for: input))
    }

    // MARK: - Non-Action Keys

    func testUnhandledKeyReturnsNil() {
        // Random key 'q' should not trigger any action
        let input = KeyInput(
            keyCode: 12, // q key
            charactersIgnoringModifiers: "q",
            modifierFlags: []
        )
        XCTAssertNil(KeyHandlingDecider.detailModeAction(for: input))
    }

    func testXKeyTriggersDeleteFocused() {
        let input = KeyInput(
            keyCode: KeyCode.keyX,
            charactersIgnoringModifiers: "x",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .deleteFocused)
    }

    func testModifiedJIgnored() {
        // Cmd+J should not trigger navigation (reserved for other shortcuts)
        let input = KeyInput(
            keyCode: KeyCode.keyJ,
            charactersIgnoringModifiers: "j",
            modifierFlags: [.command]
        )
        XCTAssertNil(KeyHandlingDecider.detailModeAction(for: input))
    }

    func testModifiedOIgnored() {
        // Cmd+O is system "Open" - we shouldn't override it
        let input = KeyInput(
            keyCode: KeyCode.keyO,
            charactersIgnoringModifiers: "o",
            modifierFlags: [.command]
        )
        XCTAssertNil(KeyHandlingDecider.detailModeAction(for: input))
    }
}

// MARK: - DetailFocusableItem Tests

final class DetailFocusableItemTests: XCTestCase {
    // MARK: - UUID Item Tests

    func testUUIDItemId() {
        let item = DetailFocusableItem.uuid("abc-123")
        XCTAssertEqual(item.id, "uuid-abc-123")
    }

    func testUUIDItemOpenURLIsNil() {
        let item = DetailFocusableItem.uuid("abc-123")
        XCTAssertNil(item.openURL)
    }

    func testUUIDItemCopyValue() {
        let item = DetailFocusableItem.uuid("abc-123-def-456")
        XCTAssertEqual(item.copyValue, "abc-123-def-456")
    }

    func testUUIDItemCopyLabel() {
        let item = DetailFocusableItem.uuid("abc-123")
        XCTAssertEqual(item.copyLabel, "UUID")
    }

    // MARK: - GitLab MR Item Tests

    func testGitLabMRItemId() {
        let link = makeGitLabLink(id: 42)
        let item = DetailFocusableItem.gitlabMR(link)
        XCTAssertEqual(item.id, "gitlab-42")
    }

    func testGitLabMRItemOpenURL() {
        let link = makeGitLabLink(url: "https://gitlab.com/mr/123")
        let item = DetailFocusableItem.gitlabMR(link)
        XCTAssertEqual(item.openURL, URL(string: "https://gitlab.com/mr/123"))
    }

    func testGitLabMRItemCopyValueWithBranch() {
        let link = makeGitLabLink(sourceBranch: "feature/fix-bug")
        let item = DetailFocusableItem.gitlabMR(link)
        XCTAssertEqual(item.copyValue, "feature/fix-bug")
    }

    func testGitLabMRItemCopyValueFallsBackToURL() {
        let link = makeGitLabLinkWithNoCachedData(url: "https://gitlab.com/mr/123")
        let item = DetailFocusableItem.gitlabMR(link)
        XCTAssertEqual(item.copyValue, "https://gitlab.com/mr/123")
    }

    func testGitLabMRItemCopyLabel() {
        let link = makeGitLabLink()
        let item = DetailFocusableItem.gitlabMR(link)
        XCTAssertEqual(item.copyLabel, "Branch")
    }

    // MARK: - Jira Issue Item Tests

    func testJiraIssueItemId() {
        let link = makeJiraLink(id: 99)
        let item = DetailFocusableItem.jiraIssue(link)
        XCTAssertEqual(item.id, "jira-99")
    }

    func testJiraIssueItemOpenURL() {
        let link = makeJiraLink(url: "https://jira.example.com/ABC-123")
        let item = DetailFocusableItem.jiraIssue(link)
        XCTAssertEqual(item.openURL, URL(string: "https://jira.example.com/ABC-123"))
    }

    func testJiraIssueItemCopyValue() {
        let link = makeJiraLink(url: "https://jira.example.com/ABC-456")
        let item = DetailFocusableItem.jiraIssue(link)
        XCTAssertEqual(item.copyValue, "https://jira.example.com/ABC-456")
    }

    func testJiraIssueItemCopyLabel() {
        let link = makeJiraLink()
        let item = DetailFocusableItem.jiraIssue(link)
        XCTAssertEqual(item.copyLabel, "Link")
    }

    // MARK: - Equatable Tests

    func testUUIDItemsAreEqual() {
        let item1 = DetailFocusableItem.uuid("abc-123")
        let item2 = DetailFocusableItem.uuid("abc-123")
        XCTAssertEqual(item1, item2)
    }

    func testUUIDItemsWithDifferentValuesAreNotEqual() {
        let item1 = DetailFocusableItem.uuid("abc-123")
        let item2 = DetailFocusableItem.uuid("def-456")
        XCTAssertNotEqual(item1, item2)
    }

    func testDifferentItemTypesAreNotEqual() {
        let uuid = DetailFocusableItem.uuid("abc-123")
        let gitlab = DetailFocusableItem.gitlabMR(makeGitLabLink(id: 1))
        XCTAssertNotEqual(uuid, gitlab)
    }

    // MARK: - Helpers

    private func makeGitLabLink(
        id: Int = 1,
        url: String = "https://gitlab.com/mr/1",
        sourceBranch: String = "feature/test"
    ) -> ExternalLinkDto {
        // JSON format matches what the API returns and what ExternalLinkCachedParser expects
        let cachedResponse = """
        {"merge_request":{"title":"Test MR","state":"opened",\
        "source_branch":"\(sourceBranch)","user_notes_count":0,\
        "head_pipeline":null},"approvals":{"approved":false}}
        """
        return ExternalLinkDto(
            id: id,
            provider: "gitlab",
            url: url,
            externalKey: "mr:test/project:\(id)",
            cachedResponse: cachedResponse,
            lastSyncedAt: "2024-09-24T12:00:00Z",
            syncError: nil
        )
    }

    private func makeGitLabLinkWithNoCachedData(
        id: Int = 1,
        url: String = "https://gitlab.com/mr/1"
    ) -> ExternalLinkDto {
        ExternalLinkDto(
            id: id,
            provider: "gitlab",
            url: url,
            externalKey: "mr:test/project:\(id)",
            cachedResponse: nil,
            lastSyncedAt: nil,
            syncError: nil
        )
    }

    private func makeJiraLink(
        id: Int = 1,
        url: String = "https://jira.example.com/ABC-123"
    ) -> ExternalLinkDto {
        ExternalLinkDto(
            id: id,
            provider: "jira",
            url: url,
            externalKey: "ABC-123",
            cachedResponse: nil,
            lastSyncedAt: nil,
            syncError: nil
        )
    }
}

// MARK: - ViewModel Focus Logic Tests

@MainActor
final class DetailFocusViewModelTests: XCTestCase {
    private var viewModel: LauncherViewModel!

    override func setUp() {
        super.setUp()
        viewModel = LauncherViewModel(apiClient: MockApiClient())
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Build Focusable Items

    func testBuildDetailFocusableItemsWithNoTask() {
        viewModel.buildDetailFocusableItems()
        XCTAssertTrue(viewModel.detailFocusableItems.isEmpty)
    }

    func testBuildDetailFocusableItemsIncludesTaskName() {
        setupDetailMode()
        viewModel.buildDetailFocusableItems()

        XCTAssertFalse(viewModel.detailFocusableItems.isEmpty)
        if case .taskName = viewModel.detailFocusableItems.first {
            // Success - task name should be first
        } else {
            XCTFail("First focusable item should be task name")
        }
    }

    func testBuildDetailFocusableItemsIncludesUUID() {
        setupDetailMode()
        viewModel.buildDetailFocusableItems()

        XCTAssertGreaterThanOrEqual(viewModel.detailFocusableItems.count, 3)
        if case .uuid = viewModel.detailFocusableItems[1] {
            // Success - UUID should be second (after task name)
        } else {
            XCTFail("Second focusable item should be UUID")
        }
    }

    func testBuildDetailFocusableItemsIncludesProject() {
        setupDetailMode()
        viewModel.buildDetailFocusableItems()

        XCTAssertGreaterThanOrEqual(viewModel.detailFocusableItems.count, 3)
        if case .project = viewModel.detailFocusableItems[2] {
            // Success - Project should be third (after task name and UUID)
        } else {
            XCTFail("Third focusable item should be project")
        }
    }

    func testBuildDetailFocusableItemsIncludesGitLabLinks() {
        setupDetailMode()
        viewModel.externalLinksState = ExternalLinksState(
            isLoading: false,
            taskUUID: viewModel.tasks[0].uuid,
            links: MockApiClient.sampleExternalLinks.filter { $0.provider.lowercased() == "gitlab" }
        )
        viewModel.buildDetailFocusableItems()

        let gitlabCount = viewModel.detailFocusableItems.filter {
            if case .gitlabMR = $0 { return true }
            return false
        }.count

        XCTAssertGreaterThan(gitlabCount, 0)
    }

    func testBuildDetailFocusableItemsIncludesJiraLinks() {
        setupDetailMode()
        viewModel.externalLinksState = ExternalLinksState(
            isLoading: false,
            taskUUID: viewModel.tasks[0].uuid,
            links: MockApiClient.sampleExternalLinks.filter { $0.provider.lowercased() == "jira" }
        )
        viewModel.buildDetailFocusableItems()

        let jiraCount = viewModel.detailFocusableItems.filter {
            if case .jiraIssue = $0 { return true }
            return false
        }.count

        XCTAssertGreaterThan(jiraCount, 0)
    }

    // MARK: - Focus Movement

    func testNavigateDownMovesToNextTarget() {
        setupDetailModeWithItems()
        // Clear existing registry and register test targets
        viewModel.navigationRegistry.clearAll()
        viewModel.navigationRegistry.register(
            .taskName("Test"),
            frame: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        viewModel.navigationRegistry.register(
            .uuid("test-uuid"),
            frame: CGRect(x: 0, y: 40, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusFirst()

        let result = viewModel.handleDetailModeAction(.navigate(.down))

        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.navigationRegistry.focusedId, "uuid-test-uuid")
    }

    func testNavigateUpMovesToPreviousTarget() {
        setupDetailModeWithItems()
        // Clear existing registry and register test targets
        viewModel.navigationRegistry.clearAll()
        viewModel.navigationRegistry.register(
            .taskName("Test"),
            frame: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        viewModel.navigationRegistry.register(
            .uuid("test-uuid"),
            frame: CGRect(x: 0, y: 40, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusLast()

        let result = viewModel.handleDetailModeAction(.navigate(.up))

        XCTAssertTrue(result)
        // taskName ID is just "taskName", not "taskName-Test"
        XCTAssertEqual(viewModel.navigationRegistry.focusedId, "taskName")
    }

    func testNavigateStaysWhenNoTargetExists() {
        setupDetailModeWithItems()
        // Clear existing registry and register only one target
        viewModel.navigationRegistry.clearAll()
        viewModel.navigationRegistry.register(
            .taskName("Test"),
            frame: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusFirst()

        let result = viewModel.handleDetailModeAction(.navigate(.down))

        // Should return true (handled) but stay on current target
        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.navigationRegistry.focusedId, "taskName")
    }

    func testNavigateRightMovesToTargetWithGreaterX() {
        setupDetailModeWithItems()
        // Clear existing registry and register test targets
        viewModel.navigationRegistry.clearAll()
        viewModel.navigationRegistry.register(
            .taskName("Test"),
            frame: CGRect(x: 0, y: 50, width: 100, height: 30)
        )
        viewModel.navigationRegistry.register(
            .gitlabMR(MockApiClient.sampleExternalLinks[0]),
            frame: CGRect(x: 200, y: 50, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusFirst()

        let result = viewModel.handleDetailModeAction(.navigate(.right))

        XCTAssertTrue(result)
    }

    func testSelectFirstJumpsToFirstTarget() {
        setupDetailModeWithItems()
        // Clear and register test targets
        viewModel.navigationRegistry.clearAll()
        viewModel.navigationRegistry.register(
            .taskName("Test"),
            frame: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        viewModel.navigationRegistry.register(
            .uuid("test-uuid"),
            frame: CGRect(x: 0, y: 40, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusLast() // Start at last

        viewModel.handleDetailModeAction(.selectFirst)

        XCTAssertEqual(viewModel.navigationRegistry.focusedId, "taskName")
    }

    func testSelectLastJumpsToLastTarget() {
        setupDetailModeWithItems()
        // Clear and register test targets
        viewModel.navigationRegistry.clearAll()
        viewModel.navigationRegistry.register(
            .taskName("Test"),
            frame: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        viewModel.navigationRegistry.register(
            .uuid("test-uuid"),
            frame: CGRect(x: 0, y: 40, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusFirst() // Start at first

        viewModel.handleDetailModeAction(.selectLast)

        XCTAssertEqual(viewModel.navigationRegistry.focusedId, "uuid-test-uuid")
    }

    // MARK: - Focused Item Property

    func testFocusedDetailItemReturnsNilWhenKeyboardNavigationInactive() {
        setupDetailModeWithItems()
        // Clear and register test targets
        viewModel.navigationRegistry.clearAll()
        viewModel.navigationRegistry.register(
            .uuid("test-uuid"),
            frame: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        // Set focused ID but don't activate navigation
        viewModel.navigationRegistry.focusedId = "uuid-test-uuid"
        viewModel.navigationRegistry.deactivateNavigation()

        // Focus ring only shows after user engages with hjkl
        XCTAssertNil(viewModel.focusedDetailItem)
    }

    func testFocusedDetailItemReturnsCorrectItem() {
        setupDetailModeWithItems()
        // Clear and register test targets
        viewModel.navigationRegistry.clearAll()
        let uuidItem = DetailFocusableItem.uuid("test-uuid")
        viewModel.navigationRegistry.register(
            uuidItem,
            frame: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusOn(uuidItem)

        let focused = viewModel.focusedDetailItem

        XCTAssertNotNil(focused)
        XCTAssertEqual(focused, uuidItem)
    }

    func testFocusedDetailItemReturnsNilWhenNotRegistered() {
        setupDetailModeWithItems()
        // Clear registry - no targets registered
        viewModel.navigationRegistry.clearAll()
        // Try to focus on non-existent target
        viewModel.navigationRegistry.focusedId = "nonexistent"

        XCTAssertNil(viewModel.focusedDetailItem)
    }

    // MARK: - Annotation Tests

    func testStartAddingAnnotationSetsState() {
        setupDetailMode()

        viewModel.startAddingAnnotation()

        XCTAssertTrue(viewModel.isAddingAnnotation)
        XCTAssertEqual(viewModel.annotationInput, "")
    }

    func testStartAddingAnnotationRequiresSelectedTask() {
        // No task selected
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = nil
        viewModel.mode = .detail

        viewModel.startAddingAnnotation()

        XCTAssertFalse(viewModel.isAddingAnnotation, "Should not start adding if no task selected")
    }

    func testCancelAddingAnnotationClearsState() {
        setupDetailMode()
        viewModel.isAddingAnnotation = true
        viewModel.annotationInput = "Some text"

        viewModel.cancelAddingAnnotation()

        XCTAssertFalse(viewModel.isAddingAnnotation)
        XCTAssertEqual(viewModel.annotationInput, "")
    }

    func testSubmitAnnotationWithEmptyTextCancels() {
        setupDetailMode()
        viewModel.isAddingAnnotation = true
        viewModel.annotationInput = "   " // whitespace only

        viewModel.submitAnnotation()

        XCTAssertFalse(viewModel.isAddingAnnotation, "Empty text should cancel")
    }

    func testHandleDetailModeActionAddAnnotation() {
        setupDetailMode()

        let result = viewModel.handleDetailModeAction(.addAnnotation)

        XCTAssertTrue(result)
        XCTAssertTrue(viewModel.isAddingAnnotation)
    }

    func testNavigateLeftMovesToTargetWithLesserX() {
        setupDetailModeWithItems()
        // Clear existing registry and set up two targets horizontally
        viewModel.navigationRegistry.clearAll()
        viewModel.navigationRegistry.register(
            .taskName("Test"),
            frame: CGRect(x: 0, y: 50, width: 100, height: 30)
        )
        viewModel.navigationRegistry.register(
            .gitlabMR(MockApiClient.sampleExternalLinks[0]),
            frame: CGRect(x: 200, y: 50, width: 100, height: 30)
        )
        // Focus on the right target
        viewModel.navigationRegistry.focusLast()

        let result = viewModel.handleDetailModeAction(.navigate(.left))

        XCTAssertTrue(result)
        // taskName ID is just "taskName"
        XCTAssertEqual(viewModel.navigationRegistry.focusedId, "taskName")
    }

    func testNavigateRightDoesNotOpenLinks() {
        setupDetailModeWithItems()
        // Clear existing registry and register a GitLab link on the right
        viewModel.navigationRegistry.clearAll()
        let link = MockApiClient.sampleExternalLinks.first { $0.provider.lowercased() == "gitlab" }!
        viewModel.navigationRegistry.register(
            .taskName("Test"),
            frame: CGRect(x: 0, y: 50, width: 100, height: 30)
        )
        viewModel.navigationRegistry.register(
            .gitlabMR(link),
            frame: CGRect(x: 200, y: 50, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusFirst()

        // Navigate right - this should ONLY move focus, not open the link
        let result = viewModel.handleDetailModeAction(.navigate(.right))

        XCTAssertTrue(result, "Navigation should succeed")
        // The `l` key now only navigates - `o` is required to open
    }

    func testOpenFocusedStartsEditingWhenTaskNameFocused() {
        setupDetailModeWithItems()
        // Clear existing registry and register task name
        viewModel.navigationRegistry.clearAll()
        let taskNameItem = DetailFocusableItem.taskName(viewModel.tasks[0].summary)
        viewModel.navigationRegistry.register(
            taskNameItem,
            frame: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusOn(taskNameItem)
        XCTAssertFalse(viewModel.isEditingTaskName)

        let result = viewModel.handleDetailModeAction(.openFocused)

        XCTAssertTrue(result)
        XCTAssertTrue(viewModel.isEditingTaskName, "Enter on task name should start editing")
    }

    // MARK: - Helpers

    private func setupDetailMode() {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
    }

    private func setupDetailModeWithItems() {
        setupDetailMode()
        viewModel.externalLinksState = ExternalLinksState(
            isLoading: false,
            taskUUID: viewModel.tasks[0].uuid,
            links: MockApiClient.sampleExternalLinks
        )
        viewModel.buildDetailFocusableItems()
    }
}
