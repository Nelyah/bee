import XCTest

@testable import LauncherApp

final class CommandPaletteFuzzyScorerTests: XCTestCase {
    private var scorer = CommandPaletteFuzzyScorer()

    override func setUp() {
        super.setUp()
        scorer = CommandPaletteFuzzyScorer()
    }

    // MARK: - Exact Match Tests

    func testExactMatchScoresHighest() {
        let score = scorer.score(query: "Select Report", target: "Select Report")
        XCTAssertEqual(score, 1000)
    }

    func testExactMatchCaseInsensitive() {
        let score = scorer.score(query: "select report", target: "Select Report")
        XCTAssertEqual(score, 1000)
    }

    // MARK: - Prefix Match Tests

    func testPrefixMatchScoresHigh() throws {
        let score = try XCTUnwrap(scorer.score(query: "sel", target: "Select Report"))
        XCTAssertGreaterThan(score, 100)
        XCTAssertLessThan(score, 1000)
    }

    func testPrefixMatchScoresHigherThanSubstring() throws {
        let prefixScore = try XCTUnwrap(scorer.score(query: "sel", target: "Select Report"))
        let substringScore = try XCTUnwrap(scorer.score(query: "ect", target: "Select Report"))
        XCTAssertGreaterThan(prefixScore, substringScore)
    }

    // MARK: - Word Prefix Match Tests

    func testWordPrefixMatchScoresMedium() throws {
        let score = try XCTUnwrap(scorer.score(query: "rep", target: "Select Report"))
        XCTAssertGreaterThan(score, 50)
        XCTAssertLessThan(score, 100)
    }

    func testWordPrefixMatchWithHyphen() throws {
        let score = try XCTUnwrap(scorer.score(query: "link", target: "Add GitLab-link"))
        XCTAssertGreaterThan(score, 25)
    }

    func testWordPrefixMatchWithUnderscore() throws {
        let score = try XCTUnwrap(scorer.score(query: "name", target: "project_name_here"))
        XCTAssertGreaterThan(score, 25)
    }

    // MARK: - Substring Match Tests

    func testSubstringMatchScoresLow() throws {
        let score = try XCTUnwrap(scorer.score(query: "ect rep", target: "Select Report"))
        XCTAssertEqual(score, 25)
    }

    func testSubstringMatchInMiddle() throws {
        let score = try XCTUnwrap(scorer.score(query: "lab", target: "Add GitLab link"))
        XCTAssertEqual(score, 25)
    }

    // MARK: - Fuzzy Match Tests

    func testFuzzyMatchScoresLowest() throws {
        let score = try XCTUnwrap(scorer.score(query: "slrp", target: "Select Report"))
        XCTAssertEqual(score, 10)
    }

    func testFuzzyMatchCharactersInOrder() throws {
        let score = try XCTUnwrap(scorer.score(query: "agl", target: "Add GitLab link"))
        XCTAssertEqual(score, 10)
    }

    // MARK: - No Match Tests

    func testNoMatchReturnsNil() {
        let score = scorer.score(query: "xyz", target: "Select Report")
        XCTAssertNil(score)
    }

    func testNoMatchWhenCharactersOutOfOrder() {
        let score = scorer.score(query: "trs", target: "Select Report")
        XCTAssertNil(score)
    }

    // MARK: - Edge Cases

    func testEmptyQueryMatchesEverything() throws {
        let score = try XCTUnwrap(scorer.score(query: "", target: "Select Report"))
        XCTAssertEqual(score, 1000)
    }

    func testSingleCharacterMatch() throws {
        let score = try XCTUnwrap(scorer.score(query: "s", target: "Select Report"))
        XCTAssertGreaterThan(score, 100)
    }

    func testLongQueryWithExactMatch() {
        let longTarget = "Add a very long GitLab merge request link to the selected task"
        let score = scorer.score(query: longTarget, target: longTarget)
        XCTAssertEqual(score, 1000)
    }

    // MARK: - Ranking Order Tests

    func testRankingOrder() throws {
        // Verify: exact > prefix > word-prefix > substring > fuzzy
        let exactScore = try XCTUnwrap(scorer.score(query: "Select", target: "Select"))
        let prefixScore = try XCTUnwrap(scorer.score(query: "Select", target: "Select Report"))
        let wordPrefixScore = try XCTUnwrap(scorer.score(query: "Report", target: "Select Report"))
        let substringScore = try XCTUnwrap(scorer.score(query: "elect", target: "Select Report"))
        let fuzzyScore = try XCTUnwrap(scorer.score(query: "slrp", target: "Select Report"))

        XCTAssertGreaterThan(exactScore, prefixScore)
        XCTAssertGreaterThan(prefixScore, wordPrefixScore)
        XCTAssertGreaterThan(wordPrefixScore, substringScore)
        XCTAssertGreaterThan(substringScore, fuzzyScore)
    }
}
