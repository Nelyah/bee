import XCTest

@testable import LauncherAppKit

@MainActor
final class ProjectOverviewSectionContributorTests: XCTestCase {
    // MARK: - Section Building Tests

    func testReturnsOneSection() {
        var navigateCalled = false
        let contributor = ProjectOverviewSectionContributor(
            onNavigate: { navigateCalled = true }
        )

        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)
        let sections = contributor.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].id, "projectOverview")
        XCTAssertNil(sections[0].title)
        XCTAssertFalse(navigateCalled)
    }

    func testReturnsSingleActionItem() {
        let contributor = ProjectOverviewSectionContributor(
            onNavigate: {}
        )

        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)
        let sections = contributor.buildSections(context: context, query: "")

        guard let items = sections.first?.items else {
            return XCTFail("Expected items in section")
        }

        XCTAssertEqual(items.count, 1)

        if case let .action(actionItem) = items[0] {
            XCTAssertEqual(actionItem.id, "go-to-projects")
            XCTAssertEqual(actionItem.title, "Go to Projects")
            XCTAssertEqual(actionItem.subtitle, "View project statistics and burndown charts")
            XCTAssertEqual(actionItem.icon, .system("chart.bar.xaxis"))
        } else {
            XCTFail("Expected action item")
        }
    }

    func testHandlerCallsOnNavigate() {
        var navigateCalled = false
        let contributor = ProjectOverviewSectionContributor(
            onNavigate: { navigateCalled = true }
        )

        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)
        let sections = contributor.buildSections(context: context, query: "")

        guard let items = sections.first?.items,
              case let .action(actionItem) = items[0]
        else {
            return XCTFail("Expected action item")
        }

        XCTAssertFalse(navigateCalled)
        actionItem.handler()
        XCTAssertTrue(navigateCalled)
    }

    func testContributorPriority() {
        let contributor = ProjectOverviewSectionContributor(
            onNavigate: {}
        )

        XCTAssertEqual(contributor.contributorId, "projectOverview")
        XCTAssertEqual(contributor.priority, 15)
    }

    // MARK: - Query Filtering Tests

    func testFiltersMatchOnTitle() {
        let contributor = ProjectOverviewSectionContributor(
            onNavigate: {}
        )

        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)

        // Should match "Go to Projects"
        let sections = contributor.buildSections(context: context, query: "projects")
        XCTAssertEqual(sections.count, 1)
    }

    func testFiltersMatchOnSubtitle() {
        let contributor = ProjectOverviewSectionContributor(
            onNavigate: {}
        )

        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)

        // Should match "View project statistics and burndown charts"
        let sections = contributor.buildSections(context: context, query: "statistics")
        XCTAssertEqual(sections.count, 1)
    }

    func testFiltersMatchOnBurndown() {
        let contributor = ProjectOverviewSectionContributor(
            onNavigate: {}
        )

        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)

        // Should match "burndown" keyword
        let sections = contributor.buildSections(context: context, query: "burndown")
        XCTAssertEqual(sections.count, 1)
    }

    func testFiltersOutNonMatchingQuery() {
        let contributor = ProjectOverviewSectionContributor(
            onNavigate: {}
        )

        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)

        // Should not match unrelated query
        let sections = contributor.buildSections(context: context, query: "xyz123")
        XCTAssertTrue(sections.isEmpty)
    }

    func testQueryIsCaseInsensitive() {
        let contributor = ProjectOverviewSectionContributor(
            onNavigate: {}
        )

        let context = CommandPaletteContext(hasSelectedTask: false, selectedTaskUUID: nil)

        // Should match case-insensitively
        let sections = contributor.buildSections(context: context, query: "PROJECTS")
        XCTAssertEqual(sections.count, 1)
    }
}
