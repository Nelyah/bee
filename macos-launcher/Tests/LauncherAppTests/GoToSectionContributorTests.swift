import XCTest

@testable import LauncherAppKit

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
        XCTAssertEqual(sections[0].title, "Go to project")
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

// MARK: - SaveReportSectionContributor Tests

@MainActor
final class SaveReportSectionContributorTests: XCTestCase {
    func testShowsSaveActionWhenFiltersExist() {
        let handler = MockActionHandler()
        let contributor = SaveReportSectionContributor(
            actionHandler: handler,
            getCurrentFilters: { ["status:pending", "project:work"] },
            getUserReports: { [] }
        )

        let context = CommandPaletteContext()
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        let items = sections[0].items

        // Find the save action
        let saveItem = items.first {
            if case let .action(action) = $0 {
                return action.id == "save-report"
            }
            return false
        }
        XCTAssertNotNil(saveItem, "Save report action should be present when filters exist")
    }

    func testHidesSaveActionWhenNoFilters() {
        let handler = MockActionHandler()
        let contributor = SaveReportSectionContributor(
            actionHandler: handler,
            getCurrentFilters: { [] },
            getUserReports: { [] }
        )

        let context = CommandPaletteContext()
        let sections = contributor.buildSections(context: context, query: "")

        // Should be empty since no filters and no user reports
        XCTAssertTrue(sections.isEmpty, "No sections should appear when no filters and no user reports")
    }

    func testShowsDeleteSubmenuWhenUserReportsExist() {
        let handler = MockActionHandler()
        let userReport = ReportSummary(
            name: "MyCustomReport",
            staticFilters: ["tag:urgent"],
            columns: ["summary"],
            columnNames: ["Summary"],
            isDefault: false,
            isUserReport: true
        )
        let contributor = SaveReportSectionContributor(
            actionHandler: handler,
            getCurrentFilters: { [] },
            getUserReports: { [userReport] }
        )

        let context = CommandPaletteContext()
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        let items = sections[0].items

        // Find the delete submenu
        let deleteItem = items.first {
            if case let .submenu(submenu) = $0 {
                return submenu.id == "delete-report-menu"
            }
            return false
        }
        XCTAssertNotNil(deleteItem, "Delete report submenu should be present when user reports exist")
    }

    func testHidesDeleteSubmenuWhenNoUserReports() {
        let handler = MockActionHandler()
        let contributor = SaveReportSectionContributor(
            actionHandler: handler,
            getCurrentFilters: { ["status:pending"] },
            getUserReports: { [] }
        )

        let context = CommandPaletteContext()
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        let items = sections[0].items

        // Should not find delete submenu
        let deleteItem = items.first {
            if case let .submenu(submenu) = $0 {
                return submenu.id == "delete-report-menu"
            }
            return false
        }
        XCTAssertNil(deleteItem, "Delete report submenu should not be present when no user reports")
    }

    func testDeleteSubmenuOnlyShowsUserReports() {
        let handler = MockActionHandler()
        let staticReport = ReportSummary(
            name: "BuiltIn",
            staticFilters: ["status:pending"],
            columns: ["summary"],
            columnNames: ["Summary"],
            isDefault: true,
            isUserReport: false
        )
        let userReport = ReportSummary(
            name: "MyCustomReport",
            staticFilters: ["tag:urgent"],
            columns: ["summary"],
            columnNames: ["Summary"],
            isDefault: false,
            isUserReport: true
        )
        let contributor = SaveReportSectionContributor(
            actionHandler: handler,
            getCurrentFilters: { [] },
            getUserReports: { [staticReport, userReport] }
        )

        let context = CommandPaletteContext()
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)

        // Verify delete submenu exists (only user reports should be deletable)
        let deleteItem = sections[0].items.first {
            if case let .submenu(submenu) = $0 {
                return submenu.id == "delete-report-menu"
            }
            return false
        }
        XCTAssertNotNil(deleteItem, "Delete report submenu should be present")
    }

    func testContributorPriority() {
        let handler = MockActionHandler()
        let contributor = SaveReportSectionContributor(
            actionHandler: handler,
            getCurrentFilters: { [] },
            getUserReports: { [] }
        )

        XCTAssertEqual(contributor.contributorId, "saveReport")
        XCTAssertEqual(contributor.priority, 5)
    }
}

// MARK: - ReportSummary Decoding Tests

final class ReportSummaryDecodingTests: XCTestCase {
    func testDecodesIsUserReportTrue() throws {
        let json = """
        {
            "name": "custom-report",
            "filters": ["status:pending"],
            "columns": ["summary", "due"],
            "column_names": ["Summary", "Due Date"],
            "is_default": false,
            "is_user_report": true
        }
        """
        let data = Data(json.utf8)
        let report = try JSONDecoder().decode(ReportSummary.self, from: data)

        XCTAssertEqual(report.name, "custom-report")
        XCTAssertTrue(report.isUserReport)
    }

    func testDecodesIsUserReportFalse() throws {
        let json = """
        {
            "name": "built-in-report",
            "filters": ["status:pending"],
            "columns": ["summary"],
            "column_names": ["Summary"],
            "is_default": true,
            "is_user_report": false
        }
        """
        let data = Data(json.utf8)
        let report = try JSONDecoder().decode(ReportSummary.self, from: data)

        XCTAssertEqual(report.name, "built-in-report")
        XCTAssertFalse(report.isUserReport)
    }

    func testDefaultsIsUserReportToFalse() throws {
        // When is_user_report is not present, it should default to false
        let json = """
        {
            "name": "legacy-report",
            "filters": [],
            "columns": ["summary"],
            "column_names": ["Summary"],
            "is_default": false
        }
        """
        let data = Data(json.utf8)
        let report = try JSONDecoder().decode(ReportSummary.self, from: data)

        XCTAssertEqual(report.name, "legacy-report")
        XCTAssertFalse(report.isUserReport, "isUserReport should default to false when not present in JSON")
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

    func showSaveReportSheet() {
        // No-op for test
    }

    func deleteUserReport(name: String) {
        // No-op for test
    }

    func addAttachment() {
        // No-op for test
    }

    func buildLinkTypeMenu(taskUUID: String) -> CommandPaletteMenu {
        CommandPaletteMenu(id: "link-type", title: "Link to Task", sections: [])
    }

    func buildTaskSelectorMenu(linkType: LinkType, sourceTaskUUID: String) -> CommandPaletteMenu {
        CommandPaletteMenu(id: "task-selector", title: "Select Task", sections: [])
    }
}
