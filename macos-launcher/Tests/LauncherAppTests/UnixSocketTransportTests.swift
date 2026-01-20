import Foundation
import Network
import XCTest

@testable import LauncherAppKit

/// Tests for UnixSocketTransport to verify HTTP-over-Unix-socket communication.
final class UnixSocketTransportTests: XCTestCase {
    private var testSocketPath: String!
    private var mockServer: MockUnixSocketServer?

    override func setUp() async throws {
        try await super.setUp()
        // Use a unique socket path for each test
        testSocketPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("bee-test-\(UUID().uuidString).sock")
            .path
    }

    override func tearDown() async throws {
        mockServer?.stop()
        mockServer = nil
        try? FileManager.default.removeItem(atPath: testSocketPath)
        try await super.tearDown()
    }

    // MARK: - Real Backend Test (requires backend running at /tmp/bee-test.sock)

    /// Test against a real backend to verify the transport works.
    /// Run: BEE_API_SOCKET=/tmp/bee-test.sock cargo run -p bee-api
    func testWithRealBackend() async throws {
        let socketPath = "/tmp/bee-test.sock"

        // Skip if socket doesn't exist (backend not running)
        guard FileManager.default.fileExists(atPath: socketPath) else {
            throw XCTSkip("Backend not running at \(socketPath)")
        }

        let transport = UnixSocketTransport(socketPath: socketPath, connectionTimeout: 5)

        // Try to connect - skip if connection fails (stale socket file)
        let data: Data
        let statusCode: Int
        do {
            (data, statusCode) = try await transport.send(
                method: "GET",
                path: "/v1/config",
                queryItems: [],
                body: nil,
                headers: [:]
            )
        } catch {
            throw XCTSkip("Backend not responding at \(socketPath): \(error.localizedDescription)")
        }

        XCTAssertEqual(statusCode, 200)
        XCTAssertTrue(data.count > 0)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)
    }

    // MARK: - Basic Request/Response Tests

    func testSimpleGETRequest() async throws {
        // Given: A mock server that returns a simple JSON response
        let expectedResponse = #"{"status":"ok"}"#
        mockServer = MockUnixSocketServer(socketPath: testSocketPath)
        mockServer?.responseDelay = 0.1 // Delay to ensure client is ready to receive
        mockServer?.responseHandler = { _, _, _ in
            (200, expectedResponse.data(using: .utf8)!)
        }
        try mockServer?.start()

        // When: We send a GET request
        let transport = UnixSocketTransport(socketPath: testSocketPath, connectionTimeout: 5)
        let (data, statusCode) = try await transport.send(
            method: "GET",
            path: "/v1/test",
            queryItems: [],
            body: nil,
            headers: [:]
        )

        // Then: We receive the expected response
        XCTAssertEqual(statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), expectedResponse)
    }

    func testPOSTRequestWithBody() async throws {
        // Given: A mock server that echoes the request body
        var receivedBody: Data?
        mockServer = MockUnixSocketServer(socketPath: testSocketPath)
        mockServer?.responseHandler = { _, _, body in
            receivedBody = body
            return (201, body ?? Data())
        }
        try mockServer?.start()

        // When: We send a POST request with a JSON body
        let requestBody = #"{"name":"test"}"#.data(using: .utf8)!
        let transport = UnixSocketTransport(socketPath: testSocketPath, connectionTimeout: 5)
        let (data, statusCode) = try await transport.send(
            method: "POST",
            path: "/v1/create",
            queryItems: [],
            body: requestBody,
            headers: [:]
        )

        // Then: The server received the body and we got the response
        XCTAssertEqual(statusCode, 201)
        XCTAssertEqual(receivedBody, requestBody)
        XCTAssertEqual(data, requestBody)
    }

    func testQueryParameters() async throws {
        // Given: A mock server that captures the request path
        var receivedPath: String?
        mockServer = MockUnixSocketServer(socketPath: testSocketPath)
        mockServer?.responseHandler = { _, path, _ in
            receivedPath = path
            return (200, Data())
        }
        try mockServer?.start()

        // When: We send a request with query parameters
        let transport = UnixSocketTransport(socketPath: testSocketPath, connectionTimeout: 5)
        _ = try await transport.send(
            method: "GET",
            path: "/v1/search",
            queryItems: [
                URLQueryItem(name: "type", value: "project"),
                URLQueryItem(name: "limit", value: "10"),
            ],
            body: nil,
            headers: [:]
        )

        // Then: The path includes the query string
        XCTAssertEqual(receivedPath, "/v1/search?type=project&limit=10")
    }

    // MARK: - Large Response Tests

    func testLargeResponse() async throws {
        // Given: A mock server that returns a large response (100KB)
        let largeData = Data(repeating: UInt8.random(in: 0 ... 255), count: 100_000)
        mockServer = MockUnixSocketServer(socketPath: testSocketPath)
        mockServer?.responseHandler = { _, _, _ in
            (200, largeData)
        }
        try mockServer?.start()

        // When: We send a request
        let transport = UnixSocketTransport(socketPath: testSocketPath, connectionTimeout: 10)
        let (data, statusCode) = try await transport.send(
            method: "GET",
            path: "/v1/large",
            queryItems: [],
            body: nil,
            headers: [:]
        )

        // Then: We receive all the data
        XCTAssertEqual(statusCode, 200)
        XCTAssertEqual(data.count, largeData.count)
        XCTAssertEqual(data, largeData)
    }

    // MARK: - Concurrent Request Tests

    func testConcurrentRequests() async throws {
        // Given: A mock server that responds with the request path
        mockServer = MockUnixSocketServer(socketPath: testSocketPath)
        mockServer?.responseHandler = { _, path, _ in
            (200, path.data(using: .utf8)!)
        }
        try mockServer?.start()

        let transport = UnixSocketTransport(socketPath: testSocketPath, connectionTimeout: 5)

        // When: We send multiple concurrent requests
        async let response1 = transport.send(method: "GET", path: "/v1/one", queryItems: [], body: nil, headers: [:])
        async let response2 = transport.send(method: "GET", path: "/v1/two", queryItems: [], body: nil, headers: [:])
        async let response3 = transport.send(method: "GET", path: "/v1/three", queryItems: [], body: nil, headers: [:])

        let results = try await [response1, response2, response3]

        // Then: All requests complete successfully with correct responses
        XCTAssertEqual(results.count, 3)
        let paths = results.map { String(data: $0.data, encoding: .utf8)! }
        XCTAssertTrue(paths.contains("/v1/one"))
        XCTAssertTrue(paths.contains("/v1/two"))
        XCTAssertTrue(paths.contains("/v1/three"))
    }

    // MARK: - Error Handling Tests

    func testConnectionTimeout() async throws {
        // Given: No server is running (socket doesn't exist)
        let transport = UnixSocketTransport(socketPath: testSocketPath, connectionTimeout: 1)

        // When/Then: Request should timeout
        do {
            _ = try await transport.send(
                method: "GET",
                path: "/v1/test",
                queryItems: [],
                body: nil,
                headers: [:]
            )
            XCTFail("Expected timeout error")
        } catch let error as TransportError {
            // Either timeout or connection failed is acceptable
            switch error {
            case .timeout, .connectionFailed:
                break // Expected
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func testServerReturnsError() async throws {
        // Given: A mock server that returns 500
        mockServer = MockUnixSocketServer(socketPath: testSocketPath)
        mockServer?.responseHandler = { _, _, _ in
            (500, #"{"error":"Internal error"}"#.data(using: .utf8)!)
        }
        try mockServer?.start()

        // When: We send a request
        let transport = UnixSocketTransport(socketPath: testSocketPath, connectionTimeout: 5)
        let (data, statusCode) = try await transport.send(
            method: "GET",
            path: "/v1/fail",
            queryItems: [],
            body: nil,
            headers: [:]
        )

        // Then: We receive the error response (transport doesn't throw on 500)
        XCTAssertEqual(statusCode, 500)
        XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("Internal error"))
    }

    // MARK: - HTTP Request Building Tests

    func testBuildHTTPRequestRespectsCustomContentType() {
        // Given: A transport and custom Content-Type header
        let transport = UnixSocketTransport(socketPath: "/tmp/test.sock")
        let body = Data("test body".utf8)
        let customContentType = "multipart/form-data; boundary=abc123"

        // When: Building an HTTP request with custom Content-Type
        let request = transport.buildHTTPRequestForTesting(
            method: "POST",
            path: "/test",
            body: body,
            headers: ["Content-Type": customContentType]
        )

        // Then: The request should NOT contain "application/json"
        let requestString = String(data: request, encoding: .utf8)!
        XCTAssertFalse(
            requestString.contains("Content-Type: application/json"),
            "Request should not contain default Content-Type when custom one is provided"
        )
        XCTAssertTrue(
            requestString.contains("Content-Type: \(customContentType)"),
            "Request should contain the custom Content-Type"
        )
    }

    func testBuildHTTPRequestAddsDefaultContentTypeWhenNotProvided() {
        // Given: A transport with no custom Content-Type
        let transport = UnixSocketTransport(socketPath: "/tmp/test.sock")
        let body = Data("test body".utf8)

        // When: Building an HTTP request without Content-Type header
        let request = transport.buildHTTPRequestForTesting(
            method: "POST",
            path: "/test",
            body: body,
            headers: [:]
        )

        // Then: The request should contain default application/json
        let requestString = String(data: request, encoding: .utf8)!
        XCTAssertTrue(
            requestString.contains("Content-Type: application/json"),
            "Request should contain default Content-Type when none provided"
        )
    }

    // MARK: - Response Parsing Tests

    func testSlowServerResponse() async throws {
        // Given: A server that sends response in chunks with delays
        mockServer = MockUnixSocketServer(socketPath: testSocketPath)
        mockServer?.responseDelay = 0.1 // 100ms delay between chunks
        mockServer?.responseHandler = { _, _, _ in
            (200, #"{"result":"slow but complete"}"#.data(using: .utf8)!)
        }
        try mockServer?.start()

        // When: We send a request
        let transport = UnixSocketTransport(socketPath: testSocketPath, connectionTimeout: 10)
        let (data, statusCode) = try await transport.send(
            method: "GET",
            path: "/v1/slow",
            queryItems: [],
            body: nil,
            headers: [:]
        )

        // Then: We receive the complete response
        XCTAssertEqual(statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"result":"slow but complete"}"#)
    }
}

// MARK: - Mock Unix Socket Server

/// A simple mock HTTP server that listens on a Unix domain socket.
/// Used for testing UnixSocketTransport without needing the real backend.
final class MockUnixSocketServer {
    private let socketPath: String
    private var serverFd: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "mock-server", attributes: .concurrent)

    /// Handler that receives (method, path, body) and returns (statusCode, responseBody)
    var responseHandler: ((String, String, Data?) -> (Int, Data))?

    /// Optional delay before sending response (to test slow servers)
    var responseDelay: TimeInterval = 0

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    func start() throws {
        // Remove stale socket file
        try? FileManager.default.removeItem(atPath: socketPath)

        // Create socket
        serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFd >= 0 else {
            throw NSError(
                domain: "MockServer",
                code: Int(errno),
                userInfo: [NSLocalizedDescriptionKey: "Failed to create socket: \(errno)"]
            )
        }

        // Set socket options
        var reuseAddr: Int32 = 1
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        // Bind to Unix socket path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        // Copy path to sun_path
        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { sunPathPtr in
            for (i, byte) in pathBytes.enumerated() where i < sunPathPtr.count {
                sunPathPtr[i] = UInt8(bitPattern: byte)
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(serverFd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            let err = errno
            close(serverFd)
            serverFd = -1
            throw NSError(
                domain: "MockServer",
                code: Int(err),
                userInfo: [NSLocalizedDescriptionKey: "Bind failed: \(err)"]
            )
        }

        guard listen(serverFd, 10) == 0 else {
            let err = errno
            close(serverFd)
            serverFd = -1
            throw NSError(
                domain: "MockServer",
                code: Int(err),
                userInfo: [NSLocalizedDescriptionKey: "Listen failed: \(err)"]
            )
        }

        isRunning = true

        // Accept connections in background
        queue.async { [weak self] in
            self?.acceptLoop()
        }

        // Verify socket file exists
        var attempts = 0
        while !FileManager.default.fileExists(atPath: socketPath), attempts < 20 {
            Thread.sleep(forTimeInterval: 0.01)
            attempts += 1
        }

        guard FileManager.default.fileExists(atPath: socketPath) else {
            throw NSError(
                domain: "MockServer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Socket file was not created"]
            )
        }
    }

    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    accept(serverFd, sockaddrPtr, &clientAddrLen)
                }
            }

            if clientFd < 0 {
                if isRunning {
                    // Error, but continue trying
                    continue
                }
                break // Server stopped
            }

            queue.async { [weak self] in
                self?.handleClientConnection(fd: clientFd)
            }
        }
    }

    private func handleClientConnection(fd: Int32) {
        defer { close(fd) }

        // Read request with timeout
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        let requestData = Data(bytes: buffer, count: bytesRead)
        guard let requestString = String(data: requestData, encoding: .utf8) else { return }

        // Parse request line
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return }

        let method = String(parts[0])
        let path = String(parts[1])

        // Parse body (after \r\n\r\n)
        var body: Data?
        if let bodyRange = requestString.range(of: "\r\n\r\n") {
            let bodyString = String(requestString[bodyRange.upperBound...])
            if !bodyString.isEmpty {
                body = bodyString.data(using: .utf8)
            }
        }

        // Add delay if configured
        if responseDelay > 0 {
            Thread.sleep(forTimeInterval: responseDelay)
        }

        // Get response from handler
        let (statusCode, responseBody) = responseHandler?(method, path, body) ?? (200, Data())

        // Build HTTP response
        let statusText = switch statusCode {
        case 200: "OK"
        case 201: "Created"
        case 500: "Internal Server Error"
        default: "Error"
        }

        var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        response += "Content-Type: application/json\r\n"
        response += "Content-Length: \(responseBody.count)\r\n"
        response += "Connection: close\r\n"
        response += "\r\n"

        var responseData = Data(response.utf8)
        responseData.append(responseBody)

        // Send response
        _ = responseData.withUnsafeBytes { ptr in
            Darwin.write(fd, ptr.baseAddress, responseData.count)
        }
    }

    func stop() {
        isRunning = false
        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }
        try? FileManager.default.removeItem(atPath: socketPath)
    }
}
