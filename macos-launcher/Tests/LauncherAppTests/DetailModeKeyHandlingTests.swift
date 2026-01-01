import AppKit
@testable import LauncherApp
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
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .moveFocus(1))
    }

    func testKMoveFocusUp() {
        let input = KeyInput(
            keyCode: KeyCode.keyK,
            charactersIgnoringModifiers: "k",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .moveFocus(-1))
    }

    func testCtrlNMoveFocusDown() {
        let input = KeyInput(
            keyCode: KeyCode.keyN,
            charactersIgnoringModifiers: "n",
            modifierFlags: [.control]
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .moveFocus(1))
    }

    func testCtrlPMoveFocusUp() {
        let input = KeyInput(
            keyCode: KeyCode.keyP,
            charactersIgnoringModifiers: "p",
            modifierFlags: [.control]
        )
        XCTAssertEqual(KeyHandlingDecider.detailModeAction(for: input), .moveFocus(-1))
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

    // MARK: - Action Tests

    func testOOpenFocused() {
        let input = KeyInput(
            keyCode: KeyCode.keyO,
            charactersIgnoringModifiers: "o",
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

    // MARK: - Non-Action Keys

    func testUnhandledKeyReturnsNil() {
        // Random key 'x' should not trigger any action
        let input = KeyInput(
            keyCode: 7, // x key
            charactersIgnoringModifiers: "x",
            modifierFlags: []
        )
        XCTAssertNil(KeyHandlingDecider.detailModeAction(for: input))
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

    func testBuildDetailFocusableItemsIncludesUUID() {
        setupDetailMode()
        viewModel.buildDetailFocusableItems()

        XCTAssertFalse(viewModel.detailFocusableItems.isEmpty)
        if case .uuid = viewModel.detailFocusableItems.first {
            // Success
        } else {
            XCTFail("First focusable item should be UUID")
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

    func testMoveFocusDownIncrementsIndex() {
        setupDetailModeWithItems()
        viewModel.detailFocusedIndex = 0

        viewModel.handleDetailModeAction(.moveFocus(1))

        XCTAssertEqual(viewModel.detailFocusedIndex, 1)
    }

    func testMoveFocusUpDecrementsIndex() {
        setupDetailModeWithItems()
        viewModel.detailFocusedIndex = 2

        viewModel.handleDetailModeAction(.moveFocus(-1))

        XCTAssertEqual(viewModel.detailFocusedIndex, 1)
    }

    func testMoveFocusStopsAtBounds() {
        setupDetailModeWithItems()
        viewModel.detailFocusedIndex = 0

        viewModel.handleDetailModeAction(.moveFocus(-1))

        XCTAssertEqual(viewModel.detailFocusedIndex, 0, "Should not go below 0")
    }

    func testMoveFocusStopsAtUpperBound() {
        setupDetailModeWithItems()
        let lastIndex = viewModel.detailFocusableItems.count - 1
        viewModel.detailFocusedIndex = lastIndex

        viewModel.handleDetailModeAction(.moveFocus(1))

        XCTAssertEqual(viewModel.detailFocusedIndex, lastIndex, "Should not exceed item count")
    }

    func testSelectFirstJumpsToIndex0() {
        setupDetailModeWithItems()
        viewModel.detailFocusedIndex = 3

        viewModel.handleDetailModeAction(.selectFirst)

        XCTAssertEqual(viewModel.detailFocusedIndex, 0)
    }

    func testSelectLastJumpsToLastIndex() {
        setupDetailModeWithItems()
        viewModel.detailFocusedIndex = 0
        let lastIndex = viewModel.detailFocusableItems.count - 1

        viewModel.handleDetailModeAction(.selectLast)

        XCTAssertEqual(viewModel.detailFocusedIndex, lastIndex)
    }

    // MARK: - Focused Item Property

    func testFocusedDetailItemReturnsCorrectItem() {
        setupDetailModeWithItems()
        viewModel.detailFocusedIndex = 1

        let focused = viewModel.focusedDetailItem

        XCTAssertNotNil(focused)
        XCTAssertEqual(focused, viewModel.detailFocusableItems[1])
    }

    func testFocusedDetailItemReturnsNilWhenOutOfBounds() {
        setupDetailModeWithItems()
        viewModel.detailFocusedIndex = 999

        XCTAssertNil(viewModel.focusedDetailItem)
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
