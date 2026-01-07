@testable import LauncherApp
import SwiftUI
import XCTest

/// Comprehensive unit tests for the FuzzyMatcher algorithm.
///
/// These tests verify fzf-style query parsing and matching behavior, covering:
/// - Basic matching behavior (match vs no-match)
/// - Scoring accuracy and relative rankings
/// - Edge cases and boundary conditions
/// - Regression tests for previously reported bugs
/// - Performance characteristics
final class FuzzyMatcherTests: XCTestCase {
    // MARK: - A. Basic Matching Tests (Should MATCH)

    func testExactMatch() {
        let result = FuzzyMatcher.match("hobby", in: "hobby")
        XCTAssertNotNil(result, "Exact match should succeed")
        XCTAssertEqual(result?.matchedIndices, [0, 1, 2, 3, 4], "All indices should match")
    }

    func testPrefixMatch() {
        let result = FuzzyMatcher.match("ho", in: "hobby")
        XCTAssertNotNil(result, "Prefix match should succeed")
        XCTAssertEqual(result?.matchedIndices, [0, 1], "First two chars should match")
    }

    func testSuffixMatch() {
        let result = FuzzyMatcher.match("by", in: "hobby")
        XCTAssertNotNil(result, "Suffix match should succeed")
        // The matcher may pick the first 'b' at index 2 or consecutive 'b' at index 3.
        // Both are valid fuzzy matches - the algorithm optimizes for best score.
        XCTAssertEqual(result?.matchedIndices.count, 2, "Should have 2 matched chars")
        XCTAssertEqual(result?.matchedIndices.last, 4, "'y' should match at index 4")
    }

    func testSubsequenceMatch() {
        let result = FuzzyMatcher.match("hby", in: "hobby")
        XCTAssertNotNil(result, "'hby' should match 'hobby' (h-o-b-b-y with gaps)")
    }

    func testCaseInsensitiveMatch() {
        let result1 = FuzzyMatcher.match("HO", in: "hobby")
        XCTAssertNotNil(result1, "Uppercase query should match lowercase target")

        let result2 = FuzzyMatcher.match("ho", in: "HOBBY")
        XCTAssertNotNil(result2, "Lowercase query should match uppercase target")

        let result3 = FuzzyMatcher.match("HoBbY", in: "hObBy")
        XCTAssertNotNil(result3, "Mixed case should match")
    }

    func testEmptyQueryMatchesAll() {
        let result1 = FuzzyMatcher.match("", in: "hobby")
        XCTAssertNotNil(result1, "Empty query should match any target")
        XCTAssertEqual(result1?.score, 1.0, "Empty query should have perfect score")
        XCTAssertEqual(result1?.matchedIndices, [], "Empty query has no matched indices")

        let result2 = FuzzyMatcher.match("", in: "")
        XCTAssertNotNil(result2, "Empty query should match empty target")
    }

    // MARK: - A. Basic Matching Tests (Should NOT MATCH)

    func testMissingCharNoMatch() {
        let result = FuzzyMatcher.match("xyz", in: "hobby")
        XCTAssertNil(result, "Query with chars not in target should not match")
    }

    func testPartialMissingCharNoMatch() {
        let result = FuzzyMatcher.match("hox", in: "hobby")
        XCTAssertNil(result, "Query with some chars not in target should not match")
    }

    func testWrongOrderNoMatch() {
        let result = FuzzyMatcher.match("oh", in: "hobby")
        XCTAssertNil(result, "'oh' should not match 'hobby' - 'o' comes after 'h'")
    }

    func testExtraCharNoMatch() {
        let result = FuzzyMatcher.match("hobbyz", in: "hobby")
        XCTAssertNil(result, "Query longer than target with extra char should not match")
    }

    func testQueryLongerThanTargetNoMatch() {
        let result = FuzzyMatcher.match("hobbies", in: "hobby")
        XCTAssertNil(result, "Query longer than target should not match")
    }

    // MARK: - A. fzf Query Syntax

    func testExactMatchWithQuote() {
        let result = FuzzyMatcher.match("'wild", in: "wild west")
        XCTAssertNotNil(result, "Quoted query should match exact substring")
        let prefixIndices = Array(result?.matchedIndices.prefix(4) ?? [])
        XCTAssertEqual(prefixIndices, [0, 1, 2, 3], "Should match 'wild' at start")
    }

