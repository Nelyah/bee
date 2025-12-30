import Foundation
import OSLog

final class ApiClient: ApiClientProtocol, Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "bee.macos-launcher", category: "api")

    /// Initialize the API client, optionally using BEE_API_BASE_URL.
    init(
        baseURL: URL? = nil,
        session: URLSession = .shared,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let defaultURL = URL(string: "http://127.0.0.1:3000")!
        if let baseURL {
            self.baseURL = baseURL
        } else if let env = environment["BEE_API_BASE_URL"],
                  let url = URL(string: env) {
            self.baseURL = url
        } else {
            self.baseURL = defaultURL
        }
        self.session = session
    }

    /// Send input to the parse endpoint and decode the response.
    func parse(input: String) async throws -> ParseResponse {
        let request = ParseRequest(input: input)
        return try await send(request, path: "/v1/parse")
    }

    /// Return an empty parse response when no parse has completed yet.
    func emptyParse() -> ParseResponse {
        ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
    }

    /// Execute an action with optional properties and filter.
    func runAction(action: String, properties: JSONValue?, filter: JSONValue?) async throws -> ActionResponse {
        let request = ActionRequest(action: action, properties: properties, filter: filter)
        return try await send(request, path: "/v1/action")
    }

    /// Fetch the current configuration from the API.
    func fetchConfig() async throws -> ConfigResponse {
        try await get(path: "/v1/config")
    }

    /// Fetch completions of a given type from the API.
    func fetchCompletions(type: String) async throws -> CompletionsResponse {
        try await get(path: "/v1/completions", queryItems: [URLQueryItem(name: "type", value: type)])
    }

    func fetchRecentGitlabMergeRequests(limit: Int) async throws -> [GitlabMergeRequestSuggestion] {
        try await get(
            path: "/v1/external-links/gitlab/merge-requests/recent",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
    }

    func fetchRecentJiraIssues(limit: Int, scope: JiraIssueScope) async throws -> [JiraIssueSuggestion] {
        try await get(
            path: "/v1/external-links/jira/issues/recent",
            queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "scope", value: scope.rawValue)
            ]
        )
    }

    func resolveExternalLink(provider: ExternalLinkProvider, input: String) async throws -> ExternalLinkResolveResponse {
        let request = ExternalLinkResolveRequest(provider: provider.rawValue, input: input)
        return try await send(request, path: "/v1/external-links/resolve")
    }

    func addExternalLink(taskUUID: String, url: String) async throws -> ExternalLinkDto {
        let request = ExternalLinkCreateRequest(url: url)
        return try await send(request, path: "/v1/tasks/\(taskUUID)/external-links")
    }

    /// Send a JSON POST request to the API and decode the response type.
    private func send<Request: Encodable, Response: Decodable>(
        _ body: Request,
        path: String
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        logger.info("HTTP POST \(path, privacy: .public) -> \(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            logger.error("HTTP error \(path, privacy: .public) (no response)")
            throw ApiClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = decodeErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            logger.error("HTTP error \(path, privacy: .public) status=\(http.statusCode)")
            throw ApiClientError.api(message: message)
        }
        logger.debug("HTTP response \(path, privacy: .public) status=\(http.statusCode)")
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Send a GET request to the API and decode the response type.
    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        guard let url = urlComponents.url else {
            throw ApiClientError.invalidResponse
        }
        logger.info("HTTP GET \(path, privacy: .public) -> \(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            logger.error("HTTP error \(path, privacy: .public) (no response)")
            throw ApiClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = decodeErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            logger.error("HTTP error \(path, privacy: .public) status=\(http.statusCode)")
            throw ApiClientError.api(message: message)
        }
        logger.debug("HTTP response \(path, privacy: .public) status=\(http.statusCode)")
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Decode an API error message from a JSON error payload.
    private func decodeErrorMessage(from data: Data) -> String? {
        guard let response = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) else {
            return nil
        }
        return response.error
    }
}

/// Errors surfaced by the API client.
enum ApiClientError: LocalizedError {
    case api(message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .api(let message):
            return message
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
