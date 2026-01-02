import Foundation
import SwiftUI

/// Represents a fuzzy match result with score and matched character positions.
struct FuzzyMatch {
    /// Match quality score (0.0-1.0, where 1.0 is perfect match).
    let score: Double

    /// Indices of characters in the target string that matched the query.
    let matchedIndices: [Int]
}

/// Provides fuzzy string matching using the fzy algorithm.
///
/// The fzy algorithm is a battle-tested fuzzy matching algorithm used by
/// command-line fuzzy finders like fzy and fzf. It uses a two-phase approach:
///
/// 1. **Matching Phase**: Determines if all query characters exist in the
///    target string in order (case-insensitive). If any character is missing
///    or out of order, there's no match.
///
/// 2. **Scoring Phase**: Uses dynamic programming to find the optimal positions
///    for matched characters, maximizing the score based on:
///    - Consecutive character matches (biggest bonus)
///    - Matches at word boundaries (/, space, _, -, .)
///    - CamelCase transitions
///    - Matches at the start of the string
///
/// Reference: https://github.com/jhawthorn/fzy/blob/master/ALGORITHM.md
enum FuzzyMatcher {
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
        // Empty query matches everything with perfect score
        guard !query.isEmpty else {
            return FuzzyMatch(score: 1.0, matchedIndices: [])
        }

        // Phase 1: Check if all query characters exist in target (in order)
        guard hasSubsequence(query, in: target) else {
            return nil
        }

        // Phase 2: Calculate optimal score using dynamic programming
        let (score, indices) = calculateOptimalMatch(query: query, target: target)

        // Normalize score to 0.0-1.0 range
        let normalizedScore = normalizeScore(score, queryLength: query.count, targetLength: target.count)

        return FuzzyMatch(score: normalizedScore, matchedIndices: indices)
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
}