    func testExactMatchWithQuoteIsCaseInsensitive() {
        let result = FuzzyMatcher.match("'FoO", in: "foo bar")
        XCTAssertNotNil(result, "Quoted exact match should be case-insensitive")
    }

    func testBoundaryExactMatch() {
        let boundaryMatch = FuzzyMatcher.match("'wild'", in: "wild west")
        XCTAssertNotNil(boundaryMatch, "Boundary match should match full word")

        let noBoundaryMatch = FuzzyMatcher.match("'wild'", in: "wilderness")
        XCTAssertNil(noBoundaryMatch, "Boundary match should not match inside a word")
    }

    func testPrefixMatchWithCaret() {
        let result = FuzzyMatcher.match("^music", in: "music.mp3")
        XCTAssertNotNil(result, "Prefix match should match at start")

        let noMatch = FuzzyMatcher.match("^music", in: "amusic.mp3")
        XCTAssertNil(noMatch, "Prefix match should not match mid-string")
    }

    func testSuffixMatchWithDollar() {
        let result = FuzzyMatcher.match(".mp3$", in: "song.mp3")
        XCTAssertNotNil(result, "Suffix match should match at end")

        let noMatch = FuzzyMatcher.match(".mp3$", in: "song.mp3.bak")
        XCTAssertNil(noMatch, "Suffix match should not match with extra suffix")
    }

    func testInverseMatch() {
        let match = FuzzyMatcher.match("!fire", in: "water.txt")
        XCTAssertNotNil(match, "Inverse term should allow non-matching target")

        let noMatch = FuzzyMatcher.match("!fire", in: "fire.txt")
        XCTAssertNil(noMatch, "Inverse term should exclude matching target")
    }

    func testInverseOnlyAllowsNonMatchingTargets() {
        let match = FuzzyMatcher.match("!foo", in: "bar")
        XCTAssertNotNil(match, "Inverse-only query should match non-containing targets")
    }

    func testOrGroupMatches() {
        let result = FuzzyMatcher.match("^core go$ | rb$ | py$", in: "core.go")
        XCTAssertNotNil(result, "OR group should match one of the alternatives")

        let noMatch = FuzzyMatcher.match("^core go$ | rb$ | py$", in: "core.rs")
        XCTAssertNil(noMatch, "OR group should reject non-matching alternatives")
    }

    func testSimpleOrGroup() {
        let match = FuzzyMatcher.match("foo | bar", in: "bar baz")
        XCTAssertNotNil(match, "Simple OR group should match either term")
    }

    func testAndTermsAllRequired() {
        let match = FuzzyMatcher.match("foo bar", in: "bar foo")
        XCTAssertNotNil(match, "All terms should be required (order-independent)")

        let noMatch = FuzzyMatcher.match("foo bar", in: "only foo")
        XCTAssertNil(noMatch, "Missing term should fail the match")
    }

    func testOrGroupWithAndTerms() {
        let match = FuzzyMatcher.match("foo | bar baz", in: "bar baz qux")
        XCTAssertNotNil(match, "OR group should allow the AND pair to match")

        let noMatch = FuzzyMatcher.match("foo | bar baz", in: "bar only")
        XCTAssertNil(noMatch, "AND pair should fail if one term is missing")
    }

    func testInverseWithPositiveTerm() {
        let match = FuzzyMatcher.match("foo !bar", in: "foo baz")
        XCTAssertNotNil(match, "Inverse term should exclude targets containing it")

        let noMatch = FuzzyMatcher.match("foo !bar", in: "foo bar")
        XCTAssertNil(noMatch, "Inverse term should exclude matching targets")
    }

    func testInverseExactTermExcludesSubstring() {
        let noMatch = FuzzyMatcher.match("!foo", in: "food")
        XCTAssertNil(noMatch, "Inverse exact term should exclude substring matches")
    }

    func testExactBoundaryWithPunctuation() {
        let match = FuzzyMatcher.match("'foo'", in: "foo,bar")
        XCTAssertNotNil(match, "Boundary exact should match punctuation-separated words")

        let noMatch = FuzzyMatcher.match("'foo'", in: "foobar")
        XCTAssertNil(noMatch, "Boundary exact should not match inside word")
    }

    func testEscapedSpaceMatchesLiteralSpace() {
        let match = FuzzyMatcher.match("foo\\ bar", in: "foo bar")
        XCTAssertNotNil(match, "Escaped space should be treated as literal")
    }

