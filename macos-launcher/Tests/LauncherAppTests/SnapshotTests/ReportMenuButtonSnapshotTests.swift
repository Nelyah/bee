@testable import LauncherAppKit
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for ReportMenuButton appearance.
///
/// Tests the report selector button with various report names
/// to verify text display and styling.
final class ReportMenuButtonSnapshotTests: SnapshotTestCase {
    // MARK: - Default State

    func testDefaultState() {
        let view = makeReportMenuButton(name: "default")
        assertViewSnapshot(view, size: TestSizes.reportMenuButton)
    }

    // MARK: - Various Report Names

    func testShortReportName() {
        let view = makeReportMenuButton(name: "all")
        assertViewSnapshot(view, size: TestSizes.reportMenuButton)
    }

    func testLongReportName() {
        let view = makeReportMenuButton(name: "My Custom Work Report")
        assertViewSnapshot(view, size: CGSize(width: 250, height: 30))
    }

    func testReportNameWithSpecialChars() {
        let view = makeReportMenuButton(name: "work-tasks")
        assertViewSnapshot(view, size: CGSize(width: 180, height: 30))
    }

    // MARK: - With Multiple Reports

    func testWithMultipleReports() {
        let reports = [
            TestHelpers.makeReportSummary(name: "default", isDefault: true),
            TestHelpers.makeReportSummary(name: "all", isDefault: false),
            TestHelpers.makeReportSummary(name: "work", isDefault: false),
        ]
        let view = makeReportMenuButton(name: "default", reports: reports)
        assertViewSnapshot(view, size: TestSizes.reportMenuButton)
    }

    // MARK: - Helper

    /// Create a ReportMenuButton with test-friendly defaults.
    private func makeReportMenuButton(
        name: String,
        reports: [ReportSummary]? = nil
    ) -> some View {
        StatefulReportMenuButton(
            name: name,
            reports: reports ?? [
                TestHelpers.makeReportSummary(name: name, isDefault: true),
            ]
        )
    }
}

/// Wrapper view that provides @State for the flash binding.
private struct StatefulReportMenuButton: View {
    @State private var flash = false

    let name: String
    let reports: [ReportSummary]

    var body: some View {
        ReportMenuButton(
            name: name,
            reports: reports,
            flash: $flash,
            onSelect: { _ in }
        )
        .padding(8)
        .background(ThemeManager.current.base)
    }
}
