import XCTest

@testable import LauncherApp

@MainActor
final class CommandPaletteDataSourceTests: XCTestCase {
    private var dataSource = CommandPaletteDataSource()

    override func setUp() {
        super.setUp()
        dataSource = CommandPaletteDataSource()
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
                            )),
                    ]
                ),
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
                        .action(CommandPaletteActionItem(id: "a1", title: "Action 1", handler: {})),
                    ]
                ),
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
                        .action(CommandPaletteActionItem(id: "a2", title: "Action 2", handler: {})),
                    ]
                ),
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
                ),
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
                ),
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
                            CommandPaletteActionItem(id: "a1", title: "Select Report", handler: {})),
                    ]
                ),
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
                            )),
                    ]
                ),
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
                        .action(CommandPaletteActionItem(id: "a1", title: "ABC", handler: {})),
                    ]
                ),
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "xyz")

        XCTAssertEqual(sections.count, 0)
    }

    // MARK: - Ranking Tests

    // MARK: - Section Title Matching Tests

    func testFilteringMatchesSectionTitle() {
        // When a query includes words from the section title,
        // items in that section should match even if the item title
        // doesn't contain those words.
        // Example: "project biran" should match item "biran" in "Go to project" section
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "goTo",
                    title: "Go to project",
                    items: [
                        .action(
                            CommandPaletteActionItem(id: "p1", title: "biran", handler: {})),
                        .action(
                            CommandPaletteActionItem(id: "p2", title: "backend", handler: {})),
                    ]
                ),
            ]
        )
        dataSource.register(contributor)

        // Query "project biran" should match "biran" because:
        // - "project" is in section title "Go to project"
        // - "biran" is the item title
        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "project biran")

        XCTAssertEqual(sections.count, 1, "Section should not be filtered out")
        XCTAssertEqual(sections[0].items.count, 1, "Should match 'biran' item")
        XCTAssertEqual(sections[0].items[0].displayTitle, "biran")
    }

    func testFilteringMatchesSectionTitlePartially() {
        // "go to backend" should match "backend" in "Go to project" section
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "goTo",
                    title: "Go to project",
                    items: [
                        .action(
                            CommandPaletteActionItem(id: "p1", title: "frontend", handler: {})),
                        .action(
                            CommandPaletteActionItem(id: "p2", title: "backend", handler: {})),
                    ]
                ),
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "go to backend")

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].items.count, 1)
        XCTAssertEqual(sections[0].items[0].displayTitle, "backend")
    }

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
                                id: "fuzzy", title: "Add something GitLab", handler: {}
                            )), // fuzzy match for "git"
                        .action(
                            CommandPaletteActionItem(id: "prefix", title: "GitLab link", handler: {})), // prefix match
                        .action(
                            CommandPaletteActionItem(
                                id: "word", title: "Add GitLab", handler: {}
                            )), // word prefix match
                    ]
                ),
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "git")

        XCTAssertEqual(sections[0].items.count, 3)
        let scores = sections[0].matchedItems.map(\.score)
        XCTAssertEqual(
            scores,
            scores.sorted(by: >),
            "Items should be ranked by descending score"
        )
    }

    // MARK: - Fuzzy Match Highlighting Tests

    func testCombinedMatchHighlightsBothSectionAndItem() throws {
        // When query "groua" matches across "Group by" and "Due Date":
        // - "grou" matches in "Group by"
        // - "a" matches in "Due Date"
        // Both should have match indices for highlighting
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "grouping",
                    title: "Group by",
                    items: [
                        .action(
                            CommandPaletteActionItem(id: "due", title: "Due Date", handler: {})),
                        .action(
                            // Use "None" which has no 'a' so it won't match "groua"
                            CommandPaletteActionItem(id: "none", title: "None", handler: {})),
                    ]
                ),
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "groua")

        XCTAssertEqual(sections.count, 1, "Section should be included")
        XCTAssertEqual(sections[0].items.count, 1, "Only Due Date should match (None has no 'a')")
        XCTAssertEqual(sections[0].items[0].displayTitle, "Due Date")

        // Verify section title has match indices for highlighting
        let sectionMatch = try XCTUnwrap(sections[0].sectionTitleMatch, "Section should have match info")
        XCTAssertFalse(sectionMatch.matchedIndices.isEmpty, "Section title should have highlighted indices")
        // "grou" matches indices 0,1,2,3 in "Group by"
        XCTAssertTrue(
            sectionMatch.matchedIndices.contains(0),
            "Should highlight 'G' in Group"
        )

        // Verify item title has match indices for the "a" in "Due Date"
        let titleMatch = try XCTUnwrap(
            sections[0].matchedItems[0].titleMatch,
            "Item should have title match info"
        )
        XCTAssertFalse(titleMatch.matchedIndices.isEmpty, "Item title should have highlighted indices")
        // "a" matches index 5 in "Due Date" (the 'a' in Date)
        XCTAssertTrue(
            titleMatch.matchedIndices.contains(5),
            "Should highlight 'a' in Date"
        )
    }

    func testDirectMatchTakesPrecedenceOverCombinedMatch() throws {
        // When query "group" matches section title directly,
        // the direct match should be used (not extracted from combined)
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "grouping",
                    title: "Group by",
                    items: [
                        .action(
                            CommandPaletteActionItem(id: "due", title: "Due Date", handler: {})),
                    ]
                ),
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "group")

        XCTAssertEqual(sections.count, 1)
        // Direct section title match should have indices for "Group"
        let sectionMatch = try XCTUnwrap(sections[0].sectionTitleMatch)
        XCTAssertEqual(sectionMatch.matchedIndices.count, 5, "Should match all 5 chars of 'group'")
    }

    func testNoHighlightingForUnmatchedParts() throws {
        // When query matches only the item title (not spanning section),
        // section should not be highlighted
        let contributor = MockContributor(
            id: "test",
            priority: 0,
            sections: [
                CommandPaletteSection(
                    id: "grouping",
                    title: "Group by",
                    items: [
                        .action(
                            CommandPaletteActionItem(id: "due", title: "Due Date", handler: {})),
                    ]
                ),
            ]
        )
        dataSource.register(contributor)

        let sections = dataSource.buildSections(context: CommandPaletteContext(), query: "due")

        XCTAssertEqual(sections.count, 1)
        // Section title should NOT be highlighted (query doesn't match "Group by")
        XCTAssertNil(sections[0].sectionTitleMatch, "Section title should not be highlighted")

        // Item title should be highlighted
        let titleMatch = try XCTUnwrap(sections[0].matchedItems[0].titleMatch)
        XCTAssertFalse(titleMatch.matchedIndices.isEmpty)
    }
}

// MARK: - Mock Contributor

private struct MockContributor: CommandPaletteSectionContributor {
    let contributorId: String
    let priority: Int
    let sections: [CommandPaletteSection]

    init(id: String, priority: Int, sections: [CommandPaletteSection] = []) {
        contributorId = id
        self.priority = priority
        self.sections = sections
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        sections
    }
}
