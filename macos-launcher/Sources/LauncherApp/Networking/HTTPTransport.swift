import Foundation

/// HTTP transport using URLSession - for remote servers.
///
/// This transport sends requests over standard HTTP/HTTPS using the system's
/// URLSession. Use this for connecting to remote bee-api servers.
public final class HTTPTransport: ApiTransport, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    /// Create an HTTP transport.
    ///
    /// - Parameters:
    ///   - baseURL: Base URL for the API (e.g., "http://127.0.0.1:3000")
    ///   - session: URLSession to use for requests (defaults to shared session)
    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func send(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Data?,
        headers: [String: String]
    ) async throws -> (data: Data, statusCode: Int) {
        // Build URL with query items
        guard var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw TransportError.invalidResponse
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw TransportError.invalidResponse
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        // Set default Content-Type for requests with body
        if body != nil {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Apply custom headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        // Send request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransportError.invalidResponse
        }

        return (data, httpResponse.statusCode)
    }
}
