@testable import LauncherApp
import XCTest

@MainActor
final class ParseErrorToastSchedulerTests: XCTestCase {
    // MARK: - Basic Scheduling Tests

    func testScheduleShowsToastAfterDelay() async {
        var shownMessages: [String] = []
        let scheduler = ParseErrorToastScheduler(
            delay: 0.05,
            shouldDefer: { false },
            isRequestCurrent: { _ in true },
            showToast: { shownMessages.append($0) }
        )

        scheduler.schedule(message: "Error message", requestId: 1)

        // Wait for the delay
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(shownMessages, ["Error message"])
    }

    func testCancelPreventsToast() async {
        var shownMessages: [String] = []
        let scheduler = ParseErrorToastScheduler(
            delay: 0.1,
            shouldDefer: { false },
            isRequestCurrent: { _ in true },
            showToast: { shownMessages.append($0) }
        )

        scheduler.schedule(message: "Error message", requestId: 1)
        scheduler.cancel()

        // Wait past the delay
        try? await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(shownMessages.isEmpty)
    }

    func testScheduleReplacesPreviousToast() async {
        var shownMessages: [String] = []
        let scheduler = ParseErrorToastScheduler(
            delay: 0.05,
            shouldDefer: { false },
            isRequestCurrent: { _ in true },
            showToast: { shownMessages.append($0) }
        )

        scheduler.schedule(message: "First error", requestId: 1)
        scheduler.schedule(message: "Second error", requestId: 2)

        // Wait for the delay
        try? await Task.sleep(for: .milliseconds(100))

        // Only the second message should be shown
        XCTAssertEqual(shownMessages, ["Second error"])
    }

    // MARK: - Deferred Scheduling Tests

    func testDeferredSchedulingDoesNotShowImmediately() async {
        var shownMessages: [String] = []
        var shouldDefer = true

        let scheduler = ParseErrorToastScheduler(
            delay: 0.01,
            shouldDefer: { shouldDefer },
            isRequestCurrent: { _ in true },
            showToast: { shownMessages.append($0) }
        )

        scheduler.schedule(message: "Deferred error", requestId: 1)

        // Wait past the delay
        try? await Task.sleep(for: .milliseconds(50))

        // Should not show because it was deferred
        XCTAssertTrue(shownMessages.isEmpty)
    }

    func testScheduleAfterMenuCloseTriggersDeferred() async {
        var shownMessages: [String] = []
        var shouldDefer = true

        let scheduler = ParseErrorToastScheduler(
            delay: 0.01,
            shouldDefer: { shouldDefer },
            isRequestCurrent: { _ in true },
            showToast: { shownMessages.append($0) }
        )

        // Schedule while deferred
        scheduler.schedule(message: "Deferred error", requestId: 1)
        try? await Task.sleep(for: .milliseconds(20))
        XCTAssertTrue(shownMessages.isEmpty)

        // Now close the menu
        shouldDefer = false
        scheduler.scheduleAfterMenuClose()

        // Wait for the delay
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(shownMessages, ["Deferred error"])
    }

    func testScheduleAfterMenuCloseWhileStillDeferredDoesNothing() async {
        var shownMessages: [String] = []

        let scheduler = ParseErrorToastScheduler(
            delay: 0.01,
            shouldDefer: { true }, // Always defer
            isRequestCurrent: { _ in true },
            showToast: { shownMessages.append($0) }
        )

        scheduler.schedule(message: "Error", requestId: 1)
        scheduler.scheduleAfterMenuClose()

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(shownMessages.isEmpty)
    }

    func testScheduleAfterMenuCloseWithNoPendingMessage() async {
        var shownMessages: [String] = []

        let scheduler = ParseErrorToastScheduler(
            delay: 0.01,
            shouldDefer: { false },
            isRequestCurrent: { _ in true },
            showToast: { shownMessages.append($0) }
        )

        // Call without scheduling first
        scheduler.scheduleAfterMenuClose()

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(shownMessages.isEmpty)
    }

    // MARK: - Request Currency Tests

    func testStaleRequestDoesNotShowToast() async {
        var shownMessages: [String] = []
        var currentRequestId = 1

        let scheduler = ParseErrorToastScheduler(
            delay: 0.05,
            shouldDefer: { false },
            isRequestCurrent: { $0 == currentRequestId },
            showToast: { shownMessages.append($0) }
        )

        scheduler.schedule(message: "Error for request 1", requestId: 1)

        // Simulate a new request coming in
        currentRequestId = 2

        // Wait for the delay
        try? await Task.sleep(for: .milliseconds(100))

        // Should not show because request 1 is no longer current
        XCTAssertTrue(shownMessages.isEmpty)
    }

    func testCurrentRequestShowsToast() async {
        var shownMessages: [String] = []
        let currentRequestId = 5

        let scheduler = ParseErrorToastScheduler(
            delay: 0.05,
            shouldDefer: { false },
            isRequestCurrent: { $0 == currentRequestId },
            showToast: { shownMessages.append($0) }
        )

        scheduler.schedule(message: "Error", requestId: 5)

        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(shownMessages, ["Error"])
    }

    // MARK: - Request ID Mismatch Tests

    func testScheduleWithDifferentRequestIdCancelsPrevious() async {
        var shownMessages: [String] = []

        let scheduler = ParseErrorToastScheduler(
            delay: 0.1,
            shouldDefer: { false },
            isRequestCurrent: { _ in true },
            showToast: { shownMessages.append($0) }
        )

        scheduler.schedule(message: "Error 1", requestId: 1)
        try? await Task.sleep(for: .milliseconds(20))

        // Schedule with different request ID
        scheduler.schedule(message: "Error 2", requestId: 2)

        try? await Task.sleep(for: .milliseconds(150))

        // Only the second message should appear
        XCTAssertEqual(shownMessages, ["Error 2"])
    }

    // MARK: - Integration Tests

    func testTypicalUseCase() async {
        var shownMessages: [String] = []
        var isMenuOpen = false
        var currentRequestId = 0

        let scheduler = ParseErrorToastScheduler(
            delay: 0.02,
            shouldDefer: { isMenuOpen },
            isRequestCurrent: { $0 == currentRequestId },
            showToast: { shownMessages.append($0) }
        )

        // User types, causing parse error while menu is closed
        currentRequestId = 1
        scheduler.schedule(message: "Parse error", requestId: 1)

        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(shownMessages, ["Parse error"])

        // User opens menu, types more
        shownMessages.removeAll()
        isMenuOpen = true
        currentRequestId = 2
        scheduler.schedule(message: "Another error", requestId: 2)

        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(shownMessages.isEmpty) // Deferred

        // User closes menu
        isMenuOpen = false
        scheduler.scheduleAfterMenuClose()

        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(shownMessages, ["Another error"])
    }
}
