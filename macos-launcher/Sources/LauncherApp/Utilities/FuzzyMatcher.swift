import Foundation
import SwiftUI

/// Represents a fuzzy match result with score and matched character positions.
struct FuzzyMatch {
    /// Match quality score (0.0-1.0, where 1.0 is perfect match).
    let score: Double

    /// Indices of characters in the target string that matched the query.
    let matchedIndices: [Int]
}

/// Provides fuzzy string matching and highlighting capabilities.
enum FuzzyMatcher {
    /// Performs fuzzy matching of a query against a target string.
    ///
    /// Scoring factors:
    /// - Consecutive character matches (higher weight)
    /// - Early matches in the string (higher weight)
    /// - Match density (percentage of query characters found)
    ///
    /// - Parameters:
    ///   - query: The search string
    ///   - target: The string to search within
    /// - Returns: A `FuzzyMatch` if the query matches, otherwise `nil`
    static func match(_ query: String, in target: String) -> FuzzyMatch? {
        guard !query.isEmpty else {
            // Empty query matches everything with perfect score
            return FuzzyMatch(score: 1.0, matchedIndices: [])
        }

        let queryChars = Array(query.lowercased())
        let targetChars = Array(target.lowercased())

        var matchedIndices: [Int] = []
        var queryIndex = 0

        // Find all query characters in target (in order)
        for (targetIndex, targetChar) in targetChars.enumerated() {
            guard queryIndex < queryChars.count else { break }

            if targetChar == queryChars[queryIndex] {
                matchedIndices.append(targetIndex)
                queryIndex += 1
            }
        }

        // If not all query characters were found, no match
        guard queryIndex == queryChars.count else {
            return nil
        }

        // Calculate score based on multiple factors
        let score = calculateScore(
            matchedIndices: matchedIndices,
            targetLength: targetChars.count,
            queryLength: queryChars.count
        )

        // Reject poor matches (less than 40% quality)
        guard score >= 0.4 else {
            return nil
        }

        return FuzzyMatch(score: score, matchedIndices: matchedIndices)
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
                result += charText
                    .fontWeight(matchWeight)
                    .underline()
                    .foregroundColor(matchColor)
            } else {
                // Normal character: base styling
                result += charText
                    .foregroundColor(baseColor)
            }
        }

        return result
    }

    // MARK: - Private Helpers

    /// Calculates a fuzzy match score based on match quality.
    ///
    /// Factors:
    /// - **Consecutive bonus:** Consecutive matches score higher
    /// - **Early position bonus:** Matches at the start of the string score higher
    /// - **Match density:** Higher percentage of characters matched scores higher
    private static func calculateScore(
        matchedIndices: [Int],
        targetLength: Int,
        queryLength: Int
    ) -> Double {
        guard !matchedIndices.isEmpty else { return 0.0 }

        var score = 0.0

        // Base score: match density (0.0-0.4)
        let density = Double(queryLength) / Double(targetLength)
        score += density * 0.4

        // Consecutive match bonus (0.0-0.3)
        var consecutiveCount = 0
        for i in 0 ..< matchedIndices.count - 1 {
            if matchedIndices[i + 1] == matchedIndices[i] + 1 {
                consecutiveCount += 1
            }
        }
        let consecutiveRatio = Double(consecutiveCount) / Double(max(1, queryLength - 1))
        score += consecutiveRatio * 0.3

        // Early position bonus (0.0-0.3)
        // First match position affects score (earlier is better)
        let firstMatchPos = Double(matchedIndices.first ?? 0)
        let earlyBonus = max(0, 1.0 - (firstMatchPos / Double(targetLength)))
        score += earlyBonus * 0.3

        return min(1.0, max(0.0, score))
    }
}
