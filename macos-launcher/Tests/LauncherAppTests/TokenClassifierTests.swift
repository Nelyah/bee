@testable import LauncherAppKit
import XCTest

final class TokenClassifierTests: XCTestCase {
    func testTokenClassifierDateFilters() {
        let dateTypes: [TokenType] = [
            .filterTokDateDue,
            .filterTokDateDueBefore,
            .filterTokDateDueAfter,
            .filterTokDateCreatedBefore,
            .filterTokDateCreatedAfter,
            .filterTokDateEndBefore,
            .filterTokDateEndAfter,
        ]

        for tokenType in dateTypes {
            XCTAssertTrue(TokenClassifier.isDateFilter(tokenType))
        }
    }

    func testTokenClassifierLogicalOperators() {
        XCTAssertTrue(TokenClassifier.isLogicalOperator(.operatorAnd))
        XCTAssertTrue(TokenClassifier.isLogicalOperator(.operatorOr))
        XCTAssertTrue(TokenClassifier.isLogicalOperator(.operatorXor))
        XCTAssertFalse(TokenClassifier.isLogicalOperator(.unknown("OperatorNot")))
    }

    func testTokenClassifierIdentifiers() {
        XCTAssertTrue(TokenClassifier.isIdentifier(.uuid))
        XCTAssertTrue(TokenClassifier.isIdentifier(.int))
        XCTAssertFalse(TokenClassifier.isIdentifier(.unknown("Float")))
    }

    func testTokenTypeDecodesUnknown() throws {
        let json = """
        {
            "token_type": "MysteryToken",
            "literal": "x",
            "start": 0,
            "end": 1
        }
        """
        let data = Data(json.utf8)
        let span = try JSONDecoder().decode(TokenSpan.self, from: data)
        if case let .unknown(rawValue) = span.tokenType {
            XCTAssertEqual(rawValue, "MysteryToken")
        } else {
            XCTFail("Expected unknown token type")
        }
    }
}
