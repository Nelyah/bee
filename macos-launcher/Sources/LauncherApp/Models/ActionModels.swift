import Foundation

struct ActionRequest: Encodable {
    let action: String
    let properties: JSONValue?
    let filter: JSONValue?
}

struct ActionResponse: Decodable {
    let action: String
    let tasks: [ApiTask]
    let events: [ApiEvent]
}

/// Structured event emitted by the API.
struct ApiEvent: Decodable {
    let kind: String
    let message: String
}
