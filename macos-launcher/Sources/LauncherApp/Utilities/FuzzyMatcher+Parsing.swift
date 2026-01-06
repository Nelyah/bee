import Foundation

extension FuzzyMatcher {
    // MARK: - Pattern Parsing

    static func buildPattern(from query: String) -> Pattern {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Pattern(termSets: [], isEmpty: true)
        }

        let termSets = parseTerms(trimmed)
        return Pattern(termSets: termSets, isEmpty: termSets.isEmpty)
    }

    static func trimmedQueryString(_ query: String) -> String {
        var str = query
        str = str.replacingOccurrences(of: "\\ ", with: "\t")
        str = str.trimmingCharacters(in: .whitespaces)
        while str.hasSuffix(" ") && !str.hasSuffix("\\ ") {
            str.removeLast()
        }
        return str.replacingOccurrences(of: "\t", with: " ")
    }

    static func parseTerms(_ input: String) -> [TermSet] {
        let str = input.replacingOccurrences(of: "\\ ", with: "\t")
        let tokens = str.split(whereSeparator: { $0 == " " }).map {
            String($0).replacingOccurrences(of: "\t", with: " ")
        }

        var sets: [TermSet] = []
        var set: TermSet = []
        var switchSet = false
        var afterBar = false

        for rawToken in tokens {
            let token = rawToken
            if !set.isEmpty && !afterBar && token == "|" {
                switchSet = false
                afterBar = true
                continue
            }
            afterBar = false

            let lowerToken = token.lowercased()
            let caseSensitive = false
            var normalizedToken = lowerToken

            let normalizeTerm = shouldNormalize(lowerToken: lowerToken)

            var isInverse = false
            var termType: TermType = .fuzzy

            if normalizedToken.hasPrefix("!") {
                isInverse = true
                termType = .exact
                normalizedToken.removeFirst()
            }

            if normalizedToken != "$", normalizedToken.hasSuffix("$") {
                termType = .suffix
                normalizedToken.removeLast()
            }

            if normalizedToken.count > 2,
               normalizedToken.hasPrefix("'"),
               normalizedToken.hasSuffix("'") {
                termType = .exactBoundary
                normalizedToken.removeFirst()
                normalizedToken.removeLast()
            } else if normalizedToken.hasPrefix("'") {
                if !isInverse {
                    termType = .exact
                } else {
                    termType = .fuzzy
                }
                normalizedToken.removeFirst()
            } else if normalizedToken.hasPrefix("^") {
                if termType == .suffix {
                    termType = .equal
                } else {
                    termType = .prefix
                }
                normalizedToken.removeFirst()
            }

            guard !normalizedToken.isEmpty else { continue }

            if switchSet {
                sets.append(set)
                set = []
            }

            var scalars = Array(normalizedToken.unicodeScalars).map { $0.value }
            if normalizeTerm {
                scalars = normalizeScalars(scalars)
            }

            set.append(Term(
                type: termType,
                isInverse: isInverse,
                text: scalars,
                caseSensitive: caseSensitive,
                normalize: normalizeTerm
            ))
            switchSet = true
        }

        if !set.isEmpty {
            sets.append(set)
        }

        return sets
    }

    static func shouldNormalize(lowerToken: String) -> Bool {
        let normalized = String(
            String.UnicodeScalarView(
                normalizeScalars(Array(lowerToken.unicodeScalars).map { $0.value })
                    .compactMap { UnicodeScalar($0) }
            )
        )
        return lowerToken == normalized
    }
}
