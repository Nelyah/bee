@testable import LauncherAppKit
import XCTest

final class ParseModelsTests: XCTestCase {
    // MARK: - TokenType Tests

    func testTokenTypeDecodesKnownTypes() throws {
        let knownTypes: [(String, TokenType)] = [
            ("TagPlusPrefix", .tagPlusPrefix),
            ("TagMinusPrefix", .tagMinusPrefix),
            ("ProjectPrefix", .projectPrefix),
            ("FilterTokDateDue", .filterTokDateDue),
            ("FilterTokDateDueBefore", .filterTokDateDueBefore),
            ("FilterTokDateDueAfter", .filterTokDateDueAfter),
            ("FilterTokDateCreatedBefore", .filterTokDateCreatedBefore),
            ("FilterTokDateCreatedAfter", .filterTokDateCreatedAfter),
            ("FilterTokDateEndBefore", .filterTokDateEndBefore),
            ("FilterTokDateEndAfter", .filterTokDateEndAfter),
            ("FilterStatus", .filterStatus),
            ("DependsOn", .dependsOn),
            ("OperatorAnd", .operatorAnd),
            ("OperatorOr", .operatorOr),
            ("OperatorXor", .operatorXor),
            ("LeftParenthesis", .leftParenthesis),
            ("RightParenthesis", .rightParenthesis),
            ("Uuid", .uuid),
            ("Int", .int),
            ("WordString", .wordString),
            ("Blank", .blank),
        ]

        for (rawValue, expected) in knownTypes {
            let json = #""\#(rawValue)""#
            let tokenType = try TestHelpers.decode(TokenType.self, from: json)
            XCTAssertEqual(tokenType, expected, "Failed for \(rawValue)")
        }
    }

    func testTokenTypeDecodesUnknown() throws {
        let json = #""UnknownTokenType""#
        let tokenType = try TestHelpers.decode(TokenType.self, from: json)
        XCTAssertEqual(tokenType, .unknown("UnknownTokenType"))
    }

    func testTokenTypeHashable() {
        let set: Set<TokenType> = [.tagPlusPrefix, .tagMinusPrefix, .tagPlusPrefix]
        XCTAssertEqual(set.count, 2)
    }

    func testTokenTypeUnknownHashable() {
        let set: Set<TokenType> = [.unknown("a"), .unknown("b"), .unknown("a")]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - TokenSpan Tests

    func testTokenSpanDecodes() throws {
        let json = """
        {
            "token_type": "TagPlusPrefix",
            "literal": "+",
            "start": 0,
            "end": 1
        }
        """
        let span = try TestHelpers.decode(TokenSpan.self, from: json)
        XCTAssertEqual(span.tokenType, .tagPlusPrefix)
        XCTAssertEqual(span.literal, "+")
        XCTAssertEqual(span.start, 0)
        XCTAssertEqual(span.end, 1)
    }

    func testTokenSpanDecodesWordString() throws {
        let json = """
        {
            "token_type": "WordString",
            "literal": "urgent",
            "start": 1,
            "end": 7
        }
        """
        let span = try TestHelpers.decode(TokenSpan.self, from: json)
        XCTAssertEqual(span.tokenType, .wordString)
        XCTAssertEqual(span.literal, "urgent")
        XCTAssertEqual(span.start, 1)
        XCTAssertEqual(span.end, 7)
    }

    func testTokenSpanDecodesUnknownType() throws {
        let json = """
        {
            "token_type": "NewTokenType",
            "literal": "test",
            "start": 0,
            "end": 4
        }
        """
        let span = try TestHelpers.decode(TokenSpan.self, from: json)
        XCTAssertEqual(span.tokenType, .unknown("NewTokenType"))
    }

    // MARK: - ParseRequest Tests

    func testParseRequestEncodes() throws {
        let request = ParseRequest(input: "list +urgent project:work")
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["input"] as? String, "list +urgent project:work")
    }

    // MARK: - ParseResponse Tests

    func testParseResponseDecodes() throws {
        let json = """
        {
            "action": "list",
            "properties": null,
            "filter": {"type": "tag", "value": "urgent"},
            "tokens": [
                {"token_type": "WordString", "literal": "list", "start": 0, "end": 4}
            ]
        }
        """
        let response = try TestHelpers.decode(ParseResponse.self, from: json)
        XCTAssertEqual(response.action, "list")
        XCTAssertNil(response.properties)
        XCTAssertNotNil(response.filter)
        XCTAssertEqual(response.tokens.count, 1)
        XCTAssertEqual(response.tokens.first?.literal, "list")
    }

    func testParseResponseDecodesWithProperties() throws {
        let json = """
        {
            "action": "add",
            "properties": {"summary": "New task"},
            "filter": null,
            "tokens": []
        }
        """
        let response = try TestHelpers.decode(ParseResponse.self, from: json)
        XCTAssertEqual(response.action, "add")
        XCTAssertNotNil(response.properties)
        XCTAssertNil(response.filter)
    }

    func testParseResponseDecodesMultipleTokens() throws {
        let json = """
        {
            "action": "list",
            "properties": null,
            "filter": null,
            "tokens": [
                {"token_type": "WordString", "literal": "list", "start": 0, "end": 4},
                {"token_type": "Blank", "literal": " ", "start": 4, "end": 5},
                {"token_type": "TagPlusPrefix", "literal": "+", "start": 5, "end": 6},
                {"token_type": "WordString", "literal": "urgent", "start": 6, "end": 12}
            ]
        }
        """
        let response = try TestHelpers.decode(ParseResponse.self, from: json)
        XCTAssertEqual(response.tokens.count, 4)
        XCTAssertEqual(response.tokens[2].tokenType, .tagPlusPrefix)
    }
}
