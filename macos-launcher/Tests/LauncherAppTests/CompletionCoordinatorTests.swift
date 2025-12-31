@testable import LauncherApp
import XCTest

@MainActor
final class CompletionCoordinatorTests: XCTestCase {
    func testAcceptGhostTextReturnsFirstItem() {
        let coordinator = CompletionCoordinator()
        coordinator.items = [
            CompletionItem(value: "status:", count: nil),
            CompletionItem(value: "project:", count: nil),
        ]
        coordinator.ghostText = "atus:"

        let item = coordinator.acceptGhostText()
        XCTAssertEqual(item?.value, "status:")
    }
}
