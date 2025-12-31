import Foundation

/// Weighted fuzzy scoring for command palette filtering.
///
/// Scores are assigned based on match quality:
/// - Exact match: highest priority
/// - Prefix match: high priority (query matches start of target)
/// - Word prefix match: medium priority (query matches start of any word)
/// - Substring match: low priority (query found within target)
/// - Fuzzy match: lowest priority (characters appear in order)
struct CommandPaletteFuzzyScorer {
    /// Score weights for different match types
    enum MatchWeight: Int {
        case exactMatch = 1000
        case prefixMatch = 100
        case wordPrefixMatch = 50
        case substringMatch = 25
        case fuzzyMatch = 10
    }

    /// Returns a score for how well query matches target, or nil if no match.
    ///
    /// Higher scores indicate better matches. Returns nil if the query
    /// does not match the target at all.
    ///
    /// - Parameters:
    ///   - query: The search query string
    ///   - target: The target string to match against
    /// - Returns: A score representing match quality, or nil if no match
    func score(query: String, target: String) -> Int? {
        guard !query.isEmpty else { return MatchWeight.exactMatch.rawValue }

        let queryLower = query.lowercased()
        let targetLower = target.lowercased()

        // Exact match
        if queryLower == targetLower {
            return MatchWeight.exactMatch.rawValue
        }

        // Prefix match (query matches start of target)
        if targetLower.hasPrefix(queryLower) {
            // Bonus for shorter queries that match longer strings
            return MatchWeight.prefixMatch.rawValue + max(0, 100 - query.count)
        }

        // Word-wise prefix match (matches start of any word)
        let words = targetLower.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
        for word in words where word.hasPrefix(queryLower) {
            return MatchWeight.wordPrefixMatch.rawValue + max(0, 50 - query.count)
        }

        // Substring match (query found within target)
        if targetLower.contains(queryLower) {
            return MatchWeight.substringMatch.rawValue
        }

        // Fuzzy match (characters appear in order)
        if fuzzyMatches(queryLower, in: targetLower) {
            return MatchWeight.fuzzyMatch.rawValue
        }

        return nil
    }

    /// Checks if query characters appear in order within value.
    ///
    /// - Parameters:
    ///   - query: The query string (should be lowercased)
    ///   - value: The target string (should be lowercased)
    /// - Returns: True if all characters in query appear in order in value
    private func fuzzyMatches(_ query: String, in value: String) -> Bool {
        guard !query.isEmpty else { return true }

        var remaining = value[...]
        for char in query {
            guard let idx = remaining.firstIndex(of: char) else {
                return false
            }
            remaining = remaining[remaining.index(after: idx)...]
        }
        return true
    }
}
