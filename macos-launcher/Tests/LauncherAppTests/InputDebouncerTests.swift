@testable import LauncherApp
import XCTest

@MainActor
final class InputDebouncerTests: XCTestCase {
    // MARK: - Basic Debounce Tests

    func testDebounceExecutesAfterDelay() async {
        var executed = false
        let debouncer = InputDebouncer(delay: 0.03)

        debouncer.debounce(requestId: 1) {
            executed = true
        }

        XCTAssertFalse(executed, "Action should not execute immediately")

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(executed, "Action should execute after delay")
    }

    func testDebounceSupersededByNewRequest() async {
        var executedIds: [Int] = []
        let debouncer = InputDebouncer(delay: 0.03)

        debouncer.debounce(requestId: 1) {
            executedIds.append(1)
        }

        // Wait a bit, but not past the delay
        try? await Task.sleep(for: .milliseconds(10))

        debouncer.debounce(requestId: 2) {
            executedIds.append(2)
        }

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(executedIds, [2], "Only the last request should execute")
    }

    func testCancelPreventsExecution() async {
        var executed = false
        let debouncer = InputDebouncer(delay: 0.03)

        debouncer.debounce(requestId: 1) {
            executed = true
        }

        debouncer.cancel()

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(executed, "Action should not execute after cancel")
    }

    // MARK: - Rapid Typing Simulation Tests

    func testRapidDebounceOnlyExecutesLast() async {
        var executedIds: [Int] = []
        let debouncer = InputDebouncer(delay: 0.03)

        // Simulate rapid typing: 5 keystrokes in quick succession
        for i in 1 ... 5 {
            debouncer.debounce(requestId: i) {
                executedIds.append(i)
            }
            try? await Task.sleep(for: .milliseconds(5))
        }

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(executedIds, [5], "Only the final keystroke should trigger action")
    }

    func testMultipleDebounceCyclesWork() async {
        var executedIds: [Int] = []
        let debouncer = InputDebouncer(delay: 0.02)

        // First cycle
        debouncer.debounce(requestId: 1) {
            executedIds.append(1)
        }

        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(executedIds, [1])

        // Second cycle
        debouncer.debounce(requestId: 2) {
            executedIds.append(2)
        }

        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(executedIds, [1, 2])
    }

    // MARK: - Request ID Validation Tests

    func testStaleRequestIdPreventsExecution() async {
        var executed = false
        let debouncer = InputDebouncer(delay: 0.03)

        debouncer.debounce(requestId: 1) {
            executed = true
        }

        // Simulate a new request superseding the old one (via cancel)
        debouncer.cancel()

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(executed)
    }

    // MARK: - Default Delay Tests

    func testDefaultDelayIs50ms() async {
        var executed = false
        let debouncer = InputDebouncer() // Uses default delay

        debouncer.debounce(requestId: 1) {
            executed = true
        }

        // Should not execute before 50ms
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertFalse(executed)

        // Should execute after 50ms
        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertTrue(executed)
    }
}
