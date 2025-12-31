import XCTest

@testable import LauncherApp

final class CommandPaletteFuzzyScorerTests: XCTestCase {
    private var scorer: CommandPaletteFuzzyScorer!

    override func setUp() {
        super.setUp()
        scorer = CommandPaletteFuzzyScorer()
    }

    override func tearDown() {
        scorer = nil
        super.tearDown()
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

    func testPrefixMatchScoresHigh() {
        let score = scorer.score(query: "sel", target: "Select Report")
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 100)
        XCTAssertLessThan(score!, 1000)
    }

    func testPrefixMatchScoresHigherThanSubstring() {
        let prefixScore = scorer.score(query: "sel", target: "Select Report")
        let substringScore = scorer.score(query: "ect", target: "Select Report")
        XCTAssertNotNil(prefixScore)
        XCTAssertNotNil(substringScore)
        XCTAssertGreaterThan(prefixScore!, substringScore!)
    }

    // MARK: - Word Prefix Match Tests

    func testWordPrefixMatchScoresMedium() {
        let score = scorer.score(query: "rep", target: "Select Report")
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 50)
        XCTAssertLessThan(score!, 100)
    }

    func testWordPrefixMatchWithHyphen() {
        let score = scorer.score(query: "link", target: "Add GitLab-link")
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 25)
    }

    func testWordPrefixMatchWithUnderscore() {
        let score = scorer.score(query: "name", target: "project_name_here")
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 25)
    }

    // MARK: - Substring Match Tests

    func testSubstringMatchScoresLow() {
        let score = scorer.score(query: "ect rep", target: "Select Report")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 25)
    }

    func testSubstringMatchInMiddle() {
        let score = scorer.score(query: "lab", target: "Add GitLab link")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 25)
    }

    // MARK: - Fuzzy Match Tests

    func testFuzzyMatchScoresLowest() {
        let score = scorer.score(query: "slrp", target: "Select Report")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 10)
    }

    func testFuzzyMatchCharactersInOrder() {
        let score = scorer.score(query: "agl", target: "Add GitLab link")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 10)
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

    func testEmptyQueryMatchesEverything() {
        let score = scorer.score(query: "", target: "Select Report")
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 1000)
    }

    func testSingleCharacterMatch() {
        let score = scorer.score(query: "s", target: "Select Report")
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 100)
    }

    func testLongQueryWithExactMatch() {
        let longTarget = "Add a very long GitLab merge request link to the selected task"
        let score = scorer.score(query: longTarget, target: longTarget)
        XCTAssertEqual(score, 1000)
    }

    // MARK: - Ranking Order Tests

    func testRankingOrder() {
        // Verify: exact > prefix > word-prefix > substring > fuzzy
        let exactScore = scorer.score(query: "Select", target: "Select")!
        let prefixScore = scorer.score(query: "Select", target: "Select Report")!
        let wordPrefixScore = scorer.score(query: "Report", target: "Select Report")!
        let substringScore = scorer.score(query: "elect", target: "Select Report")!
        let fuzzyScore = scorer.score(query: "slrp", target: "Select Report")!

        XCTAssertGreaterThan(exactScore, prefixScore)
        XCTAssertGreaterThan(prefixScore, wordPrefixScore)
        XCTAssertGreaterThan(wordPrefixScore, substringScore)
        XCTAssertGreaterThan(substringScore, fuzzyScore)
    }
}
