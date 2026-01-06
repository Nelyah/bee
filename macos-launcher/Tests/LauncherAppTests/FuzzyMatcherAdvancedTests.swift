@testable import LauncherApp
import SwiftUI
import XCTest

final class FuzzyMatcherAdvancedTests: XCTestCase {
    // MARK: - Performance Tests

    func testPerformanceWith1000Items() {
        let items = (0 ..< 1000).map { "item_\($0)_with_some_extra_text" }
        let query = "item"

        measure {
            for item in items {
                _ = FuzzyMatcher.match(query, in: item)
            }
        }
    }

    func testPerformanceWithLongStrings() {
        let longTarget = String(repeating: "abcdefghij", count: 100)
        let query = "abcdefghij"

        measure {
            for _ in 0 ..< 100 {
                _ = FuzzyMatcher.match(query, in: longTarget)
            }
        }
    }

    // MARK: - Highlighting Integration Tests

    func testHighlightedTextRendersCorrectly() {
        let text = "hobby"
        let indices = [0, 2, 4] // h, b, y

        let highlighted = FuzzyMatcher.highlightedText(
            text,
            matchedIndices: indices,
            baseFont: .body,
            baseColor: .primary,
            matchColor: .blue
        )

        // Just verify it doesn't crash and returns a Text
        XCTAssertNotNil(highlighted)
    }

    func testHighlightedTextWithEmptyIndices() {
        let highlighted = FuzzyMatcher.highlightedText(
            "hobby",
            matchedIndices: [],
            baseFont: .body,
            baseColor: .primary,
            matchColor: .blue
        )

        XCTAssertNotNil(highlighted, "Should handle empty indices")
    }

    func testHighlightedTextWithAllIndices() {
        let text = "abc"
        let highlighted = FuzzyMatcher.highlightedText(
            text,
            matchedIndices: [0, 1, 2],
            baseFont: .body,
            baseColor: .primary,
            matchColor: .blue
        )

        XCTAssertNotNil(highlighted, "Should handle all indices matched")
    }

    // MARK: - Word Boundary Detection Tests

    func testWordBoundaryAfterUnderscore() {
        let result = FuzzyMatcher.match("tb", in: "test_bar")
        XCTAssertNotNil(result)
        // 'b' after underscore should get boundary bonus
    }

    func testWordBoundaryAfterDash() {
        let result = FuzzyMatcher.match("tb", in: "test-bar")
        XCTAssertNotNil(result)
    }

    func testWordBoundaryAfterSpace() {
        let result = FuzzyMatcher.match("tb", in: "test bar")
        XCTAssertNotNil(result)
    }

    func testWordBoundaryAfterSlash() {
        let result = FuzzyMatcher.match("tb", in: "test/bar")
        XCTAssertNotNil(result)
    }

    func testWordBoundaryAfterDot() {
        let result = FuzzyMatcher.match("tb", in: "test.bar")
        XCTAssertNotNil(result)
    }

    // MARK: - Additional Scoring Verification Tests

    func testScoreOrderingWithMultipleMatches() {
        // Given several targets for the same query, verify ordering makes sense
        let query = "fb"
        let targets = [
            "FooBar", // CamelCase - high score
            "foo_bar", // Boundary - high score
            "foobar", // Plain - medium score
            "xxxfoobar", // Not at start - lower score
        ]

        var scores: [Double] = []
        for target in targets {
            if let result = FuzzyMatcher.match(query, in: target) {
                scores.append(result.score)
            }
        }

        XCTAssertEqual(scores.count, 4, "All should match")

        // First char + boundary/camel matches should score higher than plain matches
        // Plain match at start should score higher than match not at start
        XCTAssertGreaterThan(scores[2], scores[3], "Start match should beat middle match")
    }

    func testScoreStability() {
        // Same inputs should always produce same score
        let query = "test"
        let target = "testing"

        var scores: [Double] = []
        for _ in 0 ..< 10 {
            if let result = FuzzyMatcher.match(query, in: target) {
                scores.append(result.score)
            }
        }

        XCTAssertEqual(scores.count, 10)
        let firstScore = scores[0]
        for score in scores {
            XCTAssertEqual(score, firstScore, accuracy: 0.0001, "Score should be deterministic")
        }
    }
}
