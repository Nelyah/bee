@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for CriteriaStripView to catch visual regressions.
///
/// CriteriaStripView displays filter chips (grouped by source) and property chips.
/// Report filters appear above manual filters with distinct muted styling.
final class CriteriaStripSnapshotTests: SnapshotTestCase {
    // MARK: - Helper Methods

    private func makeReportFilterChip(
        label: String,
        systemImage: String = "circle.fill",
        tone: CriteriaChipTone = .pink,
        reportName: String = "Test Report"
    ) -> CriteriaChip {
        CriteriaChip(
            kind: .filter,
            source: .report,
            label: label,
            systemImage: systemImage,
            tone: tone,
            reportName: reportName
        )
    }

    private func makeManualFilterChip(
        label: String,
        systemImage: String = "line.3.horizontal.decrease",
        tone: CriteriaChipTone = .blue
    ) -> CriteriaChip {
        CriteriaChip(
            kind: .filter,
            source: .manual,
            label: label,
            systemImage: systemImage,
            tone: tone
        )
    }

    private func makePropertyChip(
        label: String,
        systemImage: String = "checklist",
        tone: CriteriaChipTone = .teal
    ) -> CriteriaChip {
        CriteriaChip(kind: .property, label: label, systemImage: systemImage, tone: tone)
    }

    private func makeCriteriaStripView(
        activeReportName: String? = nil,
        reportFilterChips: [CriteriaChip] = [],
        manualFilterChips: [CriteriaChip] = [],
        propertyChips: [CriteriaChip] = []
    ) -> some View {
        CriteriaStripView(
            activeReportName: activeReportName,
            reportFilterChips: reportFilterChips,
            manualFilterChips: manualFilterChips,
            propertyChips: propertyChips
        )
        .background(ThemeManager.current.base)
    }

    // MARK: - Empty States

    func testEmptyStrip() {
        let view = makeCriteriaStripView()
        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    func testEmptyFiltersWithProperties() {
        let propertyChips = [
            makePropertyChip(label: "Summary"),
            makePropertyChip(label: "Project"),
        ]
        let view = makeCriteriaStripView(propertyChips: propertyChips)
        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    // MARK: - Report Filters Only

    func testReportFiltersOnly() {
        let reportChips = [
            makeReportFilterChip(label: "status:pending"),
            makeReportFilterChip(label: "project:backend", systemImage: "folder", tone: .mauve),
        ]
        let view = makeCriteriaStripView(
            activeReportName: "Sprint 42",
            reportFilterChips: reportChips
        )
        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    // MARK: - Manual Filters Only

    func testManualFiltersOnly() {
        let manualChips = [
            makeManualFilterChip(label: "status:pending"),
            makeManualFilterChip(label: "+urgent", systemImage: "tag", tone: .peach),
        ]
        let view = makeCriteriaStripView(manualFilterChips: manualChips)
        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    // MARK: - Grouped Layout (Report + Manual)

    func testGroupedFilters() {
        let reportChips = [
            makeReportFilterChip(label: "status:pending"),
            makeReportFilterChip(label: "project:backend", systemImage: "folder", tone: .mauve),
        ]
        let manualChips = [
            makeManualFilterChip(label: "+urgent", systemImage: "tag", tone: .peach),
        ]
        let view = makeCriteriaStripView(
            activeReportName: "Sprint 42",
            reportFilterChips: reportChips,
            manualFilterChips: manualChips
        )
        assertViewSnapshot(view, size: CGSize(width: 600, height: 120))
    }

    // MARK: - Full Content

    func testFullContent() {
        let reportChips = [
            makeReportFilterChip(label: "status:pending"),
            makeReportFilterChip(label: "project:frontend", systemImage: "folder", tone: .mauve),
        ]
        let manualChips = [
            makeManualFilterChip(label: "+urgent", systemImage: "tag", tone: .peach),
            makeManualFilterChip(label: "due:today", systemImage: "calendar", tone: .teal),
        ]
        let propertyChips = [
            makePropertyChip(label: "Summary"),
            makePropertyChip(label: "Tags", systemImage: "tag"),
        ]
        let view = makeCriteriaStripView(
            activeReportName: "Sprint 42",
            reportFilterChips: reportChips,
            manualFilterChips: manualChips,
            propertyChips: propertyChips
        )
        assertViewSnapshot(view, size: CGSize(width: 700, height: 140))
    }

    // MARK: - Visual Differentiation

    func testReportVsManualStyling() {
        // Same filter content but different sources - should look different
        let reportChips = [
            makeReportFilterChip(label: "status:pending", tone: .pink),
        ]
        let manualChips = [
            makeManualFilterChip(label: "status:active", tone: .pink),
        ]
        let view = makeCriteriaStripView(
            activeReportName: "Test Report",
            reportFilterChips: reportChips,
            manualFilterChips: manualChips
        )
        assertViewSnapshot(view, size: CGSize(width: 500, height: 120))
    }

    // MARK: - Long Labels

    func testLongReportName() {
        let reportChips = [
            makeReportFilterChip(
                label: "status:pending",
                reportName: "Very Long Report Name That Should Truncate"
            ),
        ]
        let view = makeCriteriaStripView(
            activeReportName: "Very Long Report Name That Should Truncate",
            reportFilterChips: reportChips
        )
        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }
}
