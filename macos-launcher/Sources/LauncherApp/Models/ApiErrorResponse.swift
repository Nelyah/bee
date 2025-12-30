/// API error payload for non-2xx responses.
struct ApiErrorResponse: Decodable {
    let code: String
    let userMessage: String
    let developerMessage: String

    private enum CodingKeys: String, CodingKey {
        case code
        case userMessage = "user_message"
        case developerMessage = "developer_message"
    }
}
