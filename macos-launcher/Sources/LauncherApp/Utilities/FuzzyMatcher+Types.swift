import Foundation

/// Represents a fuzzy match result with score and matched character positions.
struct FuzzyMatch {
    /// Match quality score (larger is better).
    let score: Double

    /// Indices of characters in the target string that matched the query.
    let matchedIndices: [Int]
}

extension FuzzyMatcher {
    enum TermType {
        case fuzzy
        case exact
        case exactBoundary
        case prefix
        case suffix
        case equal
    }

    struct Term {
        let type: TermType
        let isInverse: Bool
        let text: [UInt32]
        let caseSensitive: Bool
        let normalize: Bool
    }

    typealias TermSet = [Term]

    struct Pattern {
        let termSets: [TermSet]
        let isEmpty: Bool
    }

    struct MatchResult {
        let score: Int
        let matchedScalarIndices: [Int]
    }
}
