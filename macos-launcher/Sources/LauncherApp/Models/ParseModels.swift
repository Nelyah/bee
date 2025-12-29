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

struct TokenSpan: Decodable {
    let tokenType: String
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
