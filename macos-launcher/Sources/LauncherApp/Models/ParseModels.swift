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

    private static func fromRawValue(_ rawValue: String) -> TokenType {
        switch rawValue {
        case "TagPlusPrefix": .tagPlusPrefix
        case "TagMinusPrefix": .tagMinusPrefix
        case "ProjectPrefix": .projectPrefix
        case "FilterTokDateDue": .filterTokDateDue
        case "FilterTokDateDueBefore": .filterTokDateDueBefore
        case "FilterTokDateDueAfter": .filterTokDateDueAfter
        case "FilterTokDateCreatedBefore": .filterTokDateCreatedBefore
        case "FilterTokDateCreatedAfter": .filterTokDateCreatedAfter
        case "FilterTokDateEndBefore": .filterTokDateEndBefore
        case "FilterTokDateEndAfter": .filterTokDateEndAfter
        case "FilterStatus": .filterStatus
        case "DependsOn": .dependsOn
        case "OperatorAnd": .operatorAnd
        case "OperatorOr": .operatorOr
        case "OperatorXor": .operatorXor
        case "LeftParenthesis": .leftParenthesis
        case "RightParenthesis": .rightParenthesis
        case "Uuid": .uuid
        case "Int": .int
        case "WordString": .wordString
        case "Blank": .blank
        default: .unknown(rawValue)
        }
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
