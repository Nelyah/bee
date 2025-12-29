/// API error payload for non-2xx responses.
struct ApiErrorResponse: Decodable {
    let error: String
}
