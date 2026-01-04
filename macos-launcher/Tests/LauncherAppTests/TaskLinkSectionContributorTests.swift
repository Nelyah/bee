@testable import LauncherApp
import XCTest

/// Tests for TaskLinkSectionContributor.
///
/// Verifies the contributor's behavior for showing the "Link to Task" option
/// in the command palette when a task is selected.
@MainActor
final class TaskLinkSectionContributorTests: XCTestCase {
    // MARK: - Section Building Tests

    func testReturnsEmptyWhenNoTaskSelected() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertTrue(sections.isEmpty, "Should return empty sections when no task is selected")
    }

    func testReturnsEmptyWhenSelectedTaskUUIDIsNil() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        // hasSelectedTask is true but UUID is nil (edge case)
        let context = CommandPaletteContext(hasSelectedTask: true, selectedTaskUUID: nil)
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertTrue(sections.isEmpty)
    }

    func testReturnsSectionWhenTaskSelected() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid-123"
        )
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].id, "taskLink")
    }

    func testSectionHasNoTitle() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid"
        )
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertNil(sections[0].title)
    }

    func testSectionContainsOneItem() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid"
        )
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections[0].items.count, 1)
    }

    // MARK: - Item Tests

    func testItemIsSubmenu() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid"
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let item = sections.first?.items.first else {
            return XCTFail("Expected item in section")
        }

        if case .submenu = item {
            // Success
        } else {
            XCTFail("Expected submenu item, got \(item)")
        }
    }

    func testItemHasCorrectId() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid"
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let item = sections.first?.items.first,
              case let .submenu(submenuItem) = item
        else {
            return XCTFail("Expected submenu item")
        }

        XCTAssertEqual(submenuItem.id, "link-to-task")
    }

    func testItemHasCorrectTitle() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid"
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let item = sections.first?.items.first,
              case let .submenu(submenuItem) = item
        else {
            return XCTFail("Expected submenu item")
        }

        XCTAssertEqual(submenuItem.title, "Link to Task")
    }

    func testItemHasNoSubtitle() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid"
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let item = sections.first?.items.first,
              case let .submenu(submenuItem) = item
        else {
            return XCTFail("Expected submenu item")
        }

        XCTAssertNil(submenuItem.subtitle)
    }

    func testItemHasLinkIcon() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid"
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let item = sections.first?.items.first,
              case let .submenu(submenuItem) = item
        else {
            return XCTFail("Expected submenu item")
        }

        XCTAssertEqual(submenuItem.icon, .system("link"))
    }

    // MARK: - Menu Builder Tests

    func testMenuBuilderCallsActionHandler() {
        var buildLinkTypeMenuCalled = false
        var receivedTaskUUID: String?

        let handler = MockActionHandler(
            onBuildLinkTypeMenu: { uuid in
                buildLinkTypeMenuCalled = true
                receivedTaskUUID = uuid
            }
        )
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let testUUID = "test-uuid-menu-builder"
        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: testUUID
        )
        let sections = contributor.buildSections(context: context, query: "")

        guard let item = sections.first?.items.first,
              case let .submenu(submenuItem) = item
        else {
            return XCTFail("Expected submenu item")
        }

        // Invoke the menu builder
        _ = submenuItem.menuBuilder()

        XCTAssertTrue(buildLinkTypeMenuCalled)
        XCTAssertEqual(receivedTaskUUID, testUUID)
    }

    // MARK: - Contributor Metadata Tests

    func testContributorId() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        XCTAssertEqual(contributor.contributorId, "taskLink")
    }

    func testContributorPriority() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        // Priority 4 puts it after Actions (0) but before GroupBy (10)
        XCTAssertEqual(contributor.priority, 4)
    }

    // MARK: - Query Filtering Tests

    func testQueryDoesNotAffectVisibility() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "test-uuid"
        )

        // Various queries should still show the section
        XCTAssertEqual(contributor.buildSections(context: context, query: "").count, 1)
        XCTAssertEqual(contributor.buildSections(context: context, query: "link").count, 1)
        XCTAssertEqual(contributor.buildSections(context: context, query: "random").count, 1)
        XCTAssertEqual(contributor.buildSections(context: context, query: "xyz").count, 1)
    }

    // MARK: - Edge Cases

    func testWithDifferentUUIDs() {
        let handler = MockActionHandler()
        let contributor = TaskLinkSectionContributor(actionHandler: handler)

        let uuids = [
            "550e8400-e29b-41d4-a716-446655440000",
            "simple-uuid",
            "123",
            "", // Empty UUID
        ]

        for uuid in uuids {
            let context = CommandPaletteContext(
                hasSelectedTask: true,
                selectedTaskUUID: uuid
            )
            let sections = contributor.buildSections(context: context, query: "")

            if uuid.isEmpty {
                // Empty UUID should technically still work
                XCTAssertEqual(sections.count, 1)
            } else {
                XCTAssertEqual(sections.count, 1)
            }
        }
    }
}

// MARK: - Mock Action Handler

@MainActor
private final class MockActionHandler: CommandPaletteActionHandling {
    var onBuildLinkTypeMenu: ((String) -> Void)?

    init(onBuildLinkTypeMenu: ((String) -> Void)? = nil) {
        self.onBuildLinkTypeMenu = onBuildLinkTypeMenu
    }

    func buildReportMenu(reports: [ReportSummary], currentReportName: String?) -> CommandPaletteMenu {
        CommandPaletteMenu(id: "reports", title: "Reports", sections: [])
    }

    func buildGitlabMenu(taskUUID: String) -> CommandPaletteMenu {
        CommandPaletteMenu(id: "gitlab", title: "GitLab", sections: [])
    }

    func buildJiraMenu(taskUUID: String) -> CommandPaletteMenu {
        CommandPaletteMenu(id: "jira", title: "Jira", sections: [])
    }

    func clearProjectScope() {}

    func showSaveReportSheet() {}

    func deleteUserReport(name: String) {}

    func buildLinkTypeMenu(taskUUID: String) -> CommandPaletteMenu {
        onBuildLinkTypeMenu?(taskUUID)
        return CommandPaletteMenu(id: "link-type", title: "Link to Task", sections: [])
    }

    func buildTaskSelectorMenu(linkType: LinkType, sourceTaskUUID: String) -> CommandPaletteMenu {
        CommandPaletteMenu(id: "task-selector", title: "Select Task", sections: [])
    }
}
