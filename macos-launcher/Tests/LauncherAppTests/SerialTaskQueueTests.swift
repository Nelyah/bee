@testable import LauncherAppKit
import XCTest

final class SerialTaskQueueTests: XCTestCase {
    // MARK: - Serial Execution Tests

    func testOperationsRunSequentially() async throws {
        let queue = SerialTaskQueue()
        let executionOrder = AtomicArray<Int>()

        // Start multiple operations with small delays between submissions
        // to ensure deterministic submission order (async let spawns concurrent
        // child tasks whose scheduling order is otherwise non-deterministic)
        async let result1: Void = queue.run {
            try? await Task.sleep(for: .milliseconds(50))
            executionOrder.append(1)
        }
        try? await Task.sleep(for: .milliseconds(1))

        async let result2: Void = queue.run {
            try? await Task.sleep(for: .milliseconds(10))
            executionOrder.append(2)
        }
        try? await Task.sleep(for: .milliseconds(1))

        async let result3: Void = queue.run {
            executionOrder.append(3)
        }

        // Wait for all to complete
        _ = try await (result1, result2, result3)

        // Despite different sleep times, operations should run in submission order
        XCTAssertEqual(executionOrder.get(), [1, 2, 3])
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
        let completionOrder = AtomicArray<String>()

        let operations = ["A", "B", "C", "D", "E"]

        await withTaskGroup(of: Void.self) { group in
            for op in operations {
                group.addTask {
                    try? await queue.run {
                        completionOrder.append(op)
                    }
                }
                // Small delay to ensure ordering
                try? await Task.sleep(for: .milliseconds(1))
            }
        }

        XCTAssertEqual(completionOrder.get(), operations)
    }

    func testConcurrentAccessIsSafe() async throws {
        let queue = SerialTaskQueue()
        let counter = AtomicCounter(0)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    try? await queue.run {
                        // Simulate some work
                        let current = counter.get()
                        try? await Task.sleep(for: .microseconds(10))
                        counter.set(current + 1)
                    }
                }
            }
        }

        // With serial execution, counter should be exactly 100
        XCTAssertEqual(counter.get(), 100)
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

/// A thread-safe counter for use in concurrent test code.
/// Marked as `@unchecked Sendable` because we manually ensure thread safety with NSLock.
private final class AtomicCounter: @unchecked Sendable {
    private var value: Int
    private let lock = NSLock()

    init(_ initialValue: Int = 0) {
        value = initialValue
    }

    /// Gets the current value.
    func get() -> Int {
        lock.withLock { value }
    }

    /// Sets a new value.
    func set(_ newValue: Int) {
        lock.withLock { value = newValue }
    }
}

/// A thread-safe array for use in concurrent test code.
/// Marked as `@unchecked Sendable` because we manually ensure thread safety with NSLock.
private final class AtomicArray<Element>: @unchecked Sendable {
    private var values: [Element] = []
    private let lock = NSLock()

    /// Appends an element to the array.
    func append(_ element: Element) {
        lock.withLock { values.append(element) }
    }

    /// Gets a copy of the current array.
    func get() -> [Element] {
        lock.withLock { values }
    }
}
