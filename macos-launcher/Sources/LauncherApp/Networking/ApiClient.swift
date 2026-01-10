import Foundation
import OSLog

public final class ApiClient: ApiClientProtocol, Sendable {
    private let transport: ApiTransport
    private let logger = Logger(subsystem: "bee.macos-launcher", category: "api")

    /// The profile this client is bound to, or nil for legacy/non-profile mode.
    public let profile: String?

    // MARK: - Factory Methods

    /// Create an ApiClient for HTTP connections (remote servers).
    public static func http(baseURL: URL, session: URLSession = .shared, profile: String? = nil) -> ApiClient {
        ApiClient(transport: HTTPTransport(baseURL: baseURL, session: session), profile: profile)
    }

    /// Create an ApiClient for Unix socket connections (local backend).
    public static func unixSocket(path: String, profile: String? = nil) -> ApiClient {
        ApiClient(transport: UnixSocketTransport(socketPath: path), profile: profile)
    }

    /// Create an ApiClient bound to a specific profile.
    ///
    /// All API calls will be routed to `/v1/profiles/{profile}/...` paths.
    public static func forProfile(_ profile: String, transport: ApiTransport) -> ApiClient {
        ApiClient(transport: transport, profile: profile)
    }

    // MARK: - Initializers

    /// Initialize the API client with a specific transport and optional profile.
    public init(transport: ApiTransport, profile: String? = nil) {
        self.transport = transport
        self.profile = profile
    }

    /// Legacy initializer for backwards compatibility - creates HTTP transport.
    ///
    /// Checks `BEE_API_BASE_URL` environment variable, falls back to `http://127.0.0.1:3000`.
    convenience init(
        baseURL: URL? = nil,
        session: URLSession = .shared,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        profile: String? = nil
    ) {
        let url: URL = if let baseURL {
            baseURL
        } else if let env = environment["BEE_API_BASE_URL"],
                  let envURL = URL(string: env) {
            envURL
        } else {
            Self.defaultBaseURL
        }
        self.init(transport: HTTPTransport(baseURL: url, session: session), profile: profile)
    }

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

    // MARK: - Profile Path Helpers

    /// Build an API path, prefixing with profile if bound to one.
    ///
    /// - For non-profile clients: `/v1/tasks` remains `/v1/tasks`
    /// - For profile clients: `/v1/tasks` becomes `/v1/profiles/{profile}/tasks`
    private func profilePath(_ basePath: String) -> String {
        guard let profile else {
            return basePath
        }
        // Remove /v1 prefix and add profile prefix
        if basePath.hasPrefix("/v1/") {
            let suffix = String(basePath.dropFirst(4)) // Remove "/v1/"
            return "/v1/profiles/\(profile)/\(suffix)"
        }
        return basePath
    }

    // MARK: - API Methods

    /// Send input to the parse endpoint and decode the response.
    func parse(input: String) async throws -> ParseResponse {
        let request = ParseRequest(input: input)
        return try await send(request, path: profilePath("/v1/parse"))
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
                return try await send(request, path: profilePath("/v1/action"))
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
        try await get(path: profilePath("/v1/config"))
    }

    /// Fetch completions of a given type from the API.
    func fetchCompletions(type: String) async throws -> CompletionsResponse {
        try await get(path: profilePath("/v1/completions"), queryItems: [URLQueryItem(name: "type", value: type)])
    }

    func fetchTaskDetail(taskUUID: String) async throws -> ApiTaskDetail {
        try await get(path: profilePath("/v1/tasks/\(taskUUID)"))
    }

    func fetchExternalLinks(taskUUID: String) async throws -> [ExternalLinkDto] {
        try await get(path: profilePath("/v1/tasks/\(taskUUID)/external-links"))
    }

    func syncExternalLink(linkId: Int, force: Bool) async throws -> ExternalLinkSyncResponse {
        let query = force ? [URLQueryItem(name: "force", value: "true")] : []
        return try await post(path: profilePath("/v1/external-links/\(linkId)/sync"), queryItems: query)
    }

