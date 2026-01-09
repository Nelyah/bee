@testable import LauncherAppKit
import XCTest

/// Tests for column resizing behavior, particularly around flex columns
/// and the interaction between adjacent columns.
@MainActor
final class ColumnResizeTests: XCTestCase {
    private var viewModel: LauncherViewModel!

    override func setUp() {
        super.setUp()
        viewModel = LauncherViewModel(apiClient: MockApiClient())
        // Set up columns: ID (fixed), SUMMARY (flex), DUE (fixed), TAGS (fixed)
        viewModel.columnConfigs = [
            ColumnConfig(key: "id", displayName: "ID", width: 50),
            ColumnConfig(key: "summary", displayName: "Summary", width: nil), // Flex
            ColumnConfig(key: "date_due", displayName: "Due", width: 80),
            ColumnConfig(key: "tags", displayName: "Tags", width: 80),
        ]
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - isFlex Logic Tests

    func testSummaryColumnIsFlexWhenWidthIsNil() {
        let config = ColumnConfig(key: "summary", displayName: "Summary", width: nil)
        XCTAssertTrue(config.isFlex, "Summary column with nil width should be flex")
    }

    func testSummaryColumnIsNotFlexWhenWidthIsSet() {
        // After manual resize, summary should have a width and no longer be flex
        let config = ColumnConfig(key: "summary", displayName: "Summary", width: 200)
        XCTAssertFalse(config.isFlex, "Summary column with explicit width should not be flex")
    }

    func testNonSummaryColumnIsNeverFlex() {
        let config = ColumnConfig(key: "status", displayName: "Status", width: nil)
        XCTAssertFalse(config.isFlex, "Non-summary column should never be flex")
    }

    // MARK: - Single Column Resize Tests

    func testResizeColumnUpdatesWidth() {
        let initialWidth = viewModel.columnConfigs[2].effectiveWidth // DUE column
        XCTAssertEqual(initialWidth, 80)

        viewModel.resizeColumn("date_due", delta: 20)

        XCTAssertEqual(viewModel.columnConfigs[2].width, 100)
        viewModel.finishResizing("date_due")
    }

    func testResizeColumnEnforcesMinimumWidth() {
        viewModel.resizeColumn("date_due", delta: -1000) // Try to make it very small

        let minWidth = ColumnConfig.minimumWidth(for: "date_due")
        XCTAssertEqual(viewModel.columnConfigs[2].width, minWidth)
        viewModel.finishResizing("date_due")
    }

    // MARK: - Dual Column Resize Tests (NEW BEHAVIOR)

    /// When dragging the separator between two columns, both should be affected.
    /// This test will FAIL until we implement resizeColumnBoundary.
    func testResizeColumnBoundaryAffectsBothColumns() {
        // Arrange: DUE is at index 2, TAGS is at index 3
        let dueInitialWidth = viewModel.columnConfigs[2].effectiveWidth
        let tagsInitialWidth = viewModel.columnConfigs[3].effectiveWidth
        XCTAssertEqual(dueInitialWidth, 80)
        XCTAssertEqual(tagsInitialWidth, 80)

        // Act: Drag the boundary between DUE and TAGS to the right by 20px
        viewModel.resizeColumnBoundary(leftColumn: "date_due", rightColumn: "tags", delta: 20)

        // Assert: DUE grows, TAGS shrinks
        XCTAssertEqual(viewModel.columnConfigs[2].width, 100, "Left column should grow")
        XCTAssertEqual(viewModel.columnConfigs[3].width, 60, "Right column should shrink")

        viewModel.finishResizing("date_due")
    }

    /// When dragging boundary left, left column shrinks and right column grows.
    func testResizeColumnBoundaryLeftwardAffectsBothColumns() {
        viewModel.resizeColumnBoundary(leftColumn: "date_due", rightColumn: "tags", delta: -20)

        let minWidth = ColumnConfig.minimumWidth(for: "date_due")
        XCTAssertEqual(viewModel.columnConfigs[2].width, max(minWidth, 60), "Left column should shrink")
        XCTAssertEqual(viewModel.columnConfigs[3].width, 100, "Right column should grow")

        viewModel.finishResizing("date_due")
    }

    /// When right column is nil (last column), only left column is affected.
    func testResizeColumnBoundaryWithNilRightColumn() {
        // TAGS is the last column, so dragging its right edge has no right column
        let tagsInitialWidth = viewModel.columnConfigs[3].effectiveWidth

        viewModel.resizeColumnBoundary(leftColumn: "tags", rightColumn: nil, delta: 20)

        XCTAssertEqual(viewModel.columnConfigs[3].width, tagsInitialWidth + 20)
        viewModel.finishResizing("tags")
    }

    // MARK: - Flex Column Conversion Tests (NEW BEHAVIOR)

    /// When resizing a flex column directly, it should convert to fixed width.
    /// The flex column's starting width is calculated from its effective width.
    func testResizingFlexColumnConvertsToFixed() {
        // SUMMARY is at index 1 (between ID and DUE)
        XCTAssertTrue(viewModel.columnConfigs[1].isFlex)
        XCTAssertNil(viewModel.columnConfigs[1].width, "Flex column should have nil width initially")

        // Resize SUMMARY directly (drag delta of +50)
        viewModel.resizeColumn("summary", delta: 50)

        // After resize, SUMMARY should have an explicit width
        XCTAssertNotNil(viewModel.columnConfigs[1].width, "Flex column should have explicit width after resize")
        XCTAssertFalse(viewModel.columnConfigs[1].isFlex, "Flex column should convert to fixed after resize")

        viewModel.finishResizing("summary")
    }

    /// Flex column resize respects minimum width.
    func testResizingFlexColumnRespectsMinimum() {
        // SUMMARY is at index 1
        XCTAssertTrue(viewModel.columnConfigs[1].isFlex)

        // Try to resize SUMMARY to very small size
        viewModel.resizeColumn("summary", delta: -1000)

        let minWidth = ColumnConfig.minimumWidth(for: "summary")
        XCTAssertEqual(viewModel.columnConfigs[1].width, minWidth, "Flex column should not go below minimum")

        viewModel.finishResizing("summary")
    }

    // MARK: - Minimum Width Enforcement in Boundary Resize

    func testResizeColumnBoundaryEnforcesMinimumOnBothColumns() {
        // Try to shrink both columns below minimum
        viewModel.resizeColumnBoundary(leftColumn: "date_due", rightColumn: "tags", delta: -1000)

        let minWidth = ColumnConfig.minimumWidth(for: "date_due")
        XCTAssertGreaterThanOrEqual(
            viewModel.columnConfigs[2].width ?? 0,
            minWidth,
            "Left column should not go below minimum"
        )

        viewModel.finishResizing("date_due")
    }
}
