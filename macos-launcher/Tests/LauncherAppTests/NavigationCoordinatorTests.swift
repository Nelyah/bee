@testable import LauncherApp
import XCTest

final class NavigationCoordinatorTests: XCTestCase {
    func testModeForInputChangeReturnsList() {
        XCTAssertEqual(NavigationCoordinator.modeForInputChange(), .list)
    }

    func testModeForOpenDetailRequiresSelection() {
        XCTAssertNil(NavigationCoordinator.modeForOpenDetail(selectedIndex: nil))
        XCTAssertEqual(NavigationCoordinator.modeForOpenDetail(selectedIndex: 0), .detail)
    }

    func testModeForCloseDetailReturnsList() {
        XCTAssertEqual(NavigationCoordinator.modeForCloseDetail(), .list)
    }
}
