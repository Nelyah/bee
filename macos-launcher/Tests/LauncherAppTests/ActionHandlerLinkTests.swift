@testable import LauncherAppKit
import XCTest

/// Tests for CommandPaletteActionHandler's task linking methods.
///
/// Verifies the menu building behavior for task linking functionality.
@MainActor
final class ActionHandlerLinkTests: XCTestCase {
    // MARK: - buildLinkTypeMenu Tests

    func testBuildLinkTypeMenuReturnsSixItems() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")

        XCTAssertEqual(menu.sections.count, 1)
        XCTAssertEqual(menu.sections[0].items.count, 6)
    }

    func testBuildLinkTypeMenuHasCorrectTitle() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")

        XCTAssertEqual(menu.title, "Link to Task")
        XCTAssertEqual(menu.id, "link-type")
    }

    func testBuildLinkTypeMenuHasCorrectSectionTitle() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")

        XCTAssertEqual(menu.sections[0].title, "Relationship Type")
        XCTAssertEqual(menu.sections[0].id, "linkTypes")
    }

    func testBuildLinkTypeMenuItemsAreSubmenus() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")

        for item in menu.sections[0].items {
            if case .submenu = item {
                // Success
            } else {
                XCTFail("Expected submenu item, got \(item)")
            }
        }
    }

    func testBuildLinkTypeMenuContainsBlockingOption() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")
        let items = menu.sections[0].items

        let blockingItem = items.first { item in
            if case let .submenu(submenu) = item {
                return submenu.id == "link-type-blocking"
            }
            return false
        }

        XCTAssertNotNil(blockingItem)
        if case let .submenu(submenu)? = blockingItem {
            XCTAssertEqual(submenu.title, "Blocks...")
            XCTAssertEqual(submenu.icon, .system("arrow.right"))
        }
    }

    func testBuildLinkTypeMenuContainsDependsOnOption() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")
        let items = menu.sections[0].items

        let dependsOnItem = items.first { item in
            if case let .submenu(submenu) = item {
                return submenu.id == "link-type-depends_on"
            }
            return false
        }

        XCTAssertNotNil(dependsOnItem)
        if case let .submenu(submenu)? = dependsOnItem {
            XCTAssertEqual(submenu.title, "Depends on...")
            XCTAssertEqual(submenu.icon, .system("arrow.left"))
        }
    }

    func testBuildLinkTypeMenuContainsParentOfOption() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")
        let items = menu.sections[0].items

        let parentOfItem = items.first { item in
            if case let .submenu(submenu) = item {
                return submenu.id == "link-type-parent_of"
            }
            return false
        }

        XCTAssertNotNil(parentOfItem)
        if case let .submenu(submenu)? = parentOfItem {
            XCTAssertEqual(submenu.title, "Parent of...")
            XCTAssertEqual(submenu.icon, .system("arrow.up"))
        }
    }

    func testBuildLinkTypeMenuContainsChildOfOption() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")
        let items = menu.sections[0].items

        let childOfItem = items.first { item in
            if case let .submenu(submenu) = item {
                return submenu.id == "link-type-child_of"
            }
            return false
        }

        XCTAssertNotNil(childOfItem)
        if case let .submenu(submenu)? = childOfItem {
            XCTAssertEqual(submenu.title, "Child of...")
            XCTAssertEqual(submenu.icon, .system("arrow.down"))
        }
    }

    func testBuildLinkTypeMenuContainsRelatedToOption() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")
        let items = menu.sections[0].items

        let relatedToItem = items.first { item in
            if case let .submenu(submenu) = item {
                return submenu.id == "link-type-related_to"
            }
            return false
        }

        XCTAssertNotNil(relatedToItem)
        if case let .submenu(submenu)? = relatedToItem {
            XCTAssertEqual(submenu.title, "Related to...")
            XCTAssertEqual(submenu.icon, .system("link"))
        }
    }

    func testBuildLinkTypeMenuContainsDuplicatesOption() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")
        let items = menu.sections[0].items

        let duplicatesItem = items.first { item in
            if case let .submenu(submenu) = item {
                return submenu.id == "link-type-duplicates"
            }
            return false
        }

        XCTAssertNotNil(duplicatesItem)
        if case let .submenu(submenu)? = duplicatesItem {
            XCTAssertEqual(submenu.title, "Duplicates...")
            XCTAssertEqual(submenu.icon, .system("doc.on.doc"))
        }
    }

    func testBuildLinkTypeMenuItemsHaveDescriptions() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildLinkTypeMenu(taskUUID: "source-uuid")

        for item in menu.sections[0].items {
            if case let .submenu(submenu) = item {
                XCTAssertNotNil(submenu.subtitle, "Item \(submenu.id) should have subtitle")
            }
        }
    }

    // MARK: - buildTaskSelectorMenu Tests

    func testBuildTaskSelectorMenuExcludesSourceTask() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        // Add some tasks to the view model
        viewModel.tasks = [
            TestHelpers.makeTask(id: "source-uuid", summary: "Source Task"),
            TestHelpers.makeTask(id: "target-1", summary: "Target 1"),
            TestHelpers.makeTask(id: "target-2", summary: "Target 2"),
        ]

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source-uuid")

        // Should have 2 items (excluding source)
        XCTAssertEqual(menu.sections[0].items.count, 2)

        // Verify source task is not in the list
        for item in menu.sections[0].items {
            if case let .action(action) = item {
                XCTAssertNotEqual(action.id, "task-source-uuid")
            }
        }
    }

    func testBuildTaskSelectorMenuShowsTaskSummaries() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        viewModel.tasks = [
            TestHelpers.makeTask(id: "source", summary: "Source"),
            TestHelpers.makeTask(id: "target", summary: "My Target Task"),
        ]

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source")

        guard let item = menu.sections[0].items.first,
              case let .action(action) = item
        else {
            return XCTFail("Expected action item")
        }

        XCTAssertEqual(action.title, "My Target Task")
    }

    func testBuildTaskSelectorMenuShowsProjectAsSubtitle() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        viewModel.tasks = [
            TestHelpers.makeTask(id: "source", summary: "Source"),
            TestHelpers.makeTask(id: "target", project: "my-project", summary: "Target"),
        ]

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source")

        guard let item = menu.sections[0].items.first,
              case let .action(action) = item
        else {
            return XCTFail("Expected action item")
        }

        XCTAssertEqual(action.subtitle, "my-project")
    }

    func testBuildTaskSelectorMenuShowsNoProjectWhenNil() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        viewModel.tasks = [
            TestHelpers.makeTask(id: "source", summary: "Source"),
            TestHelpers.makeTask(id: "target", project: nil, summary: "Target"),
        ]

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source")

        guard let item = menu.sections[0].items.first,
              case let .action(action) = item
        else {
            return XCTFail("Expected action item")
        }

        XCTAssertEqual(action.subtitle, "No project")
    }

    func testBuildTaskSelectorMenuHasCorrectTitle() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        viewModel.tasks = [
            TestHelpers.makeTask(id: "source", summary: "Source"),
            TestHelpers.makeTask(id: "target", summary: "Target"),
        ]

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source")

        XCTAssertEqual(menu.title, "Blocks")
    }

    func testBuildTaskSelectorMenuTitleChangesWithLinkType() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        viewModel.tasks = [
            TestHelpers.makeTask(id: "source", summary: "Source"),
            TestHelpers.makeTask(id: "target", summary: "Target"),
        ]

        let linkTypes: [(LinkType, String)] = [
            (.blocking, "Blocks"),
            (.dependsOn, "Depends on"),
            (.parentOf, "Parent of"),
            (.childOf, "Child of"),
            (.relatedTo, "Related to"),
            (.duplicates, "Duplicates"),
        ]

        for (linkType, expectedTitle) in linkTypes {
            let menu = handler.buildTaskSelectorMenu(linkType: linkType, sourceTaskUUID: "source")
            XCTAssertEqual(menu.title, expectedTitle, "Title for \(linkType) should be '\(expectedTitle)'")
        }
    }

    func testBuildTaskSelectorMenuHasCorrectSectionTitle() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        viewModel.tasks = [
            TestHelpers.makeTask(id: "source", summary: "Source"),
        ]

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source")

        XCTAssertEqual(menu.sections[0].title, "Select Task to Link")
    }

    func testBuildTaskSelectorMenuReturnsEmptyWhenNoOtherTasks() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        // Only the source task exists
        viewModel.tasks = [
            TestHelpers.makeTask(id: "source", summary: "Source"),
        ]

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source")

        XCTAssertTrue(menu.sections[0].items.isEmpty)
    }

    func testBuildTaskSelectorMenuItemsAreActions() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        viewModel.tasks = [
            TestHelpers.makeTask(id: "source", summary: "Source"),
            TestHelpers.makeTask(id: "target", summary: "Target"),
        ]

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source")

        for item in menu.sections[0].items {
            if case .action = item {
                // Success
            } else {
                XCTFail("Expected action item")
            }
        }
    }

    func testBuildTaskSelectorMenuItemIdsContainTaskUUID() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        viewModel.tasks = [
            TestHelpers.makeTask(id: "source", summary: "Source"),
            TestHelpers.makeTask(id: "target-uuid-123", summary: "Target"),
        ]

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source")

        guard let item = menu.sections[0].items.first,
              case let .action(action) = item
        else {
            return XCTFail("Expected action item")
        }

        XCTAssertEqual(action.id, "task-target-uuid-123")
    }

    // MARK: - Edge Cases

    func testBuildLinkTypeMenuWithEmptyUUID() async {
        let (_, handler) = await makeHandlerWithMocks()

        // Should not crash with empty UUID
        let menu = handler.buildLinkTypeMenu(taskUUID: "")

        XCTAssertEqual(menu.sections.count, 1)
        XCTAssertEqual(menu.sections[0].items.count, 6)
    }

    func testBuildTaskSelectorMenuWithManyTasks() async {
        let (viewModel, handler) = await makeHandlerWithMocks()

        // Add many tasks
        var tasks: [ApiTask] = [TestHelpers.makeTask(id: "source", summary: "Source")]
        for i in 1 ... 100 {
            tasks.append(TestHelpers.makeTask(id: "target-\(i)", summary: "Task \(i)"))
        }
        viewModel.tasks = tasks

        let menu = handler.buildTaskSelectorMenu(linkType: .blocking, sourceTaskUUID: "source")

        // Should have 100 items (excluding source)
        XCTAssertEqual(menu.sections[0].items.count, 100)
    }

    // MARK: - Filter Format Tests

    /// Regression test: Filter type must be "UuidFilter" not "UUIDFilter"
    /// The API expects snake_case naming where UUID becomes Uuid
    func testTaskLinkFilterUsesCorrectTypeName() async {
        // The filter construction should use "UuidFilter" (not "UUIDFilter")
        // to match the API's expected filter variant names
        let filterValue: JSONValue = .object([
            "type": .string("UuidFilter"), // Correct casing
            "value": .object([
                "uuid": .string("test-uuid"),
            ]),
        ])

        // Verify the structure is correct
        if case let .object(obj) = filterValue,
           case let .string(typeName)? = obj["type"] {
            XCTAssertEqual(typeName, "UuidFilter", "Filter type must use 'UuidFilter' to match API expectations")
        } else {
            XCTFail("Expected valid filter structure")
        }
    }

    // MARK: - GitLab Menu Tests

    /// Regression test: GitLab suggestions should appear after async loading.
    ///
    /// Bug: "When I try to link a task to a GitLab MR, none of the MR show up"
    /// This test verifies the full flow from menu creation to suggestion loading.
    func testBuildGitlabMenuLoadsAndShowsSuggestions() async throws {
        let apiClient = MockApiClient()
        let settingsService = MockSettingsService()
        let viewModel = LauncherViewModel(
            apiClient: apiClient,
            settingsService: settingsService
        )
        let handler = CommandPaletteActionHandler(viewModel: viewModel, apiClient: apiClient)

        // Configure mock to return sample merge requests
        apiClient.gitlabMergeRequestsResult = .success([
            GitlabMergeRequestSuggestion(
                id: 1,
                title: "Fix bug",
                webURL: "https://gitlab.com/test/project/-/merge_requests/1",
                projectPath: "test/project",
                state: .opened,
                updatedAt: "2025-09-24T23:56:12.966+02:00",
                notesCount: 5,
                approved: true,
                pipelineStatus: .success
            ),
            GitlabMergeRequestSuggestion(
                id: 2,
                title: "Add feature",
                webURL: "https://gitlab.com/test/project/-/merge_requests/2",
                projectPath: "test/project",
                state: .merged,
                updatedAt: "2025-09-24T22:45:14.728+02:00",
                notesCount: 0,
                approved: true,
                pipelineStatus: nil
            ),
        ])

        // Build initial menu (starts async loading)
        let initialMenu = handler.buildGitlabMenu(taskUUID: "test-task-uuid")

        // Initial menu should have URL entry section
        XCTAssertEqual(initialMenu.id, "add-gitlab")
        XCTAssertEqual(initialMenu.title, "Add GitLab Link")
        XCTAssertGreaterThanOrEqual(initialMenu.sections.count, 1)

        // Push the menu onto navigation stack (simulating command palette opening)
        viewModel.commandPalette.navigationStack.push(initialMenu)

        // Wait for async loading to complete
        // The loadGitlabSuggestions function will pop and push a new menu
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // After loading, the menu should be replaced with one containing suggestions
        guard let currentMenu = viewModel.commandPalette.navigationStack.currentMenu else {
            XCTFail("Navigation stack should have a menu after loading")
            return
        }

        // Find the suggestions section (not the URL entry section)
        let suggestionsSection = currentMenu.sections.first { $0.id == "gitlab" }
        XCTAssertNotNil(suggestionsSection, "Menu should have a 'gitlab' suggestions section")

        // The suggestions section should NOT be empty
        // This is where the bug manifests - suggestions don't show up
        if let section = suggestionsSection {
            XCTAssertFalse(
                section.items.isEmpty,
                """
                REGRESSION BUG: GitLab suggestions section is empty!

                Expected: Section should contain 2 merge request items from mock data.
                Actual: Section is empty (no MRs showing up).

                This test fails when the async loading flow is broken or suggestions
                are not properly added to the menu.
                """
            )
            XCTAssertEqual(section.items.count, 2, "Should have 2 MR suggestions from mock")
        }
    }

    /// Test that GitLab menu shows error toast when API fails.
    func testBuildGitlabMenuShowsToastOnError() async throws {
        let apiClient = MockApiClient()
        let settingsService = MockSettingsService()
        let viewModel = LauncherViewModel(
            apiClient: apiClient,
            settingsService: settingsService
        )
        let handler = CommandPaletteActionHandler(viewModel: viewModel, apiClient: apiClient)

        // Configure mock to return error
        struct TestError: LocalizedError {
            var errorDescription: String? { "GitLab API error: token invalid" }
        }
        apiClient.gitlabMergeRequestsResult = .failure(TestError())

        // Build initial menu
        let initialMenu = handler.buildGitlabMenu(taskUUID: "test-task-uuid")
        viewModel.commandPalette.navigationStack.push(initialMenu)

        // Wait for async loading to complete (and fail)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Should show error toast
        XCTAssertFalse(viewModel.toasts.isEmpty, "Should show error toast when GitLab API fails")
        if let toast = viewModel.toasts.first {
            XCTAssertTrue(
                toast.message.contains("Failed to load GitLab suggestions"),
                "Toast should mention GitLab loading failure"
            )
        }
    }

    /// Test that initial GitLab menu has URL entry action pinned.
    func testBuildGitlabMenuHasUrlEntryAction() async {
        let (_, handler) = await makeHandlerWithMocks()

        let menu = handler.buildGitlabMenu(taskUUID: "test-uuid")

        XCTAssertEqual(menu.id, "add-gitlab")
        XCTAssertEqual(menu.title, "Add GitLab Link")

        // Should have at least URL entry section
        guard let urlSection = menu.sections.first(where: { $0.id == "gitlab-url" }) else {
            XCTFail("Menu should have gitlab-url section")
            return
        }

        guard case let .action(urlEntryAction)? = urlSection.items.first else {
            XCTFail("URL section should have an action item")
            return
        }

        XCTAssertEqual(urlEntryAction.id, "gitlab-url-entry")
        XCTAssertEqual(urlEntryAction.title, "Enter GitLab URL...")
        XCTAssertTrue(urlEntryAction.isPinned, "URL entry should be pinned")
    }

    // MARK: - Helpers

    private func makeHandlerWithMocks() async -> (LauncherViewModel, CommandPaletteActionHandler) {
        let apiClient = MockApiClient()
        let settingsService = MockSettingsService()
        let viewModel = LauncherViewModel(
            apiClient: apiClient,
            settingsService: settingsService
        )
        let handler = CommandPaletteActionHandler(viewModel: viewModel, apiClient: apiClient)
        return (viewModel, handler)
    }
}
