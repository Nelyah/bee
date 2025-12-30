import XCTest
@testable import LauncherApp

final class TokenClassifierTests: XCTestCase {
    func testTokenClassifierDateFilters() {
        let dateTypes = [
            "FilterTokDateDue",
            "FilterTokDateDueBefore",
            "FilterTokDateDueAfter",
            "FilterTokDateCreatedBefore",
            "FilterTokDateCreatedAfter",
            "FilterTokDateEndBefore",
            "FilterTokDateEndAfter"
        ]

        for tokenType in dateTypes {
            XCTAssertTrue(TokenClassifier.isDateFilter(tokenType))
        }
    }

    func testTokenClassifierLogicalOperators() {
        XCTAssertTrue(TokenClassifier.isLogicalOperator("OperatorAnd"))
        XCTAssertTrue(TokenClassifier.isLogicalOperator("OperatorOr"))
        XCTAssertTrue(TokenClassifier.isLogicalOperator("OperatorXor"))
        XCTAssertFalse(TokenClassifier.isLogicalOperator("OperatorNot"))
    }

    func testTokenClassifierIdentifiers() {
        XCTAssertTrue(TokenClassifier.isIdentifier("Uuid"))
        XCTAssertTrue(TokenClassifier.isIdentifier("Int"))
        XCTAssertFalse(TokenClassifier.isIdentifier("Float"))
    }
}
