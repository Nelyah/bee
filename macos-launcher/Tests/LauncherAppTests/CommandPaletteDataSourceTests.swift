import XCTest

@testable import LauncherApp

@MainActor
final class CommandPaletteDataSourceTests: XCTestCase {
    private var dataSource: CommandPaletteDataSource!

    override func setUp() {
        super.setUp()
        dataSource = CommandPaletteDataSource()
    }

    override func tearDown() {
        dataSource = nil
        super.tearDown()
    }

    // MARK: - Registration Tests

    func testRegisterContributor() {
        let contributor = MockContributor(id: "test", priority: 0)
        dataSource.register(contributor)

        XCTAssertEqual(dataSource.contributorCount, 1)
        XCTAssertEqual(dataSource.contributorIds, ["test"])
    }

    func testRegisterMultipleContributors() {
        dataSource.register(MockContributor(id: "a", priority: 10))
        dataSource.register(MockContributor(id: "b", priority: 5))
        dataSource.register(MockContributor(id: "c", priority: 20))

        XCTAssertEqual(dataSource.contributorCount, 3)
    }

    func testContributorsSortedByPriority() {
        dataSource.register(MockContributor(id: "high", priority: 100))
        dataSource.register(MockContributor(id: "low", priority: 0))
        dataSource.register(MockContributor(id: "mid", priority: 50))

        XCTAssertEqual(dataSource.contributorIds, ["low", "mid", "high"])
    }

    func testUnregisterContributor() {
        dataSource.register(MockContributor(id: "keep", priority: 0))
        dataSource.register(MockContributor(id: "remove", priority: 10))
        dataSource.unregister(contributorId: "remove")

        XCTAssertEqual(dataSource.contributorCount, 1)
        XCTAssertEqual(dataSource.contributorIds, ["keep"])
    }

    func testClearContributors() {
        dataSource.register(MockContributor(id: "a", priority: 0))
        dataSource.register(MockContributor(id: "b", priority: 10))
        dataSource.clearContributors()

        XCTAssertEqual(dataSource.contributorCount, 0)
    }

    // MARK: - Section Building Tests

    func testBuildSectionsFromContributors() {
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "section1",
                    title: "Actions",
                    items: [
                        .action(
                            CommandPaletteActionItem(
                                id: "action1",
                                title: "Select Report",
                                handler: {}
                            ))
                    ]
                )
            ]
        )
        dataSource.register(contributor)

        let context = CommandPaletteContext()
        let sections = dataSource.buildSections(context: context, query: "")

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].title, "Actions")
        XCTAssertEqual(sections[0].items.count, 1)
    }

    func testBuildSectionsAggregatesMultipleContributors() {
        let contributor1 = MockContributor(
            id: "first",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "s1",
                    title: "First",
                    items: [
                        .action(CommandPaletteActionItem(id: "a1", title: "Action 1", handler: {}))
                    ]
                )
            ]
        )
        let contributor2 = MockContributor(
            id: "second",
            priority: 10,
            sections: [
                CommandPaletteSection(
                    id: "s2",
                    title: "Second",
                    items: [
                        .action(CommandPaletteActionItem(id: "a2", title: "Action 2", handler: {}))
                    ]
                )
            ]
        )
        dataSource.register(contributor1)
        dataSource.register(contributor2)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "")

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].title, "First")
        XCTAssertEqual(sections[1].title, "Second")
    }

    // MARK: - Filtering Tests

    func testFilteringRemovesNonMatchingItems() {
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "s1",
                    items: [
                        .action(
                            CommandPaletteActionItem(id: "a1", title: "Select Report", handler: {})),
                        .action(
                            CommandPaletteActionItem(id: "a2", title: "Add GitLab link", handler: {})),
                        .action(
                            CommandPaletteActionItem(id: "a3", title: "Add Jira link", handler: {})),
                    ]
                )
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "git")

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].items.count, 1)
        XCTAssertEqual(sections[0].items[0].displayTitle, "Add GitLab link")
    }

    func testEmptyQueryReturnsAllItems() {
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "s1",
                    items: [
                        .action(
                            CommandPaletteActionItem(id: "a1", title: "Select Report", handler: {})),
                        .action(
                            CommandPaletteActionItem(id: "a2", title: "Add GitLab link", handler: {})),
                    ]
                )
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "")

        XCTAssertEqual(sections[0].items.count, 2)
    }

    func testWhitespaceOnlyQueryReturnsAllItems() {
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "s1",
                    items: [
                        .action(
                            CommandPaletteActionItem(id: "a1", title: "Select Report", handler: {}))
                    ]
                )
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "   ")

        XCTAssertEqual(sections[0].items.count, 1)
    }

    func testFilteringBySubtitle() {
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "s1",
                    items: [
                        .action(
                            CommandPaletteActionItem(
                                id: "a1",
                                title: "Action",
                                subtitle: "special keyword",
                                handler: {}
                            ))
                    ]
                )
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "keyword")

        XCTAssertEqual(sections[0].items.count, 1)
    }

    func testEmptySectionRemovedAfterFiltering() {
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "s1",
                    title: "Will be empty",
                    items: [
                        .action(CommandPaletteActionItem(id: "a1", title: "ABC", handler: {}))
                    ]
                )
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "xyz")

        XCTAssertEqual(sections.count, 0)
    }

    // MARK: - Ranking Tests

    func testItemsRankedByScore() {
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "s1",
                    items: [
                        .action(
                            CommandPaletteActionItem(
                                id: "fuzzy", title: "Add something GitLab", handler: {})),  // fuzzy match for "git"
                        .action(
                            CommandPaletteActionItem(id: "prefix", title: "GitLab link", handler: {})),  // prefix match
                        .action(
                            CommandPaletteActionItem(
                                id: "word", title: "Add GitLab", handler: {})),  // word prefix match
                    ]
                )
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "git")

        XCTAssertEqual(sections[0].items.count, 3)
        // Prefix match should be first
        XCTAssertEqual(sections[0].items[0].displayTitle, "GitLab link")
    }
}

// MARK: - Mock Contributor

private struct MockContributor: CommandPaletteSectionContributor {
    let contributorId: String
    let priority: Int
    let sections: [CommandPaletteSection]

    init(id: String, priority: Int, sections: [CommandPaletteSection] = []) {
        self.contributorId = id
        self.priority = priority
        self.sections = sections
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        sections
    }
}
