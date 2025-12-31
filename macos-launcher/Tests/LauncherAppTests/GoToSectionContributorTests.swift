import XCTest

@testable import LauncherApp

@MainActor
final class GoToSectionContributorTests: XCTestCase {
    // MARK: - Section Building Tests

    func testBuildSectionsWithProjects() {
        let contributor = GoToSectionContributor(
            currentProjectScope: { nil },
            onProjectSelect: { _ in }
        )

        let context = CommandPaletteContext(projects: ["alpha", "beta", "gamma"])
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].id, "goTo")
        XCTAssertEqual(sections[0].title, "Go To")
        XCTAssertEqual(sections[0].items.count, 3)
    }

    func testBuildSectionsEmpty() {
        let contributor = GoToSectionContributor(
            currentProjectScope: { nil },
            onProjectSelect: { _ in }
        )

        let context = CommandPaletteContext(projects: [])
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertTrue(sections.isEmpty)
    }

    func testCurrentProjectMarkedAsCurrent() {
        let contributor = GoToSectionContributor(
            currentProjectScope: { "beta" },
            onProjectSelect: { _ in }
        )

        let context = CommandPaletteContext(projects: ["alpha", "beta", "gamma"])
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        let items = sections[0].items

        // Find the "beta" item and check its subtitle
        let betaItem = items.first { $0.displayTitle == "beta" }
        XCTAssertNotNil(betaItem)
        XCTAssertEqual(betaItem?.subtitle, "Current")

        // Other items should not have "Current" subtitle
        let alphaItem = items.first { $0.displayTitle == "alpha" }
        XCTAssertNotNil(alphaItem)
        XCTAssertNil(alphaItem?.subtitle)
    }

    func testProjectSelectCallback() {
        var selectedProject: String?
        let contributor = GoToSectionContributor(
            currentProjectScope: { nil },
            onProjectSelect: { selectedProject = $0 }
        )

        let context = CommandPaletteContext(projects: ["myproject"])
        let sections = contributor.buildSections(context: context, query: "")

        guard let item = sections.first?.items.first,
              case let .action(actionItem) = item
        else {
            return XCTFail("Expected action item")
        }

        actionItem.handler()

        XCTAssertEqual(selectedProject, "myproject")
    }

    func testContributorPriority() {
        let contributor = GoToSectionContributor(
            currentProjectScope: { nil },
            onProjectSelect: { _ in }
        )

        XCTAssertEqual(contributor.contributorId, "goTo")
        XCTAssertEqual(contributor.priority, 20)
    }
}

// MARK: - ActionsSectionContributor Clear Scope Tests

@MainActor
final class ActionsSectionContributorScopeTests: XCTestCase {
    func testClearProjectScopeActionAppearsWhenScopeSet() {
        let handler = MockActionHandler()
        let contributor = ActionsSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(currentProjectScope: "myproject")
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        let items = sections[0].items

        // Find the clear scope action
        let clearItem = items.first {
            if case let .action(action) = $0 {
                return action.id == "clear-project-scope"
            }
            return false
        }
        XCTAssertNotNil(clearItem, "Clear project scope action should be present")

        // Check the subtitle shows the scoped project
        if case let .action(action)? = clearItem {
            XCTAssertEqual(action.subtitle, "myproject")
        }
    }

    func testClearProjectScopeActionHiddenWhenNoScope() {
        let handler = MockActionHandler()
        let contributor = ActionsSectionContributor(actionHandler: handler)

        let context = CommandPaletteContext(currentProjectScope: nil)
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        let items = sections[0].items

        // Should not find clear scope action
        let clearItem = items.first {
            if case let .action(action) = $0 {
                return action.id == "clear-project-scope"
            }
            return false
        }
        XCTAssertNil(clearItem, "Clear project scope action should not be present when no scope")
    }
}

// MARK: - Mock Action Handler

@MainActor
private final class MockActionHandler: CommandPaletteActionHandling {
    var clearProjectScopeCalled = false

    func buildReportMenu(reports: [ReportSummary], currentReportName: String?) -> CommandPaletteMenu {
        CommandPaletteMenu(id: "reports", title: "Reports", sections: [])
    }

    func buildGitlabMenu(taskUUID: String) -> CommandPaletteMenu {
        CommandPaletteMenu(id: "gitlab", title: "GitLab", sections: [])
    }

    func buildJiraMenu(taskUUID: String) -> CommandPaletteMenu {
        CommandPaletteMenu(id: "jira", title: "Jira", sections: [])
    }

    func clearProjectScope() {
        clearProjectScopeCalled = true
    }
}
