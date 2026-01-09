import Foundation

/// Protocol for sending HTTP-like requests over different transports.
///
/// This abstraction allows ApiClient to work over both HTTP (for remote servers)
/// and Unix sockets (for local backend) without changing any business logic.
/// The transport is responsible only for sending raw bytes and receiving the response;
/// all JSON encoding/decoding, retry logic, and error handling remain in ApiClient.
public protocol ApiTransport: Sendable {
    /// Send an HTTP-like request and return raw response data with status code.
    ///
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, PUT, DELETE, etc.)
    ///   - path: Request path (e.g., "/v1/config")
    ///   - queryItems: Optional query parameters
    ///   - body: Optional request body data
    ///   - headers: Additional HTTP headers
    /// - Returns: Tuple of response data and HTTP status code
    /// - Throws: `TransportError` on connection or protocol errors
    func send(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Data?,
        headers: [String: String]
    ) async throws -> (data: Data, statusCode: Int)
}

/// Errors that can occur at the transport layer.
public enum TransportError: LocalizedError {
    /// Response could not be parsed as HTTP
    case invalidResponse

    /// Failed to establish or maintain connection
    case connectionFailed(String)

    /// Request timed out
    case timeout

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from server"
        case let .connectionFailed(reason):
            "Connection failed: \(reason)"
        case .timeout:
            "Request timed out"
        }
    }
}
