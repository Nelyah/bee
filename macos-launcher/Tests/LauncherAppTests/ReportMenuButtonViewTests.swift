import AppKit
import XCTest

@testable import LauncherApp

final class ReportMenuButtonViewTests: XCTestCase {
    func testUpdateBuildsMenuItemsAndMarksSelection() {
        let reports = [
            ReportSummary(
                name: "default",
                staticFilters: [],
                columns: [],
                columnNames: [],
                isDefault: true
            ),
            ReportSummary(
                name: "work",
                staticFilters: [],
                columns: [],
                columnNames: [],
                isDefault: false
            ),
        ]

        let view = ReportMenuButtonView(onSelect: { _ in }, onPress: {})
        view.update(name: "work", reports: reports)

        let items = view.menuItems
        XCTAssertEqual(items.map(\.title), ["default", "work"])
        XCTAssertEqual(items[1].state, .on)
        XCTAssertEqual(items[0].state, .off)
    }
}
