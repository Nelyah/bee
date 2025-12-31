@testable import LauncherApp
import XCTest

final class SerialTaskQueueTests: XCTestCase {
    // MARK: - Serial Execution Tests

    func testOperationsRunSequentially() async throws {
        let queue = SerialTaskQueue()
        var executionOrder: [Int] = []
        let lock = NSLock()

        // Start multiple operations with small delays between submissions
        // to ensure deterministic submission order (async let spawns concurrent
        // child tasks whose scheduling order is otherwise non-deterministic)
        async let result1: Void = queue.run {
            try? await Task.sleep(for: .milliseconds(50))
            lock.withLock { executionOrder.append(1) }
        }
        try? await Task.sleep(for: .milliseconds(1))

        async let result2: Void = queue.run {
            try? await Task.sleep(for: .milliseconds(10))
            lock.withLock { executionOrder.append(2) }
        }
        try? await Task.sleep(for: .milliseconds(1))

        async let result3: Void = queue.run {
            lock.withLock { executionOrder.append(3) }
        }

        // Wait for all to complete
        _ = try await (result1, result2, result3)

        // Despite different sleep times, operations should run in submission order
        XCTAssertEqual(executionOrder, [1, 2, 3])
    }

    func testOperationReturnsValue() async throws {
        let queue = SerialTaskQueue()

        let result = try await queue.run {
            42
        }

        XCTAssertEqual(result, 42)
    }

    func testOperationThrowsError() async {
        let queue = SerialTaskQueue()

        do {
            _ = try await queue.run {
                throw TestError.intentional
            }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testErrorDoesNotBlockSubsequentOperations() async throws {
        let queue = SerialTaskQueue()

        // First operation throws
        do {
            _ = try await queue.run {
                throw TestError.intentional
            }
        } catch {
            // Expected
        }

        // Second operation should still run
        let result = try await queue.run {
            "success"
        }

        XCTAssertEqual(result, "success")
    }

    func testOperationsCompleteInFIFOOrder() async throws {
        let queue = SerialTaskQueue()
        var completionOrder: [String] = []
        let lock = NSLock()

        let operations = ["A", "B", "C", "D", "E"]

        await withTaskGroup(of: Void.self) { group in
            for op in operations {
                group.addTask {
                    try? await queue.run {
                        lock.withLock { completionOrder.append(op) }
                    }
                }
                // Small delay to ensure ordering
                try? await Task.sleep(for: .milliseconds(1))
            }
        }

        XCTAssertEqual(completionOrder, operations)
    }

    func testConcurrentAccessIsSafe() async throws {
        let queue = SerialTaskQueue()
        var counter = 0
        let lock = NSLock()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    try? await queue.run {
                        // Simulate some work
                        let current = lock.withLock { counter }
                        try? await Task.sleep(for: .microseconds(10))
                        lock.withLock { counter = current + 1 }
                    }
                }
            }
        }

        // With serial execution, counter should be exactly 100
        XCTAssertEqual(counter, 100)
    }

    func testAsyncOperationWithDelay() async throws {
        let queue = SerialTaskQueue()
        let startTime = Date()

        try await queue.run {
            try await Task.sleep(for: .milliseconds(50))
        }

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThanOrEqual(elapsed, 0.05)
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case intentional
}
