@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for CriteriaStripView to catch visual regressions.
///
/// CriteriaStripView displays filter and property chips in two columns.
/// These tests verify the layout and styling of the criteria strip.
final class CriteriaStripSnapshotTests: SnapshotTestCase {
    // MARK: - Helper Methods

    private func makeFilterChip(
        label: String,
        systemImage: String = "line.3.horizontal.decrease",
        tone: CriteriaChipTone = .blue
    ) -> CriteriaChip {
        CriteriaChip(kind: .filter, label: label, systemImage: systemImage, tone: tone)
    }

    private func makePropertyChip(
        label: String,
        systemImage: String = "checklist",
        tone: CriteriaChipTone = .teal
    ) -> CriteriaChip {
        CriteriaChip(kind: .property, label: label, systemImage: systemImage, tone: tone)
    }

    // MARK: - Empty States

    func testEmptyStrip() {
        let view = CriteriaStripView(filterChips: [], propertyChips: [])

        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    func testEmptyFiltersWithProperties() {
        let propertyChips = [
            makePropertyChip(label: "Summary"),
            makePropertyChip(label: "Project"),
        ]
        let view = CriteriaStripView(filterChips: [], propertyChips: propertyChips)

        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    func testFiltersWithEmptyProperties() {
        let filterChips = [
            makeFilterChip(label: "status:pending"),
        ]
        let view = CriteriaStripView(filterChips: filterChips, propertyChips: [])

        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    // MARK: - Single Items

    func testSingleFilter() {
        let filterChips = [
            makeFilterChip(label: "status:pending"),
        ]
        let view = CriteriaStripView(filterChips: filterChips, propertyChips: [])

        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    func testSingleProperty() {
        let propertyChips = [
            makePropertyChip(label: "Summary"),
        ]
        let view = CriteriaStripView(filterChips: [], propertyChips: propertyChips)

        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    // MARK: - Multiple Items

    func testMultipleFilters() {
        let filterChips = [
            makeFilterChip(label: "status:pending", tone: .blue),
            makeFilterChip(label: "project:backend", systemImage: "folder", tone: .green),
            makeFilterChip(label: "tag:urgent", systemImage: "tag", tone: .red),
        ]
        let view = CriteriaStripView(filterChips: filterChips, propertyChips: [])

        assertViewSnapshot(view, size: CGSize(width: 600, height: 80))
    }

    func testMultipleProperties() {
        let propertyChips = [
            makePropertyChip(label: "Summary"),
            makePropertyChip(label: "Project", systemImage: "folder"),
            makePropertyChip(label: "Tags", systemImage: "tag"),
            makePropertyChip(label: "Due Date", systemImage: "calendar"),
        ]
        let view = CriteriaStripView(filterChips: [], propertyChips: propertyChips)

        assertViewSnapshot(view, size: CGSize(width: 600, height: 80))
    }

    // MARK: - Mixed Content

    func testMixedContent() {
        let filterChips = [
            makeFilterChip(label: "status:active", tone: .blue),
            makeFilterChip(label: "project:api", systemImage: "folder", tone: .green),
        ]
        let propertyChips = [
            makePropertyChip(label: "Summary"),
            makePropertyChip(label: "Tags", systemImage: "tag"),
        ]
        let view = CriteriaStripView(filterChips: filterChips, propertyChips: propertyChips)

        assertViewSnapshot(view, size: TestSizes.criteriaStrip)
    }

    func testFullContent() {
        let filterChips = [
            makeFilterChip(label: "status:pending", tone: .blue),
            makeFilterChip(label: "project:frontend", systemImage: "folder", tone: .green),
            makeFilterChip(label: "tag:feature", systemImage: "tag", tone: .peach),
            makeFilterChip(label: "+urgent", systemImage: "exclamationmark.triangle", tone: .red),
        ]
        let propertyChips = [
            makePropertyChip(label: "Summary"),
            makePropertyChip(label: "Project", systemImage: "folder"),
            makePropertyChip(label: "Tags", systemImage: "tag"),
            makePropertyChip(label: "Due", systemImage: "calendar"),
            makePropertyChip(label: "Urgency", systemImage: "flame"),
        ]
        let view = CriteriaStripView(filterChips: filterChips, propertyChips: propertyChips)

        assertViewSnapshot(view, size: CGSize(width: 700, height: 100))
    }

    // MARK: - Tone Variations

    func testDifferentTones() {
        let filterChips = [
            makeFilterChip(label: "blue", tone: .blue),
            makeFilterChip(label: "teal", tone: .teal),
            makeFilterChip(label: "green", tone: .green),
            makeFilterChip(label: "yellow", tone: .yellow),
            makeFilterChip(label: "peach", tone: .peach),
            makeFilterChip(label: "red", tone: .red),
        ]
        let view = CriteriaStripView(filterChips: filterChips, propertyChips: [])

        assertViewSnapshot(view, size: CGSize(width: 600, height: 100))
    }

    func testAllTones() {
        let filterChips = [
            makeFilterChip(label: "blue", tone: .blue),
            makeFilterChip(label: "teal", tone: .teal),
            makeFilterChip(label: "green", tone: .green),
            makeFilterChip(label: "yellow", tone: .yellow),
            makeFilterChip(label: "peach", tone: .peach),
            makeFilterChip(label: "mauve", tone: .mauve),
            makeFilterChip(label: "lavender", tone: .lavender),
            makeFilterChip(label: "pink", tone: .pink),
            makeFilterChip(label: "sky", tone: .sky),
            makeFilterChip(label: "rosewater", tone: .rosewater),
            makeFilterChip(label: "red", tone: .red),
        ]
        let view = CriteriaStripView(filterChips: filterChips, propertyChips: [])

        assertViewSnapshot(view, size: CGSize(width: 700, height: 120))
    }

    // MARK: - Long Content

    func testLongLabels() {
        let filterChips = [
            makeFilterChip(label: "status:pending OR status:active", tone: .blue),
            makeFilterChip(label: "project:very-long-project-name", systemImage: "folder", tone: .green),
        ]
        let propertyChips = [
            makePropertyChip(label: "Summary with extended description"),
        ]
        let view = CriteriaStripView(filterChips: filterChips, propertyChips: propertyChips)

        assertViewSnapshot(view, size: CGSize(width: 700, height: 80))
    }
}