    func testTrailingSpacesAreTrimmed() {
        let match = FuzzyMatcher.match("foo   ", in: "foo")
        XCTAssertNotNil(match, "Trailing spaces in query should be trimmed")
    }

    func testPrefixIgnoresLeadingWhitespace() {
        let match = FuzzyMatcher.match("^foo", in: "   foo")
        XCTAssertNotNil(match, "Prefix match should skip leading whitespace")
    }

    func testSuffixIgnoresTrailingWhitespace() {
        let match = FuzzyMatcher.match("foo$", in: "foo   ")
        XCTAssertNotNil(match, "Suffix match should skip trailing whitespace")
    }

    func testEqualMatchIgnoresOuterWhitespace() {
        let match = FuzzyMatcher.match("^foo$", in: "  foo  ")
        XCTAssertNotNil(match, "Equal match should ignore outer whitespace")

        let noMatch = FuzzyMatcher.match("^foo$", in: "  foo bar  ")
        XCTAssertNil(noMatch, "Equal match should require full trimmed equality")
    }

    func testNormalizedMatchesAccents() {
        let match = FuzzyMatcher.match("cafe", in: "café")
        XCTAssertNotNil(match, "Normalized query should match accented target")
    }

    func testNormalizedMatchesMultipleAccents() {
        let match = FuzzyMatcher.match("resume", in: "résumé")
        XCTAssertNotNil(match, "Normalized query should match multiple accents")
    }

