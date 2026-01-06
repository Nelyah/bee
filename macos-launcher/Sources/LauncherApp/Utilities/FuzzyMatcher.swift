import Foundation
import SwiftUI

/// Represents a fuzzy match result with score and matched character positions.
struct FuzzyMatch {
    /// Match quality score (0.0-1.0, where 1.0 is perfect match).
    let score: Double

    /// Indices of characters in the target string that matched the query.
    let matchedIndices: [Int]
}

/// Provides fuzzy string matching with fzf-style query syntax.
///
/// Supported query forms (fzf extended search):
/// - Fuzzy match: `abc` (default)
/// - Exact match: `'abc` (substring)
/// - Exact word-boundary match: `'abc'`
/// - Prefix match: `^abc`
/// - Suffix match: `abc$`
/// - Inverse match: `!abc`
/// - OR groups: `foo | bar`
/// - Multiple terms are ANDed: `^core go$`
///
/// Fuzzy scoring uses a dynamic programming approach similar to fzy.
enum FuzzyMatcher {
    private enum MatchMode {
        case fuzzy
        case exact
        case prefix
        case suffix
        case boundary
    }

    private struct QueryToken {
        let pattern: String
        let mode: MatchMode
        let isInverse: Bool
    }

    // MARK: - Scoring Constants

    /// Scoring constants based on the fzy algorithm.
    private enum Score {
        /// Base score for each matched character.
        static let match: Double = 16.0

        /// Penalty for starting a gap (non-consecutive match).
        static let gapStart: Double = -3.0

        /// Penalty for each additional character in a gap.
        static let gapExtend: Double = -1.0

        /// Bonus for matching the first character of the target.
        static let bonusFirstChar: Double = 16.0

        /// Bonus for matching after a word boundary character.
        static let bonusBoundary: Double = 8.0

        /// Bonus for matching a CamelCase transition.
        static let bonusCamel: Double = 7.0

        /// Bonus for consecutive character matches.
        static let bonusConsecutive: Double = 4.0
    }

    // MARK: - Public API

