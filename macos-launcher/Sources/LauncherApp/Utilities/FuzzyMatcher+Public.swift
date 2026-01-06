import SwiftUI

extension FuzzyMatcher {
    // MARK: - Public API

    static func match(_ query: String, in target: String) -> FuzzyMatch? {
        initializeIfNeeded()

        let trimmedQuery = trimmedQueryString(query)
        guard !trimmedQuery.isEmpty else {
            return FuzzyMatch(score: 1.0, matchedIndices: [])
        }

        let pattern = buildPattern(from: trimmedQuery)
        let input = ScalarChars(target)

        if pattern.isEmpty {
            return FuzzyMatch(score: 1.0, matchedIndices: [])
        }

        return matchExtended(pattern: pattern, input: input)
    }

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
                // swiftlint:disable:next shorthand_operator
                result = result + charText
                    .fontWeight(matchWeight)
                    .underline()
                    .foregroundColor(matchColor)
            } else {
                // swiftlint:disable:next shorthand_operator
                result = result + charText
                    .foregroundColor(baseColor)
            }
        }

        return result
    }
}
