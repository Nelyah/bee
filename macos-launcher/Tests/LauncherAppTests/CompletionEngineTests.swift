@testable import LauncherApp
import XCTest

final class CompletionEngineTests: XCTestCase {
    func testActionCompletionsIncludeFilterKeywords() {
        let cache = CompletionCache(
            projects: [],
            tags: [],
            actions: [],
            status: [],
            dates: []
        )

        let result = CompletionEngine.buildCompletions(
            context: .action,
            prefix: "sta",
            cache: cache,
            tasks: []
        )

        XCTAssertTrue(result.items.contains { $0.value == "status:" })
        XCTAssertEqual(result.ghostText, "tus:")
    }

    func testGhostTextShowsFirstItemWhenPrefixEmptyForStatus() {
        let cache = CompletionCache(
            projects: [],
            tags: [],
            actions: [],
            status: [
                CompletionItem(value: "pending", count: nil),
                CompletionItem(value: "active", count: nil),
            ],
            dates: []
        )

        let result = CompletionEngine.buildCompletions(
            context: .status,
            prefix: "",
            cache: cache,
            tasks: []
        )

        XCTAssertEqual(result.ghostText, "pending")
    }
}
