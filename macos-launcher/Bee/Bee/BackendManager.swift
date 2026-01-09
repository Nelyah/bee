//
//  BackendManager.swift
//  Bee
//
//  Manages the lifecycle of the bee-api backend process using Unix domain sockets.
//  The backend is bundled with the app and runs automatically when the app starts.
//

import Combine
import Foundation
import LauncherAppKit
import os

/// Get the real home directory, bypassing sandbox remapping.
/// In a sandboxed app, `NSHomeDirectory()` returns the container path,
/// but we need the actual user home for the backend to access config/database.
private func getRealHomeDirectory() -> String {
    // getpwuid returns the passwd entry for the user, which has the real home path
    if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
        return String(cString: home)
    }
    // Fallback to environment (will be sandboxed path, but better than nothing)
    return ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
}

/// Manages the lifecycle of the bee-api backend process.
///
/// The backend communicates via Unix domain socket for true network isolation.
/// No TCP port is exposed - only the app can communicate with its backend.
@MainActor
final class BackendManager: ObservableObject {
    /// Shared instance for app-wide access.
    static let shared = BackendManager()

    private let logger = Logger(subsystem: "bee", category: "backend")
    private var process: Process?

    /// The Unix socket path for the running backend.
    @Published private(set) var socketPath: String?

    /// Whether the backend is currently running and ready.
    @Published private(set) var isReady = false

    /// Error message if startup failed.
    @Published private(set) var startupError: String?

    private init() {}

    // MARK: - Lifecycle

    /// Starts the backend process if not already running.
    func start() async throws {
        guard process == nil else {
            logger.info("Backend already running at \(socketPath ?? "unknown")")
            return
        }

        startupError = nil

        // Generate unique socket path using PID
        // Use FileManager.temporaryDirectory for sandbox compatibility - this points to
        // the app's container temp directory when sandboxed, or /var/folders/... otherwise
        let tempDir = FileManager.default.temporaryDirectory
        let path = tempDir.appendingPathComponent("bee-\(ProcessInfo.processInfo.processIdentifier).sock").path

        // Remove stale socket file if exists
        try? FileManager.default.removeItem(atPath: path)

        // Locate the binary in the app bundle
        guard let binaryURL = Bundle.main.url(forResource: "beed", withExtension: nil) else {
            let error = BackendError.binaryNotFound
            startupError = error.localizedDescription
            throw error
        }

        logger.info("Found backend binary at \(binaryURL.path)")

        // Note: Don't try to chmod the bundled binary - app bundles are code-signed and read-only.
        // The binary should already have execute permissions from the build script.

        let process = Process()
        process.executableURL = binaryURL

        // Get the real home directory (not the sandboxed container path)
        // The sandbox remaps HOME to ~/Library/Containers/..., but we need the actual home
        // for the backend to find the user's config and database files
        let realHome = getRealHomeDirectory()
        logger.info("Using real home directory: \(realHome)")

        process.environment = ProcessInfo.processInfo.environment.merging([
            "BEE_API_SOCKET": path,
            "HOME": realHome, // Override sandboxed HOME so backend finds config
            "BEE_DATA_HOME": "\(realHome)/.local/share/bee", // Explicit data directory
        ]) { _, new in new }

        // Capture stdout/stderr for debugging
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Log output asynchronously
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                self?.logger.debug("Backend: \(output)")
            }
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.logger.info("Backend terminated with code \(proc.terminationStatus)")
                self?.cleanup()
            }
        }

        do {
            try process.run()
        } catch {
            let wrappedError = BackendError.failedToStart(error.localizedDescription)
            startupError = wrappedError.localizedDescription
            throw wrappedError
        }

        self.process = process
        socketPath = path

        logger.info("Backend started, waiting for socket at \(path)")

        // Wait for socket file to appear and backend to be ready
        try await waitForReady()
        isReady = true
    }

    /// Stops the backend process and cleans up.
    func stop() {
        guard let process else { return }

        logger.info("Stopping backend...")
        process.terminate()

        // Give it a moment to terminate gracefully
        DispatchQueue.global().async {
            self.process?.waitUntilExit()
        }

        cleanup()
    }

    // MARK: - Private

    private func cleanup() {
        if let path = socketPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        process = nil
        socketPath = nil
        isReady = false
    }

    /// Wait for the backend to be ready by checking if socket file exists and responds.
    ///
    /// We require multiple consecutive successful health checks to ensure the server
    /// is fully warmed up and stable, not just momentarily accepting connections.
    private func waitForReady(timeout: TimeInterval = 10) async throws {
        guard let path = socketPath else {
            throw BackendError.notStarted
        }

        let start = Date()
        let requiredSuccessCount = 2 // Require 2 consecutive successes
        var consecutiveSuccesses = 0

        // Wait for socket file to exist and server to respond consistently
        while Date().timeIntervalSince(start) < timeout {
            if FileManager.default.fileExists(atPath: path) {
                // Socket exists, try to connect
                do {
                    let transport = UnixSocketTransport(socketPath: path, connectionTimeout: 2)
                    let (data, statusCode) = try await transport.send(
                        method: "GET",
                        path: "/v1/config",
                        queryItems: [],
                        body: nil,
                        headers: [:]
                    )
                    if statusCode == 200 {
                        consecutiveSuccesses += 1
                        logger
                            .info(
                                "Backend health check \(consecutiveSuccesses)/\(requiredSuccessCount) passed (\(data.count) bytes)"
                            )

                        if consecutiveSuccesses >= requiredSuccessCount {
                            logger.info("Backend ready after \(consecutiveSuccesses) consecutive successful checks")
                            return
                        }
                        // Small delay between checks
                        try await Task.sleep(for: .milliseconds(50))
                        continue
                    }
                    logger.warning("Backend responded with status \(statusCode), retrying...")
                    consecutiveSuccesses = 0
                } catch {
                    // Connection failed, backend might still be starting
                    logger.debug("Connection failed: \(error.localizedDescription), retrying...")
                    consecutiveSuccesses = 0
                }
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        let error = BackendError.timeout
        startupError = error.localizedDescription
        throw error
    }
}

// MARK: - Errors

/// Errors that can occur when managing the backend process.
enum BackendError: LocalizedError {
    case binaryNotFound
    case notStarted
    case timeout
    case failedToStart(String)
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            "Backend binary (beed) not found in app bundle"
        case .notStarted:
            "Backend not started"
        case .timeout:
            "Backend failed to start within timeout"
        case let .failedToStart(reason):
            "Failed to start backend: \(reason)"
        case let .connectionFailed(reason):
            "Connection failed: \(reason)"
        }
    }
}
