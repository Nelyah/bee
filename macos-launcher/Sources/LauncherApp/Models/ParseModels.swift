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
        case "TagPlusPrefix": return .tagPlusPrefix
        case "TagMinusPrefix": return .tagMinusPrefix
        case "ProjectPrefix": return .projectPrefix
        case "FilterTokDateDue": return .filterTokDateDue
        case "FilterTokDateDueBefore": return .filterTokDateDueBefore
        case "FilterTokDateDueAfter": return .filterTokDateDueAfter
        case "FilterTokDateCreatedBefore": return .filterTokDateCreatedBefore
        case "FilterTokDateCreatedAfter": return .filterTokDateCreatedAfter
        case "FilterTokDateEndBefore": return .filterTokDateEndBefore
        case "FilterTokDateEndAfter": return .filterTokDateEndAfter
        case "FilterStatus": return .filterStatus
        case "DependsOn": return .dependsOn
        case "OperatorAnd": return .operatorAnd
        case "OperatorOr": return .operatorOr
        case "OperatorXor": return .operatorXor
        case "LeftParenthesis": return .leftParenthesis
        case "RightParenthesis": return .rightParenthesis
        case "Uuid": return .uuid
        case "Int": return .int
        case "WordString": return .wordString
        case "Blank": return .blank
        default: return .unknown(rawValue)
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