    /// Performs fuzzy matching of a query against a target string.
    ///
    /// The algorithm requires all query characters to be present in the target
    /// in the same order. Characters can be skipped in the target (fuzzy match),
    /// but all query characters must match exactly.
    ///
    /// - Parameters:
    ///   - query: The search string (what the user typed)
    ///   - target: The string to search within (e.g., a project name)
    /// - Returns: A `FuzzyMatch` if all query chars are found in order, otherwise `nil`
    static func match(_ query: String, in target: String) -> FuzzyMatch? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return FuzzyMatch(score: 1.0, matchedIndices: [])
        }

        let groups = parseQuery(trimmedQuery)
        var bestMatch: FuzzyMatch?

        for group in groups {
            if let match = matchGroup(group, target: target) {
                if bestMatch == nil || match.score > bestMatch!.score {
                    bestMatch = match
                }
            }
        }

        return bestMatch
    }

    /// Creates highlighted text with matched characters styled distinctly.
    ///
    /// Matched characters are rendered with bold weight and underline.
    ///
    /// - Parameters:
    ///   - text: The full text to render
    ///   - matchedIndices: Indices of characters to highlight
    ///   - baseFont: The base font to use
    ///   - baseColor: The base text color
    ///   - matchColor: The color for matched characters
    ///   - matchWeight: The font weight for matched characters (default: .bold)
    /// - Returns: A `Text` view with styled highlighting
    static func highlightedText(
        _ text: String,
        matchedIndices: [Int],
        baseFont: Font,
        baseColor: Color,
        matchColor: Color,
        matchWeight: Font.Weight = .bold
    ) -> Text {
        let matchSet = Set(matchedIndices)
        var result = Text("")

        for (index, char) in text.enumerated() {
            let charText = Text(String(char))
                .font(baseFont)

            if matchSet.contains(index) {
                // Matched character: bold + underline + match color
                // swiftlint:disable:next shorthand_operator
                result = result + charText
                    .fontWeight(matchWeight)
                    .underline()
                    .foregroundColor(matchColor)
            } else {
                // Normal character: base styling
                // swiftlint:disable:next shorthand_operator
                result = result + charText
                    .foregroundColor(baseColor)
            }
        }

        return result
    }

    // MARK: - Phase 1: Subsequence Check

    /// Checks if all query characters exist in target in order.
    ///
    /// This is a fast O(n+m) check that determines if a match is possible
    /// before running the more expensive scoring algorithm.
    ///
    /// - Parameters:
    ///   - query: The search string
    ///   - target: The string to search within
    /// - Returns: `true` if all query chars found in order, `false` otherwise
    private static func hasSubsequence(_ query: String, in target: String) -> Bool {
        let queryChars = Array(query.lowercased())
        let targetChars = Array(target.lowercased())

        var queryIndex = 0

        for targetChar in targetChars {
            guard queryIndex < queryChars.count else { break }

            if targetChar == queryChars[queryIndex] {
                queryIndex += 1
            }
        }

        return queryIndex == queryChars.count
    }

    // MARK: - Phase 2: Optimal Score Calculation

    // swiftlint:disable cyclomatic_complexity
    /// Calculates the optimal match score and positions using dynamic programming.
    ///
    /// This implements a simplified version of the fzy algorithm that finds
    /// the best positions to match each query character, maximizing bonuses
    /// for consecutive matches, word boundaries, and early positions.
    ///
    /// - Parameters:
    ///   - query: The search string
    ///   - target: The string to search within
    /// - Returns: Tuple of (raw score, best match indices)
    private static func calculateOptimalMatch(query: String, target: String) -> (Double, [Int]) {
        let queryChars = Array(query.lowercased())
        let targetLower = Array(target.lowercased())
        let targetOriginal = Array(target)

        let n = queryChars.count
        let m = targetLower.count

        // Edge case: both empty or query longer than target
        if n == 0 { return (0, []) }
        if m == 0 { return (-.infinity, []) }
        if n > m { return (-.infinity, []) }

        // DP table: score[i][j] = best score matching query[0..<i] ending at target[j-1]
        // We use 1-based indexing for cleaner boundary handling
        var score = [[Double]](repeating: [Double](repeating: -.infinity, count: m + 1), count: n + 1)

        // consecutive[i][j] = score if query[i-1] matched target[j-1] AND was consecutive
        var consecutive = [[Double]](repeating: [Double](repeating: -.infinity, count: m + 1), count: n + 1)

        // Track which target position gave best score for backtracking
        var bestEndPos = [[Int]](repeating: [Int](repeating: -1, count: m + 1), count: n + 1)

        // Base case: matching 0 query characters
        score[0][0] = 0
        for j in 1 ... m {
            score[0][j] = 0 // Can skip any prefix of target
        }

        // Fill DP table
        for i in 1 ... n {
            let queryChar = queryChars[i - 1]

            for j in 1 ... m {
                let targetChar = targetLower[j - 1]

                // Option 1: Don't match target[j-1], carry forward best score
                if score[i][j - 1] > score[i][j] {
                    score[i][j] = score[i][j - 1]
                    bestEndPos[i][j] = bestEndPos[i][j - 1]
                }

                // Option 2: Match query[i-1] with target[j-1] (if chars match)
                guard queryChar == targetChar else { continue }

                // Calculate bonus for this position
                var bonus = Score.match

                // First character bonus
                if j == 1 {
                    bonus += Score.bonusFirstChar
                } else {
                    // Word boundary bonus
                    if isBoundaryChar(targetOriginal[j - 2]) {
                        bonus += Score.bonusBoundary
                    }
                    // CamelCase bonus
                    else if targetOriginal[j - 2].isLowercase, targetOriginal[j - 1].isUppercase {
                        bonus += Score.bonusCamel
                    }
                }

                // Calculate score from previous state
                var matchScore: Double
                var isConsecutive = false

                if i == 1 {
                    // First query char: start fresh
                    matchScore = bonus
                    // Add gap penalty for skipped target prefix
                    if j > 1 {
                        matchScore += Score.gapStart + Score.gapExtend * Double(j - 2)
                    }
                } else {
                    // Subsequent query chars: best of consecutive or gap
                    let gapScore = score[i - 1][j - 1] + bonus
                    let consScore = consecutive[i - 1][j - 1] + bonus + Score.bonusConsecutive

                    if consScore >= gapScore, consecutive[i - 1][j - 1] > -.infinity {
                        matchScore = consScore
                        isConsecutive = true
                    } else if score[i - 1][j - 1] > -.infinity {
                        matchScore = gapScore
                    } else {
                        continue // No valid previous state
                    }
                }

                // Update if this is better
                if matchScore > score[i][j] {
                    score[i][j] = matchScore
                    bestEndPos[i][j] = j - 1 // 0-based index
                    consecutive[i][j] = matchScore
                } else {
                    consecutive[i][j] = -.infinity
                }

                _ = isConsecutive // Silence unused variable warning
            }
        }

        // Find best final score (can end at any position in target)
        var bestScore: Double = -.infinity
        var endJ = m

        for j in n ... m {
            if score[n][j] > bestScore {
                bestScore = score[n][j]
                endJ = j
            }
        }

        // Backtrack to find matched indices
        let indices = backtrack(
            score: score,
            bestEndPos: bestEndPos,
            n: n,
            endJ: endJ,
            queryChars: queryChars,
            targetLower: targetLower
        )

        return (bestScore, indices)
    }

    // swiftlint:enable cyclomatic_complexity

    // swiftlint:disable function_parameter_count
    /// Backtracks through the DP table to find the actual matched indices.
    private static func backtrack(
        score _: [[Double]],
        bestEndPos: [[Int]],
        n: Int,
        endJ: Int,
        queryChars: [Character],
        targetLower: [Character]
    ) -> [Int] {
        var indices = [Int]()
        var i = n
        var j = endJ

        while i > 0, j > 0 {
            let pos = bestEndPos[i][j]
            if pos >= 0, targetLower[pos] == queryChars[i - 1] {
                indices.append(pos)
                i -= 1
                j = pos // Move to position before this match
            } else {
                j -= 1
            }
        }

        return indices.reversed()
    }

    // swiftlint:enable function_parameter_count

    // MARK: - Helper Functions

    /// Checks if a character is a word boundary character.
    private static func isBoundaryChar(_ char: Character) -> Bool {
        char == "/" || char == " " || char == "_" || char == "-" || char == "."
    }

    /// Normalizes the raw score to a 0.0-1.0 range.
    ///
    /// The normalization considers:
    /// - Query length (longer queries can accumulate more points)
    /// - Target length (longer targets may have more gap penalties)
    /// - Maximum possible score (all consecutive, all bonuses)
    private static func normalizeScore(_ rawScore: Double, queryLength: Int, targetLength: Int) -> Double {
        guard queryLength > 0 else { return 1.0 }
        guard rawScore > -.infinity else { return 0.0 }

        // Calculate maximum possible score
        // Best case: all chars consecutive at start with first char bonus
        let maxScore = Score.match * Double(queryLength)
            + Score.bonusFirstChar
            + Score.bonusConsecutive * Double(max(0, queryLength - 1))

        // Calculate minimum expected score (all chars match with gaps)
        let minScore = Score.match * Double(queryLength)
            + Score.gapStart * Double(queryLength)
            + Score.gapExtend * Double(max(0, targetLength - queryLength))

        // Normalize to 0.0-1.0 range
        let range = maxScore - minScore
        guard range > 0 else { return rawScore > 0 ? 1.0 : 0.0 }

        let normalized = (rawScore - minScore) / range
        return max(0.0, min(1.0, normalized))
    }

    // MARK: - fzf Query Parsing

    private static func parseQuery(_ query: String) -> [[QueryToken]] {
        let rawTokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        var groups: [[QueryToken]] = []
        var currentGroup: [QueryToken] = []

        for raw in rawTokens {
            if raw == "|" {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                    currentGroup = []
                }
                continue
            }
            if let token = parseToken(raw) {
                currentGroup.append(token)
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups.isEmpty ? [[]] : groups
    }

    private static func parseToken(_ raw: String) -> QueryToken? {
        var token = raw
        var isInverse = false

        if token.hasPrefix("!") {
            isInverse = true
            token.removeFirst()
        }

        guard !token.isEmpty else { return nil }

        var mode: MatchMode = .fuzzy
        let isQuoted = token.hasPrefix("'")

        if isQuoted {
            token.removeFirst()
            if token.hasSuffix("'") {
                token.removeLast()
                mode = .boundary
            } else {
                mode = .exact
            }
        } else {
            let hasPrefixCaret = token.hasPrefix("^")
            let hasSuffixDollar = token.hasSuffix("$")

            if hasPrefixCaret {
                token.removeFirst()
            }
            if hasSuffixDollar, !token.isEmpty {
                token.removeLast()
            }

            if hasPrefixCaret, hasSuffixDollar {
                mode = .exact
            } else if hasPrefixCaret {
                mode = .prefix
            } else if hasSuffixDollar {
                mode = .suffix
            }
        }

        guard !token.isEmpty else { return nil }
        return QueryToken(pattern: token, mode: mode, isInverse: isInverse)
    }

    // MARK: - Matching

    private static func matchGroup(_ tokens: [QueryToken], target: String) -> FuzzyMatch? {
        var matchedIndices = Set<Int>()
        var positiveScores: [Double] = []

        for token in tokens {
            let result = matchToken(token, target: target)

            if token.isInverse {
                if result != nil {
                    return nil
                }
                continue
            }

            guard let match = result else { return nil }
            positiveScores.append(match.score)
            for index in match.matchedIndices {
                matchedIndices.insert(index)
            }
        }

        let score: Double = if positiveScores.isEmpty {
            1.0
        } else {
            min(1.0, positiveScores.reduce(0.0, +) / Double(positiveScores.count))
        }

        return FuzzyMatch(score: score, matchedIndices: matchedIndices.sorted())
    }

    private static func matchToken(_ token: QueryToken, target: String) -> FuzzyMatch? {
        switch token.mode {
        case .fuzzy:
            fuzzyMatch(token.pattern, in: target)
        case .exact:
            exactMatch(token.pattern, in: target)
        case .prefix:
            prefixMatch(token.pattern, in: target)
        case .suffix:
            suffixMatch(token.pattern, in: target)
        case .boundary:
            boundaryMatch(token.pattern, in: target)
        }
    }

    private static func fuzzyMatch(_ query: String, in target: String) -> FuzzyMatch? {
        guard hasSubsequence(query, in: target) else {
            return nil
        }

        let (score, indices) = calculateOptimalMatch(query: query, target: target)
        let normalizedScore = normalizeScore(score, queryLength: query.count, targetLength: target.count)
        return FuzzyMatch(score: normalizedScore, matchedIndices: indices)
    }

    private static func exactMatch(_ pattern: String, in target: String) -> FuzzyMatch? {
        let targetLower = target.lowercased()
        let patternLower = pattern.lowercased()
        guard let range = targetLower.range(of: patternLower) else { return nil }
        let startIndex = targetLower.distance(from: targetLower.startIndex, to: range.lowerBound)
        let indices = Array(startIndex ..< startIndex + patternLower.count)
        return FuzzyMatch(score: exactScore(pattern: pattern, target: target), matchedIndices: indices)
    }

    private static func prefixMatch(_ pattern: String, in target: String) -> FuzzyMatch? {
        let targetLower = target.lowercased()
        let patternLower = pattern.lowercased()
        guard targetLower.hasPrefix(patternLower) else { return nil }
        let indices = Array(0 ..< patternLower.count)
        return FuzzyMatch(score: min(1.0, exactScore(pattern: pattern, target: target) + 0.1), matchedIndices: indices)
    }

    private static func suffixMatch(_ pattern: String, in target: String) -> FuzzyMatch? {
        let targetLower = target.lowercased()
        let patternLower = pattern.lowercased()
        guard targetLower.hasSuffix(patternLower) else { return nil }
        let startIndex = max(0, targetLower.count - patternLower.count)
        let indices = Array(startIndex ..< startIndex + patternLower.count)
        return FuzzyMatch(score: min(1.0, exactScore(pattern: pattern, target: target) + 0.1), matchedIndices: indices)
    }

    private static func boundaryMatch(_ pattern: String, in target: String) -> FuzzyMatch? {
        let targetLower = Array(target.lowercased())
        let targetChars = Array(target)
        let patternLower = Array(pattern.lowercased())
        guard !patternLower.isEmpty else { return nil }

        let targetCount = targetLower.count
        let patternCount = patternLower.count
        guard patternCount <= targetCount else { return nil }

        for start in 0 ... (targetCount - patternCount) {
            let slice = targetLower[start ..< start + patternCount]
            if slice.elementsEqual(patternLower) {
                let beforeIndex = start - 1
                let afterIndex = start + patternCount
                let beforeBoundary = beforeIndex < 0 || isBoundaryChar(targetChars[beforeIndex])
                let afterBoundary = afterIndex >= targetCount || isBoundaryChar(targetChars[afterIndex])
                if beforeBoundary, afterBoundary {
                    let indices = Array(start ..< start + patternCount)
                    return FuzzyMatch(
                        score: min(1.0, exactScore(pattern: pattern, target: target) + 0.05),
                        matchedIndices: indices
                    )
                }
            }
        }

        return nil
    }

    private static func exactScore(pattern: String, target: String) -> Double {
        let targetLength = max(1, target.count)
        return min(1.0, Double(pattern.count) / Double(targetLength))
    }
}