    func fetchRecentGitlabMergeRequests(limit: Int) async throws -> [GitlabMergeRequestSuggestion] {
        try await get(
            path: profilePath("/v1/external-links/gitlab/merge-requests/recent"),
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
    }

    func fetchRecentJiraIssues(limit: Int, scope: JiraIssueScope) async throws -> [JiraIssueSuggestion] {
        try await get(
            path: profilePath("/v1/external-links/jira/issues/recent"),
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
        return try await send(request, path: profilePath("/v1/external-links/resolve"))
    }

    func addExternalLink(taskUUID: String, url: String) async throws -> ExternalLinkDto {
        let request = ExternalLinkCreateRequest(url: url)
        return try await send(request, path: profilePath("/v1/tasks/\(taskUUID)/external-links"))
    }

    // MARK: - User Reports

    func createUserReport(_ request: UserReportRequest) async throws -> UserReportDto {
        try await send(request, path: profilePath("/v1/reports"))
    }

    func updateUserReport(name: String, _ request: UserReportRequest) async throws -> UserReportDto {
        try await put(request, path: profilePath("/v1/reports/\(name)"))
    }

    func deleteUserReport(name: String) async throws {
        try await delete(path: profilePath("/v1/reports/\(name)"))
    }

    // MARK: - Attachments

    func uploadAttachment(taskUUID: String, fileURL: URL) async throws -> TaskAttachmentDto {
        let path = profilePath("/v1/tasks/\(taskUUID)/attachments")
        logger.info("HTTP POST (multipart) \(path, privacy: .public)")

        let boundary = UUID().uuidString

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

        let (data, statusCode) = try await transport.send(
            method: "POST",
            path: path,
            queryItems: [],
            body: body,
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        )
        try validateResponse(statusCode: statusCode, data: data, path: path)
        return try JSONDecoder().decode(TaskAttachmentDto.self, from: data)
    }

    func downloadAttachment(attachmentId: Int) async throws -> Data {
        let path = profilePath("/v1/attachments/\(attachmentId)/download")
        logger.info("HTTP GET \(path, privacy: .public)")

        let (data, statusCode) = try await transport.send(
            method: "GET",
            path: path,
            queryItems: [],
            body: nil,
            headers: [:]
        )
        try validateResponse(statusCode: statusCode, data: data, path: path)
        return data
    }

    func deleteAttachment(attachmentId: Int) async throws {
        try await delete(path: profilePath("/v1/attachments/\(attachmentId)"))
    }

    // MARK: - Project Overview

    func fetchProjects() async throws -> ProjectsResponse {
        try await get(path: profilePath("/v1/projects"))
    }

    func fetchProjectBurndown(project: String, days: Int) async throws -> ProjectBurndownResponse {
        let encodedProject = project.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? project
        return try await get(
            path: profilePath("/v1/projects/\(encodedProject)/burndown"),
            queryItems: [URLQueryItem(name: "days", value: String(days))]
        )
    }

    // MARK: - Profile Management (global, not profile-scoped)

    /// List all available profiles.
    public func listProfiles() async throws -> ProfilesListResponse {
        // Profile list is always at the global path, not profile-scoped
        try await get(path: "/v1/profiles")
    }

    /// Create a new profile.
    public func createProfile(key: String, name: String?, description: String?) async throws -> ProfileCreateResponse {
        let request = ProfileCreateRequest(key: key, name: name, description: description)
        // Profile creation is always at the global path
        return try await send(request, path: "/v1/profiles")
    }

    /// Delete a profile.
    public func deleteProfile(key: String) async throws {
        // Profile deletion is always at the global path
        try await delete(path: "/v1/profiles/\(key)")
    }

    // MARK: - Private Transport Helpers

    /// Send a JSON POST request to the API and decode the response type.
    private func send<Response: Decodable>(
        _ body: some Encodable,
        path: String
    ) async throws -> Response {
        logger.info("HTTP POST \(path, privacy: .public)")
        let bodyData = try JSONEncoder().encode(body)

        let (data, statusCode) = try await transport.send(
            method: "POST",
            path: path,
            queryItems: [],
            body: bodyData,
            headers: [:]
        )
        try validateResponse(statusCode: statusCode, data: data, path: path)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Send a GET request to the API and decode the response type.
    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        logger.info("HTTP GET \(path, privacy: .public)")

        let (data, statusCode) = try await transport.send(
            method: "GET",
            path: path,
            queryItems: queryItems,
            body: nil,
            headers: [:]
        )
        try validateResponse(statusCode: statusCode, data: data, path: path)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Send a POST request without a JSON body and decode the response type.
    private func post<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        logger.info("HTTP POST \(path, privacy: .public)")

        let (data, statusCode) = try await transport.send(
            method: "POST",
            path: path,
            queryItems: queryItems,
            body: nil,
            headers: [:]
        )
        try validateResponse(statusCode: statusCode, data: data, path: path)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Send a JSON PUT request to the API and decode the response type.
    private func put<Response: Decodable>(
        _ body: some Encodable,
        path: String
    ) async throws -> Response {
        logger.info("HTTP PUT \(path, privacy: .public)")
        let bodyData = try JSONEncoder().encode(body)

        let (data, statusCode) = try await transport.send(
            method: "PUT",
            path: path,
            queryItems: [],
            body: bodyData,
            headers: [:]
        )
        try validateResponse(statusCode: statusCode, data: data, path: path)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Send a DELETE request to the API.
    private func delete(path: String) async throws {
        logger.info("HTTP DELETE \(path, privacy: .public)")

        let (data, statusCode) = try await transport.send(
            method: "DELETE",
            path: path,
            queryItems: [],
            body: nil,
            headers: [:]
        )
        try validateResponse(statusCode: statusCode, data: data, path: path)
    }

    /// Validate HTTP status code and throw on non-2xx status codes.
    private func validateResponse(statusCode: Int, data: Data, path: String) throws {
        guard (200 ..< 300).contains(statusCode) else {
            let payload = decodeErrorPayload(from: data)
            let message = payload?.userMessage ?? "HTTP \(statusCode)"
            logger.error("HTTP error \(path, privacy: .public) status=\(statusCode)")
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
        logger.debug("HTTP response \(path, privacy: .public) status=\(statusCode)")
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
