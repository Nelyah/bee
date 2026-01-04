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
/// Uses `FuzzyMatcher` for fuzzy matching with match index tracking for highlighting.
@MainActor
final class CommandPaletteDataSource: ObservableObject {
    private var contributors: [CommandPaletteSectionContributor] = []

    init() {}

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
    /// filtered and ranked based on the query using fuzzy matching.
    /// Match indices are captured for highlighting in the view layer.
    ///
    /// - Parameters:
    ///   - context: The current palette context
    ///   - query: The current search query
    /// - Returns: An array of filtered sections with non-empty item lists
    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var allSections: [CommandPaletteSection] = []

        for contributor in contributors {
            let sections = contributor.buildSections(context: context, query: query)
            for section in sections {
                let filteredItems = filterAndRank(
                    items: section.items,
                    query: trimmedQuery,
                    sectionTitle: section.title
                )

                guard !filteredItems.isEmpty else { continue }

                // Match section title for highlighting
                var sectionTitleMatch: FuzzyMatch?
                if !trimmedQuery.isEmpty, let title = section.title {
                    // Try direct section title match first
                    sectionTitleMatch = FuzzyMatcher.match(trimmedQuery, in: title)

                    // If no direct match, try to extract from combined matches
                    if sectionTitleMatch == nil {
                        // Find an item that matched via combined and extract section indices
                        for matchedItem in filteredItems {
                            let combined = "\(title) \(matchedItem.item.displayTitle)"
                            if let combinedMatch = FuzzyMatcher.match(trimmedQuery, in: combined) {
                                let sectionLength = title.count
                                // Indices < sectionLength are in the section title
                                let sectionIndices = combinedMatch.matchedIndices.filter { $0 < sectionLength }
                                if !sectionIndices.isEmpty {
                                    sectionTitleMatch = FuzzyMatch(
                                        score: combinedMatch.score,
                                        matchedIndices: sectionIndices
                                    )
                                    break // Found section highlighting, no need to check more items
                                }
                            }
                        }
                    }
                }

                allSections.append(
                    CommandPaletteSection(
                        id: section.id,
                        title: section.title,
                        matchedItems: filteredItems,
                        sectionTitleMatch: sectionTitleMatch
                    )
                )
            }
        }

        return allSections
    }

    /// Filters and ranks items inside the provided sections based on the query.
    func filterSections(_ sections: [CommandPaletteSection], query: String) -> [CommandPaletteSection] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var filteredSections: [CommandPaletteSection] = []

        for section in sections {
            let filteredItems = filterAndRank(
                items: section.items,
                query: trimmedQuery,
                sectionTitle: section.title
            )

            guard !filteredItems.isEmpty else { continue }

            // Match section title for highlighting
            var sectionTitleMatch: FuzzyMatch?
            if !trimmedQuery.isEmpty, let title = section.title {
                // Try direct section title match first
                sectionTitleMatch = FuzzyMatcher.match(trimmedQuery, in: title)

                // If no direct match, try to extract from combined matches
                if sectionTitleMatch == nil {
                    for matchedItem in filteredItems {
                        let combined = "\(title) \(matchedItem.item.displayTitle)"
                        if let combinedMatch = FuzzyMatcher.match(trimmedQuery, in: combined) {
                            let sectionLength = title.count
                            let sectionIndices = combinedMatch.matchedIndices.filter { $0 < sectionLength }
                            if !sectionIndices.isEmpty {
                                sectionTitleMatch = FuzzyMatch(
                                    score: combinedMatch.score,
                                    matchedIndices: sectionIndices
                                )
                                break
                            }
                        }
                    }
                }
            }

            filteredSections.append(
                CommandPaletteSection(
                    id: section.id,
                    title: section.title,
                    matchedItems: filteredItems,
                    sectionTitleMatch: sectionTitleMatch
                )
            )
        }

        return filteredSections
    }

    /// Filters and ranks items based on the query using `FuzzyMatcher`.
    ///
    /// Items that don't match the query are filtered out. Matching items
    /// are sorted by score (highest first). Match indices are captured
    /// for highlighting in the view layer.
    ///
    /// - Parameters:
    ///   - items: The items to filter
    ///   - query: The trimmed search query
    ///   - sectionTitle: The section title to include in combined matching
    /// - Returns: Filtered and ranked items with match info
    private func filterAndRank(
        items: [CommandPaletteItem],
        query: String,
        sectionTitle: String? = nil
    ) -> [FuzzyMatchedPaletteItem] {
        // Empty query: return all items without highlighting
        guard !query.isEmpty else {
            return items.map { FuzzyMatchedPaletteItem(item: $0, titleMatch: nil, subtitleMatch: nil) }
        }

        return items
            .compactMap { item -> FuzzyMatchedPaletteItem? in
                // Try matching title directly
                var titleMatch = FuzzyMatcher.match(query, in: item.displayTitle)

                // Try matching subtitle
                let subtitleMatch: FuzzyMatch? = if let subtitle = item.subtitle {
                    FuzzyMatcher.match(query, in: subtitle)
                } else {
                    nil
                }

                // Try matching against section title + item title combined
                // This allows "groua" to match "Group by" + "Due Date" spanning both
                var combinedMatch: FuzzyMatch?
                if let sectionTitle {
                    let combined = "\(sectionTitle) \(item.displayTitle)"
                    combinedMatch = FuzzyMatcher.match(query, in: combined)

                    // If combined matched but title didn't, extract title portion of indices
                    if titleMatch == nil, let match = combinedMatch {
                        let sectionLength = sectionTitle.count
                        // Indices > sectionLength are in the item title (after the space)
                        let titleIndices = match.matchedIndices
                            .filter { $0 > sectionLength }
                            .map { $0 - sectionLength - 1 } // Subtract section length + 1 for space
                        if !titleIndices.isEmpty {
                            titleMatch = FuzzyMatch(score: match.score, matchedIndices: titleIndices)
                        }
                    }
                }

                // Must have at least one match to include the item
                guard titleMatch != nil || subtitleMatch != nil || combinedMatch != nil else {
                    return nil
                }

                return FuzzyMatchedPaletteItem(
                    item: item,
                    titleMatch: titleMatch,
                    subtitleMatch: subtitleMatch
                )
            }
            .sorted { $0.score > $1.score }
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
