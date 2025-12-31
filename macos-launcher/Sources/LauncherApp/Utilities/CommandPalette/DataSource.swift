import Foundation

/// Protocol for objects that contribute sections to the command palette.
///
/// Implementers can provide their own sections based on context and query.
/// Contributors are registered with the DataSource and called in priority order.
protocol CommandPaletteSectionContributor {
    /// Unique identifier for this contributor
    var contributorId: String { get }

    /// Order priority (lower values appear first)
    var priority: Int { get }

    /// Build sections for the given context.
    ///
    /// - Parameters:
    ///   - context: The current palette context with task selection, reports, etc.
    ///   - query: The current search query
    /// - Returns: An array of sections to display
    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection]
}

/// Aggregates and filters sections from multiple contributors.
///
/// The DataSource manages a registry of section contributors and handles
/// filtering and ranking of items based on the current search query.
@MainActor
final class CommandPaletteDataSource: ObservableObject {
    private var contributors: [CommandPaletteSectionContributor] = []
    private let scorer: CommandPaletteFuzzyScorer

    init(scorer: CommandPaletteFuzzyScorer = CommandPaletteFuzzyScorer()) {
        self.scorer = scorer
    }

    /// Registers a section contributor.
    ///
    /// Contributors are automatically sorted by priority after registration.
    ///
    /// - Parameter contributor: The contributor to register
    func register(_ contributor: CommandPaletteSectionContributor) {
        contributors.append(contributor)
        contributors.sort { $0.priority < $1.priority }
    }

    /// Unregisters a section contributor by ID.
    ///
    /// - Parameter contributorId: The ID of the contributor to remove
    func unregister(contributorId: String) {
        contributors.removeAll { $0.contributorId == contributorId }
    }

    /// Removes all registered contributors.
    func clearContributors() {
        contributors.removeAll()
    }

    /// Builds and filters sections from all contributors.
    ///
    /// Sections are built in priority order. Items within each section are
    /// filtered and ranked based on the query using fuzzy scoring.
    ///
    /// - Parameters:
    ///   - context: The current palette context
    ///   - query: The current search query
    /// - Returns: An array of filtered sections with non-empty item lists
    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        var allSections: [CommandPaletteSection] = []

        for contributor in contributors {
            let sections = contributor.buildSections(context: context, query: query)
            for section in sections {
                let filteredItems = filterAndRank(items: section.items, query: query)
                if !filteredItems.isEmpty {
                    allSections.append(
                        CommandPaletteSection(
                            id: section.id,
                            title: section.title,
                            items: filteredItems
                        )
                    )
                }
            }
        }

        return allSections
    }

    /// Filters and ranks items inside the provided sections based on the query.
    func filterSections(_ sections: [CommandPaletteSection], query: String) -> [CommandPaletteSection] {
        var filteredSections: [CommandPaletteSection] = []

        for section in sections {
            let filteredItems = filterAndRank(items: section.items, query: query)
            if !filteredItems.isEmpty {
                filteredSections.append(
                    CommandPaletteSection(
                        id: section.id,
                        title: section.title,
                        items: filteredItems
                    )
                )
            }
        }

        return filteredSections
    }

    /// Filters and ranks items based on the query.
    ///
    /// Items that don't match the query are filtered out. Matching items
    /// are sorted by score (highest first).
    ///
    /// - Parameters:
    ///   - items: The items to filter
    ///   - query: The search query
    /// - Returns: Filtered and ranked items
    private func filterAndRank(items: [CommandPaletteItem], query: String) -> [CommandPaletteItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return items }

        return items
            .compactMap { item -> (item: CommandPaletteItem, score: Int)? in
                // Score against display title
                if let score = scorer.score(query: trimmedQuery, target: item.displayTitle) {
                    return (item, score)
                }
                // Also check subtitle if available
                if let subtitle = item.subtitle,
                   let score = scorer.score(query: trimmedQuery, target: subtitle)
                {
                    return (item, score)
                }
                return nil
            }
            .sorted { $0.score > $1.score }
            .map(\.item)
    }

    /// Returns the number of registered contributors.
    var contributorCount: Int {
        contributors.count
    }

    /// Returns the IDs of all registered contributors in priority order.
    var contributorIds: [String] {
        contributors.map(\.contributorId)
    }
}
