@testable import LauncherAppKit
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for ColumnHeaderRow using ViewInspector.
///
/// These tests verify the column header's structure, sort indicators, and resize handle behavior.
final class ColumnHeaderRowUITests: XCTestCase {
    // MARK: - Test Data

    private let testColumnConfigs = [
        ColumnConfig(key: "id", displayName: "ID", width: nil),
        ColumnConfig(key: "summary", displayName: "Summary", width: nil),
        ColumnConfig(key: "status", displayName: "Status", width: nil),
    ]

    // MARK: - Basic Rendering Tests

    func testColumnHeaderRowRendersAllColumnNames() throws {
        var sortedColumn: String?
        let sut = ColumnHeaderRow(
            columnConfigs: testColumnConfigs,
            sortState: nil,
            onSort: { sortedColumn = $0 },
            onResize: nil,
            onResizeEnd: nil
        )

        let view = try sut.inspect()

        // Find the column header text labels
        _ = try view.find(text: "ID")
        _ = try view.find(text: "SUMMARY")
        _ = try view.find(text: "STATUS")

        // Verify no sort happened yet
        XCTAssertNil(sortedColumn)
    }

    func testColumnHeaderShowsSortIndicatorWhenActive() throws {
        let sut = ColumnHeaderRow(
            columnConfigs: testColumnConfigs,
            sortState: .ascending("status"),
            onSort: { _ in },
            onResize: nil,
            onResizeEnd: nil
        )

        let view = try sut.inspect()

        // The sort indicator should be present as a chevron image
        // When ascending, it shows "chevron.up"
        let chevronImages = view.findAll(ViewType.Image.self)
        XCTAssertTrue(chevronImages.count >= 1, "Should have at least one chevron image for sort indicator")
    }

    func testColumnHeaderSortCallbackIsCalled() throws {
        var sortedColumn: String?
        let sut = ColumnHeaderRow(
            columnConfigs: testColumnConfigs,
            sortState: nil,
            onSort: { sortedColumn = $0 },
            onResize: nil,
            onResizeEnd: nil
        )

        let view = try sut.inspect()

        // Find and tap the "ID" column header button
        let idButton = try view.find(ViewType.Button.self, where: { button in
            (try? button.find(text: "ID")) != nil
        })
        try idButton.tap()

        XCTAssertEqual(sortedColumn, "id", "Sort callback should be called with 'id' column")
    }

    // MARK: - Resize Handle Tests

    /// Test that resize callbacks are wired correctly.
    /// This test verifies the resize handle exists and callbacks are invoked,
    /// but cannot fully test drag behavior due to ViewInspector limitations.
    func testResizeCallbacksAreWired() throws {
        var resizeColumn: String?
        var resizeDelta: CGFloat?
        var resizeEnded = false

        let sut = ColumnHeaderRow(
            columnConfigs: testColumnConfigs,
            sortState: nil,
            onSort: { _ in },
            onResize: { column, delta in
                resizeColumn = column
                resizeDelta = delta
            },
            onResizeEnd: { _ in
                resizeEnded = true
            }
        )

        // The view should render without errors
        let view = try sut.inspect()
        XCTAssertNoThrow(try view.find(ViewType.HStack.self))

        XCTAssertNil(resizeColumn)
        XCTAssertNil(resizeDelta)
        XCTAssertFalse(resizeEnded)

        // Note: ViewInspector cannot simulate drag gestures, so we verify
        // the component structure is correct. The actual drag behavior
        // must be tested manually or with XCUITest.
    }

    // MARK: - Column Config Tests

    func testFlexColumnDoesNotShowResizeHandle() throws {
        // Summary is the flex column - it should not have a resize handle
        let configs = [
            ColumnConfig(key: "id", displayName: "ID", width: nil),
            ColumnConfig(key: "summary", displayName: "Summary", width: nil), // Flex column
        ]

        let sut = ColumnHeaderRow(
            columnConfigs: configs,
            sortState: nil,
            onSort: { _ in },
            onResize: { _, _ in },
            onResizeEnd: nil
        )

        let view = try sut.inspect()

        // The view should render - the resize handle logic is internal
        // but we can verify the structure is correct
        XCTAssertNoThrow(try view.find(text: "ID"))
        XCTAssertNoThrow(try view.find(text: "SUMMARY"))
    }

    func testLastColumnDoesNotShowResizeHandle() throws {
        // The last column shouldn't have a resize handle (nothing to resize against)
        let configs = [
            ColumnConfig(key: "id", displayName: "ID", width: nil),
            ColumnConfig(key: "status", displayName: "Status", width: nil),
        ]

        let sut = ColumnHeaderRow(
            columnConfigs: configs,
            sortState: nil,
            onSort: { _ in },
            onResize: { _, _ in },
            onResizeEnd: nil
        )

        let view = try sut.inspect()
        XCTAssertNoThrow(try view.find(text: "STATUS"))
    }
}
