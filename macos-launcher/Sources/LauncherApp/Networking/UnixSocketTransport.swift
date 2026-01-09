import Foundation

/// Unix domain socket transport using POSIX sockets.
///
/// This transport communicates with the bee-api backend via a Unix domain socket,
/// providing true network isolation (no TCP port exposed). It manually constructs
/// HTTP/1.1 requests and parses responses since URLSession doesn't support Unix sockets.
public final class UnixSocketTransport: ApiTransport, @unchecked Sendable {
    private let socketPath: String
    private let connectionTimeout: TimeInterval

    /// Create a Unix socket transport.
    ///
    /// - Parameters:
    ///   - socketPath: Path to the Unix domain socket (e.g., "/tmp/bee-12345.sock")
    ///   - connectionTimeout: Timeout for operations (default: 10 seconds)
    public init(socketPath: String, connectionTimeout: TimeInterval = 10) {
        self.socketPath = socketPath
        self.connectionTimeout = connectionTimeout
    }

    public func send(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Data?,
        headers: [String: String]
    ) async throws -> (data: Data, statusCode: Int) {
        // Build full path with query string
        let fullPath = buildFullPath(path: path, queryItems: queryItems)

        // Build HTTP request
        let requestData = buildHTTPRequest(method: method, path: fullPath, body: body, headers: headers)

        // Perform synchronous socket I/O on a background thread
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.performRequest(requestData: requestData)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Socket Implementation

    private func performRequest(requestData: Data) throws -> (data: Data, statusCode: Int) {
        // Create Unix socket
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw TransportError.connectionFailed("Failed to create socket: \(errno)")
        }
        defer { close(fd) }

        // Set socket timeout
        var timeout = timeval(tv_sec: Int(connectionTimeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Build address structure
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        // Copy path to sun_path
        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { sunPathPtr in
            for (i, byte) in pathBytes.enumerated() where i < sunPathPtr.count {
                sunPathPtr[i] = UInt8(bitPattern: byte)
            }
        }

        // Connect to socket
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            throw TransportError.connectionFailed("Connect failed: \(errno)")
        }

        // Send request
        let bytesSent = requestData.withUnsafeBytes { ptr in
            Darwin.write(fd, ptr.baseAddress, requestData.count)
        }

        guard bytesSent == requestData.count else {
            throw TransportError.connectionFailed("Write failed: sent \(bytesSent) of \(requestData.count) bytes")
        }

        // Read response
        var responseData = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)

        while true {
            let bytesRead = read(fd, &buffer, buffer.count)
            if bytesRead < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw TransportError.timeout
                }
                throw TransportError.connectionFailed("Read failed: \(errno)")
            }
            if bytesRead == 0 {
                break // Connection closed by server
            }
            responseData.append(contentsOf: buffer[..<bytesRead])
        }

        // Parse HTTP response
        return try parseHTTPResponse(responseData)
    }

    // MARK: - Private Helpers

    private func buildFullPath(path: String, queryItems: [URLQueryItem]) -> String {
        guard !queryItems.isEmpty else { return path }

        var components = URLComponents()
        components.queryItems = queryItems
        guard let query = components.query else { return path }

        return "\(path)?\(query)"
    }

    private func buildHTTPRequest(
        method: String,
        path: String,
        body: Data?,
        headers: [String: String]
    ) -> Data {
        var request = "\(method) \(path) HTTP/1.1\r\n"
        request += "Host: localhost\r\n"
        request += "Connection: close\r\n"

        if let body, !body.isEmpty {
            request += "Content-Type: application/json\r\n"
            request += "Content-Length: \(body.count)\r\n"
        }

        for (key, value) in headers {
            request += "\(key): \(value)\r\n"
        }

        request += "\r\n"

        var data = Data(request.utf8)
        if let body {
            data.append(body)
        }

        return data
    }

    private func parseHTTPResponse(_ data: Data) throws -> (data: Data, statusCode: Int) {
        // Find header/body separator (\r\n\r\n) in raw bytes
        let separator: [UInt8] = [0x0D, 0x0A, 0x0D, 0x0A] // \r\n\r\n
        guard let separatorIndex = data.firstRange(of: Data(separator)) else {
            throw TransportError.invalidResponse
        }

        let headerData = data[..<separatorIndex.lowerBound]
        let bodyData = data[separatorIndex.upperBound...]

        // Parse headers as string
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw TransportError.invalidResponse
        }

        // Parse status line: "HTTP/1.1 200 OK"
        let lines = headerString.split(separator: "\r\n")
        guard let statusLine = lines.first else {
            throw TransportError.invalidResponse
        }

        let parts = statusLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2, let statusCode = Int(parts[1]) else {
            throw TransportError.invalidResponse
        }

        return (data: Data(bodyData), statusCode: statusCode)
    }
}