    func testEmojiScalarMapping() {
        let result = FuzzyMatcher.match("ab", in: "a😊b")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchedIndices, [0, 2], "Indices should map to character positions")
    }

    func testMultipleTermsOrderIndependent() {
        let match = FuzzyMatcher.match("bar foo", in: "foo ... bar")
        XCTAssertNotNil(match, "Term order should not matter")
    }

    // MARK: - B. Scoring Tests (Relative Rankings)

    func testExactMatchScoresHighest() {
        let exact = FuzzyMatcher.match("hobby", in: "hobby")
        let partial = FuzzyMatcher.match("hob", in: "hobby")

        XCTAssertNotNil(exact)
        XCTAssertNotNil(partial)
        XCTAssertGreaterThanOrEqual(
            exact!.score, partial!.score,
            "Exact match should score higher or equal to partial match"
        )
    }

    func testPrefixScoresBetterThanMiddle() {
        let prefix = FuzzyMatcher.match("ho", in: "hobby")
        let middle = FuzzyMatcher.match("ho", in: "xxxhobby")

        XCTAssertNotNil(prefix)
        XCTAssertNotNil(middle)
        XCTAssertGreaterThan(
            prefix!.score, middle!.score,
            "Prefix match should score higher than match in middle"
        )
    }

    func testConsecutiveScoresBetter() {
        let consecutive = FuzzyMatcher.match("abc", in: "abc")
        let gapped = FuzzyMatcher.match("abc", in: "aXbXc")

        XCTAssertNotNil(consecutive)
        XCTAssertNotNil(gapped)
        XCTAssertGreaterThan(
            consecutive!.score, gapped!.score,
            "Consecutive matches should score higher than gapped matches"
        )
    }

    func testGapPenaltyPrefersTighterMatch() {
        let tight = FuzzyMatcher.match("ac", in: "abc")
        let loose = FuzzyMatcher.match("ac", in: "abbbbbc")

        XCTAssertNotNil(tight)
        XCTAssertNotNil(loose)
        XCTAssertGreaterThan(
            tight!.score, loose!.score,
            "Tighter gaps should score higher than loose gaps"
        )
    }

    func testBoundaryMatchesScoreBetter() {
        let boundary = FuzzyMatcher.match("fb", in: "foo_bar")
        let nonBoundary = FuzzyMatcher.match("fb", in: "foobar")

        XCTAssertNotNil(boundary)
        XCTAssertNotNil(nonBoundary)
        XCTAssertGreaterThan(
            boundary!.score, nonBoundary!.score,
            "Match after word boundary should score higher"
        )
    }

    func testCamelCaseBonus() {
        let camelCase = FuzzyMatcher.match("fb", in: "FooBar")
        let noCamel = FuzzyMatcher.match("fb", in: "foobar")

        XCTAssertNotNil(camelCase)
        XCTAssertNotNil(noCamel)
        XCTAssertGreaterThan(
            camelCase!.score, noCamel!.score,
            "CamelCase transition should get bonus"
        )
    }

    func testFirstCharBonus() {
        let firstChar = FuzzyMatcher.match("h", in: "hobby")
        let laterChar = FuzzyMatcher.match("o", in: "hobby")

        XCTAssertNotNil(firstChar)
        XCTAssertNotNil(laterChar)
        XCTAssertGreaterThan(
            firstChar!.score, laterChar!.score,
            "Match at first character should score higher"
        )
    }

    func testShorterTargetScoresBetter() {
        // Same query, shorter target should score higher or equal
        let short = FuzzyMatcher.match("bee", in: "bee")
        let long = FuzzyMatcher.match("bee", in: "beekeeper")

        XCTAssertNotNil(short)
        XCTAssertNotNil(long)
        XCTAssertGreaterThanOrEqual(
            short!.score, long!.score,
            "Shorter target with same match should score higher or equal"
        )
    }

    // MARK: - C. Edge Cases

    func testSingleCharQuery() {
        let result = FuzzyMatcher.match("h", in: "hobby")
        XCTAssertNotNil(result, "Single char query should match")
        XCTAssertEqual(result?.matchedIndices, [0])
    }

    func testSingleCharTarget() {
        let result = FuzzyMatcher.match("h", in: "h")
        XCTAssertNotNil(result, "Single char matching single char target should work")
        XCTAssertEqual(result?.matchedIndices, [0])
    }

    func testSingleCharNoMatch() {
        let result = FuzzyMatcher.match("x", in: "hobby")
        XCTAssertNil(result, "Single char not in target should not match")
    }

    func testVeryLongQuery() {
        let longQuery = String(repeating: "a", count: 50)
        let longTarget = String(repeating: "a", count: 100)

        let result = FuzzyMatcher.match(longQuery, in: longTarget)
        XCTAssertNotNil(result, "Long query matching long target should work")
        XCTAssertEqual(result?.matchedIndices.count, 50)
    }

    func testVeryLongTarget() {
        let query = "abc"
        let longTarget = String(repeating: "x", count: 500) + "abc"

        let result = FuzzyMatcher.match(query, in: longTarget)
        XCTAssertNotNil(result, "Query should match at end of long target")
    }

    func testSpecialCharacters() {
        // Underscore
        let underscore = FuzzyMatcher.match("fb", in: "foo_bar")
        XCTAssertNotNil(underscore)

        // Dash
        let dash = FuzzyMatcher.match("fb", in: "foo-bar")
        XCTAssertNotNil(dash)

        // Dot
        let dot = FuzzyMatcher.match("fb", in: "foo.bar")
        XCTAssertNotNil(dot)

        // Space
        let space = FuzzyMatcher.match("fb", in: "foo bar")
        XCTAssertNotNil(space)

        // Slash
        let slash = FuzzyMatcher.match("fb", in: "foo/bar")
        XCTAssertNotNil(slash)
    }

    func testUnicodeCharacters() {
        let result1 = FuzzyMatcher.match("café", in: "café")
        XCTAssertNotNil(result1, "Unicode characters should match")

        let result2 = FuzzyMatcher.match("日本", in: "日本語")
        XCTAssertNotNil(result2, "CJK characters should match")

        let result3 = FuzzyMatcher.match("emoji", in: "emoji")
        XCTAssertNotNil(result3, "Regular chars should still work")
    }

    func testRepeatedChars() {
        let result = FuzzyMatcher.match("bb", in: "bobbin")
        XCTAssertNotNil(result, "'bb' should match 'bobbin'")
        // Should find the consecutive 'bb' in bobbin
    }

    func testAllSameChar() {
        let result = FuzzyMatcher.match("aaa", in: "aaaaa")
        XCTAssertNotNil(result, "'aaa' should match 'aaaaa'")
        XCTAssertEqual(result?.matchedIndices.count, 3)
    }

    func testEmptyTarget() {
        let result = FuzzyMatcher.match("a", in: "")
        XCTAssertNil(result, "Non-empty query should not match empty target")
    }

    // MARK: - D. Regression Tests (Original Bugs)

    func testHoDoesNotMatchWork() {
        // This was the original bug - "ho" matched "work"
        let result = FuzzyMatcher.match("ho", in: "work")
        XCTAssertNil(result, "'ho' should NOT match 'work' - there is no 'h' in 'work'")
    }

    func testHobbMatchesHobby() {
        // This was the original bug - "hobb" didn't match "hobby"
        let result = FuzzyMatcher.match("hobb", in: "hobby")
        XCTAssertNotNil(result, "'hobb' should match 'hobby' - all chars are present in order")
    }

    func testTypoShouldNotMatch() {
        // "ho" should not match words without both 'h' and 'o' in that order
        XCTAssertNil(FuzzyMatcher.match("ho", in: "work"), "No 'h' in work")
        XCTAssertNil(FuzzyMatcher.match("ho", in: "only"), "No 'h' in only")
        XCTAssertNil(FuzzyMatcher.match("ab", in: "ba"), "Wrong order")
    }

    func testAllQueryCharsMustBePresent() {
        XCTAssertNil(FuzzyMatcher.match("hello", in: "helo"), "Missing one 'l'")
        XCTAssertNotNil(FuzzyMatcher.match("hello", in: "hello"), "All chars present")
        XCTAssertNotNil(FuzzyMatcher.match("hello", in: "hellooo"), "Extra chars at end OK")
    }

    // MARK: - E. Scoring Boundary Tests

    func testScoreIsFinite() {
        // Test various matches to ensure scores are finite
        let testCases = [
            ("a", "a"),
            ("abc", "abc"),
            ("a", "abcdefghijklmnop"),
            ("test", "this_is_a_test"),
            ("fb", "FooBar"),
        ]

        for (query, target) in testCases {
            if let result = FuzzyMatcher.match(query, in: target) {
                XCTAssertTrue(
                    result.score.isFinite,
                    "Score should be finite for '\(query)' in '\(target)'"
                )
            }
        }
    }

    func testExactMatchBeatsGappedMatch() {
        let exact = FuzzyMatcher.match("hobby", in: "hobby")
        let gapped = FuzzyMatcher.match("hobby", in: "h_o_b_b_y")
        XCTAssertNotNil(exact)
        XCTAssertNotNil(gapped)
        XCTAssertGreaterThan(
            exact!.score, gapped!.score,
            "Exact match should score higher than gapped match"
        )
    }

    // MARK: - F. MatchedIndices Tests

    func testMatchedIndicesAreCorrect() {
        let result = FuzzyMatcher.match("hby", in: "hobby")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchedIndices.count, 3, "Should have 3 matched indices")
        // h at 0, b at 2 or 3, y at 4
        XCTAssertEqual(result?.matchedIndices.first, 0, "First match should be 'h' at index 0")
        XCTAssertEqual(result?.matchedIndices.last, 4, "Last match should be 'y' at index 4")
    }

    func testMatchedIndicesPreferConsecutive() {
        // "ab" in "aXab" - algorithm finds valid matches
        // The greedy algorithm may find [0, 3] or [2, 3] depending on implementation
        let result = FuzzyMatcher.match("ab", in: "aXab")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchedIndices.count, 2, "Should have 2 matched chars")

        // Better test: consecutive match should score higher than gapped match
        let consecutive = FuzzyMatcher.match("ab", in: "ab")
        let gapped = FuzzyMatcher.match("ab", in: "aXb")
        XCTAssertNotNil(consecutive)
        XCTAssertNotNil(gapped)
        XCTAssertGreaterThan(
            consecutive!.score, gapped!.score,
            "Consecutive match should score higher than gapped match"
        )
    }

    func testMatchedIndicesAreAscending() {
        let result = FuzzyMatcher.match("abc", in: "aXXbXXc")
        XCTAssertNotNil(result)

        let indices = result!.matchedIndices
        for i in 1 ..< indices.count {
            XCTAssertLessThan(
                indices[i - 1], indices[i],
                "Matched indices should be in ascending order"
            )
        }
    }

    func testMatchedIndicesCountEqualsQueryLength() {
        let testCases = [
            ("a", "abc"),
            ("abc", "abcdef"),
            ("test", "testing"),
        ]

        for (query, target) in testCases {
            if let result = FuzzyMatcher.match(query, in: target) {
                XCTAssertEqual(
                    result.matchedIndices.count, query.count,
                    "Matched indices count should equal query length for '\(query)' in '\(target)'"
                )
            }
        }
    }
}
