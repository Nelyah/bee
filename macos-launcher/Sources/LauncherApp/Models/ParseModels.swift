import Foundation

struct ParseRequest: Encodable {
    let input: String
}

struct ParseResponse: Decodable {
    let action: String
    let properties: JSONValue?
    let filter: JSONValue?
    let tokens: [TokenSpan]
}

enum TokenType: Hashable, Decodable {
    case tagPlusPrefix
    case tagMinusPrefix
    case projectPrefix
    case filterTokDateDue
    case filterTokDateDueBefore
    case filterTokDateDueAfter
    case filterTokDateCreatedBefore
    case filterTokDateCreatedAfter
    case filterTokDateEndBefore
    case filterTokDateEndAfter
    case filterStatus
    case dependsOn
    case operatorAnd
    case operatorOr
    case operatorXor
    case leftParenthesis
    case rightParenthesis
    case uuid
    case int
    case wordString
    case blank
    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TokenType.fromRawValue(rawValue)
    }

    private static let tokenTypeMap: [String: TokenType] = [
        "TagPlusPrefix": .tagPlusPrefix,
        "TagMinusPrefix": .tagMinusPrefix,
        "ProjectPrefix": .projectPrefix,
        "FilterTokDateDue": .filterTokDateDue,
        "FilterTokDateDueBefore": .filterTokDateDueBefore,
        "FilterTokDateDueAfter": .filterTokDateDueAfter,
        "FilterTokDateCreatedBefore": .filterTokDateCreatedBefore,
        "FilterTokDateCreatedAfter": .filterTokDateCreatedAfter,
        "FilterTokDateEndBefore": .filterTokDateEndBefore,
        "FilterTokDateEndAfter": .filterTokDateEndAfter,
        "FilterStatus": .filterStatus,
        "DependsOn": .dependsOn,
        "OperatorAnd": .operatorAnd,
        "OperatorOr": .operatorOr,
        "OperatorXor": .operatorXor,
        "LeftParenthesis": .leftParenthesis,
        "RightParenthesis": .rightParenthesis,
        "Uuid": .uuid,
        "Int": .int,
        "WordString": .wordString,
        "Blank": .blank,
    ]

    private static func fromRawValue(_ rawValue: String) -> TokenType {
        tokenTypeMap[rawValue] ?? .unknown(rawValue)
    }
}

struct TokenSpan: Decodable {
    let tokenType: TokenType
    let literal: String
    let start: Int
    let end: Int

    private enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case literal
        case start
        case end
    }
}
