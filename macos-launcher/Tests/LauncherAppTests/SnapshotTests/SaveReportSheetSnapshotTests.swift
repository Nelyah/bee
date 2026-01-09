@testable import LauncherAppKit
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for SaveReportSheet to catch visual regressions.
///
/// These tests capture the visual appearance of the save report sheet
/// in various configurations.
final class SaveReportSheetSnapshotTests: SnapshotTestCase {
    // MARK: - Test Setup

    private func makeSUT(
        currentFilter: JSONValue? = nil,
        filterChipLabels: [String] = [],
        currentColumns: [String] = ["summary", "project"],
        currentColumnNames: [String] = ["Summary", "Project"],
        staticReportNames: Set<String> = [],
        existingUserReportNames: Set<String> = []
    ) -> SaveReportSheet {
        SaveReportSheet(
            isPresented: .constant(true),
            currentFilter: currentFilter,
            filterChipLabels: filterChipLabels,
            currentColumns: currentColumns,
            currentColumnNames: currentColumnNames,
            staticReportNames: staticReportNames,
            existingUserReportNames: existingUserReportNames,
            onSave: { _, _, _, _ in }
        )
    }

    // MARK: - Default State

    func testDefaultState() {
        let sut = makeSUT()

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }

    // MARK: - Filter Variations

    func testWithNoFilters() {
        let sut = makeSUT(filterChipLabels: [])

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }

    func testWithSingleFilter() {
        let sut = makeSUT(filterChipLabels: ["status:pending"])

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }

    func testWithMultipleFilters() {
        let sut = makeSUT(filterChipLabels: ["status:pending", "project:api", "+urgent"])

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }

    func testWithManyFilters() {
        let sut = makeSUT(
            filterChipLabels: [
                "status:active",
                "project:frontend",
                "+high-priority",
                "tag:feature",
                "assigned:me",
            ]
        )

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }

    // MARK: - Column Variations

    func testWithMinimalColumns() {
        let sut = makeSUT(
            currentColumns: ["summary"],
            currentColumnNames: ["Summary"]
        )

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }

    func testWithTypicalColumns() {
        let sut = makeSUT(
            currentColumns: ["summary", "project", "tags", "due"],
            currentColumnNames: ["Summary", "Project", "Tags", "Due Date"]
        )

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }

    func testWithManyColumns() {
        let sut = makeSUT(
            currentColumns: ["summary", "project", "tags", "due", "urgency", "created", "status"],
            currentColumnNames: ["Summary", "Project", "Tags", "Due Date", "Urgency", "Created", "Status"]
        )

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }

    // MARK: - Combined Content

    func testWithFiltersAndColumns() {
        let sut = makeSUT(
            filterChipLabels: ["status:pending", "project:backend"],
            currentColumns: ["summary", "project", "tags"],
            currentColumnNames: ["Summary", "Project", "Tags"]
        )

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }

    func testFullContent() {
        let sut = makeSUT(
            filterChipLabels: ["status:active", "project:api", "+urgent", "tag:feature"],
            currentColumns: ["summary", "project", "tags", "due", "urgency"],
            currentColumnNames: ["Summary", "Project", "Tags", "Due Date", "Urgency"]
        )

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 340))
    }
}
