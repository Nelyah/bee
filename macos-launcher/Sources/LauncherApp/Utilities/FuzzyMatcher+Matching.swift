import Foundation

extension FuzzyMatcher {
    // MARK: - Extended Match

    static func matchExtended(pattern: Pattern, input: ScalarChars) -> FuzzyMatch? {
        var allScalarIndices: [Int] = []
        var totalScore = 0

        for termSet in pattern.termSets {
            var matched = false
            var currentScore = 0
            var currentIndices: [Int] = []

            for term in termSet {
                let result = matchTerm(term, input: input)
                if let result {
                    if term.isInverse {
                        continue
                    }
                    matched = true
                    currentScore = result.score
                    currentIndices = result.matchedScalarIndices
                    break
                } else if term.isInverse {
                    matched = true
                    currentScore = 0
                    currentIndices = []
                    continue
                }
            }

            if matched {
                totalScore += currentScore
                allScalarIndices.append(contentsOf: currentIndices)
            } else {
                return nil
            }
        }

        let matchedIndices = mapScalarIndicesToCharacterIndices(
            allScalarIndices,
            mapping: input.scalarToCharacterIndex
        )
        return FuzzyMatch(score: Double(totalScore), matchedIndices: matchedIndices)
    }

    static func matchTerm(_ term: Term, input: ScalarChars) -> MatchResult? {
        switch term.type {
        case .fuzzy:
            fuzzyMatchV2(
                caseSensitive: term.caseSensitive,
                normalize: term.normalize,
                input: input,
                pattern: term.text
            )
        case .exact:
            exactMatch(
                caseSensitive: term.caseSensitive,
                normalize: term.normalize,
                input: input,
                pattern: term.text,
                boundary: false
            )
        case .exactBoundary:
            exactMatch(
                caseSensitive: term.caseSensitive,
                normalize: term.normalize,
                input: input,
                pattern: term.text,
                boundary: true
            )
        case .prefix:
            prefixMatch(
                caseSensitive: term.caseSensitive,
                normalize: term.normalize,
                input: input,
                pattern: term.text
            )
        case .suffix:
            suffixMatch(
                caseSensitive: term.caseSensitive,
                normalize: term.normalize,
                input: input,
                pattern: term.text
            )
        case .equal:
            equalMatch(
                caseSensitive: term.caseSensitive,
                normalize: term.normalize,
                input: input,
                pattern: term.text
            )
        }
    }
}
