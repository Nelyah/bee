import Foundation
import OSLog

final class ApiClient: ApiClientProtocol, Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "bee.macos-launcher", category: "api")

    /// Initialize the API client, optionally using BEE_API_BASE_URL.
    private static var defaultBaseURL: URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = 3000
        guard let url = components.url else {
            fatalError("Invalid default API URL")
        }
        return url
    }

    init(
        baseURL: URL? = nil,
        session: URLSession = .shared,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        if let baseURL {
            self.baseURL = baseURL
        } else if let env = environment["BEE_API_BASE_URL"],
                  let url = URL(string: env) {
            self.baseURL = url
        } else {
            self.baseURL = Self.defaultBaseURL
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
        var attempt = 0
        while true {
            do {
                return try await send(request, path: "/v1/action")
            } catch let error as ApiClientError {
                switch error {
                case let .api(message, code, developerMessage):
                    if message.lowercased().contains("database is locked"), attempt < 2 {
                        attempt += 1
                        let delay = UInt64(150_000_000 * attempt)
                        logger.warning("Retrying action after database lock. attempt=\(attempt)")
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    throw ApiClientError.api(
                        message: message,
                        code: code,
                        developerMessage: developerMessage
                    )
                case .invalidResponse:
                    throw error
                }
            }
        }
    }

    /// Fetch the current configuration from the API.
    func fetchConfig() async throws -> ConfigResponse {
        try await get(path: "/v1/config")
    }

    /// Fetch completions of a given type from the API.
    func fetchCompletions(type: String) async throws -> CompletionsResponse {
        try await get(path: "/v1/completions", queryItems: [URLQueryItem(name: "type", value: type)])
    }

    func fetchTaskDetail(taskUUID: String) async throws -> ApiTaskDetail {
        try await get(path: "/v1/tasks/\(taskUUID)")
    }

    func fetchExternalLinks(taskUUID: String) async throws -> [ExternalLinkDto] {
        try await get(path: "/v1/tasks/\(taskUUID)/external-links")
    }

    func syncExternalLink(linkId: Int, force: Bool) async throws -> ExternalLinkSyncResponse {
        let query = force ? [URLQueryItem(name: "force", value: "true")] : []
        return try await post(path: "/v1/external-links/\(linkId)/sync", queryItems: query)
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
                URLQueryItem(name: "scope", value: scope.rawValue),
            ]
        )
    }

    func resolveExternalLink(
        provider: ExternalLinkProvider,
        input: String
    ) async throws -> ExternalLinkResolveResponse {
        let request = ExternalLinkResolveRequest(provider: provider.rawValue, input: input)
        return try await send(request, path: "/v1/external-links/resolve")
    }

    func addExternalLink(taskUUID: String, url: String) async throws -> ExternalLinkDto {
        let request = ExternalLinkCreateRequest(url: url)
        return try await send(request, path: "/v1/tasks/\(taskUUID)/external-links")
    }

    // MARK: - User Reports

    func createUserReport(_ request: UserReportRequest) async throws -> UserReportDto {
        try await send(request, path: "/v1/reports")
    }

    func updateUserReport(name: String, _ request: UserReportRequest) async throws -> UserReportDto {
        try await put(request, path: "/v1/reports/\(name)")
    }

    func deleteUserReport(name: String) async throws {
        try await delete(path: "/v1/reports/\(name)")
    }

    // MARK: - Attachments

    func uploadAttachment(taskUUID: String, fileURL: URL) async throws -> TaskAttachmentDto {
        let url = baseURL.appendingPathComponent("/v1/tasks/\(taskUUID)/attachments")
        logger
            .info("HTTP POST (multipart) /v1/tasks/\(taskUUID)/attachments -> \(url.absoluteString, privacy: .public)")

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, path: "/v1/tasks/\(taskUUID)/attachments")
        return try JSONDecoder().decode(TaskAttachmentDto.self, from: data)
    }

    func downloadAttachment(attachmentId: Int) async throws -> Data {
        let path = "/v1/attachments/\(attachmentId)/download"
        let url = baseURL.appendingPathComponent(path)
        logger.info("HTTP GET \(path, privacy: .public) -> \(url.absoluteString, privacy: .public)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, path: path)
        return data
    }

    func deleteAttachment(attachmentId: Int) async throws {
        try await delete(path: "/v1/attachments/\(attachmentId)")
    }

    /// Send a JSON POST request to the API and decode the response type.
    private func send<Response: Decodable>(
        _ body: some Encodable,
        path: String
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        logger.info("HTTP POST \(path, privacy: .public) -> \(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, path: path)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Send a GET request to the API and decode the response type.
    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        guard var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw ApiClientError.invalidResponse
        }
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
        try validateResponse(response, data: data, path: path)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Send a POST request without a JSON body and decode the response type.
    private func post<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        guard var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw ApiClientError.invalidResponse
        }
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        guard let url = urlComponents.url else {
            throw ApiClientError.invalidResponse
        }
        logger.info("HTTP POST \(path, privacy: .public) -> \(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, path: path)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Send a JSON PUT request to the API and decode the response type.
    private func put<Response: Decodable>(
        _ body: some Encodable,
        path: String
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        logger.info("HTTP PUT \(path, privacy: .public) -> \(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, path: path)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Send a DELETE request to the API.
    private func delete(path: String) async throws {
        let url = baseURL.appendingPathComponent(path)
        logger.info("HTTP DELETE \(path, privacy: .public) -> \(url.absoluteString, privacy: .public)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, path: path)
    }

    /// Validate HTTP response and throw on non-2xx status codes.
    private func validateResponse(_ response: URLResponse, data: Data, path: String) throws {
        guard let http = response as? HTTPURLResponse else {
            logger.error("HTTP error \(path, privacy: .public) (no response)")
            throw ApiClientError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let payload = decodeErrorPayload(from: data)
            let message = payload?.userMessage ?? "HTTP \(http.statusCode)"
            logger.error("HTTP error \(path, privacy: .public) status=\(http.statusCode)")
            if let payload {
                let code = payload.code
                let detail = payload.developerMessage
                logger.error("API error code=\(code, privacy: .public) detail=\(detail, privacy: .public)")
            }
            throw ApiClientError.api(
                message: message,
                code: payload?.code,
                developerMessage: payload?.developerMessage
            )
        }
        logger.debug("HTTP response \(path, privacy: .public) status=\(http.statusCode)")
    }

    /// Decode an API error payload from non-2xx responses.
    private func decodeErrorPayload(from data: Data) -> ApiErrorResponse? {
        try? JSONDecoder().decode(ApiErrorResponse.self, from: data)
    }
}

/// Errors surfaced by the API client.
enum ApiClientError: LocalizedError {
    case api(message: String, code: String?, developerMessage: String?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case let .api(message, _, _):
            message
        case .invalidResponse:
            "Invalid response from server"
        }
    }

    var code: String? {
        switch self {
        case let .api(_, code, _):
            code
        case .invalidResponse:
            nil
        }
    }

    var developerMessage: String? {
        switch self {
        case let .api(_, _, developerMessage):
            developerMessage
        case .invalidResponse:
            nil
        }
    }
}
