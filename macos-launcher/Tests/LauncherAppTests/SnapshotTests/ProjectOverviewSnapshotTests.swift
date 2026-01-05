@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for ProjectOverview and related components.
final class ProjectOverviewSnapshotTests: SnapshotTestCase {
    // MARK: - ProjectStatsRow Tests

    func testProjectStatsRowExpanded() {
        let stats = ProjectStats(
            name: "backend",
            pendingCount: 5,
            activeCount: 2,
            completedCount: 10,
            overdueCount: 1,
            totalCount: 18
        )
        let node = ProjectNode(
            name: "backend",
            fullPath: "backend",
            stats: stats,
            children: [
                ProjectNode(
                    name: "api",
                    fullPath: "backend.api",
                    stats: ProjectStats(
                        name: "backend.api",
                        pendingCount: 2,
                        activeCount: 1,
                        completedCount: 5,
                        overdueCount: 0,
                        totalCount: 8
                    ),
                    children: []
                ),
            ]
        )

        let view = ProjectStatsRow(
            node: node,
            isExpanded: true,
            indentLevel: 0,
            onToggleExpand: {},
            onSelect: {},
            onShowBurndown: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 500, height: 50))
    }

    func testProjectStatsRowCollapsed() {
        let stats = ProjectStats(
            name: "frontend",
            pendingCount: 3,
            activeCount: 1,
            completedCount: 8,
            overdueCount: 0,
            totalCount: 12
        )
        let node = ProjectNode(
            name: "frontend",
            fullPath: "frontend",
            stats: stats,
            children: [
                ProjectNode(
                    name: "ui",
                    fullPath: "frontend.ui",
                    stats: stats,
                    children: []
                ),
            ]
        )

        let view = ProjectStatsRow(
            node: node,
            isExpanded: false,
            indentLevel: 0,
            onToggleExpand: {},
            onSelect: {},
            onShowBurndown: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 500, height: 50))
    }

    func testProjectStatsRowIndented() {
        let stats = ProjectStats(
            name: "api",
            pendingCount: 2,
            activeCount: 1,
            completedCount: 5,
            overdueCount: 0,
            totalCount: 8
        )
        let node = ProjectNode(
            name: "api",
            fullPath: "backend.api",
            stats: stats,
            children: []
        )

        let view = ProjectStatsRow(
            node: node,
            isExpanded: false,
            indentLevel: 1,
            onToggleExpand: {},
            onSelect: {},
            onShowBurndown: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 500, height: 50))
    }

    func testProjectStatsRowLeafNode() {
        let stats = ProjectStats(
            name: "helpers",
            pendingCount: 1,
            activeCount: 0,
            completedCount: 3,
            overdueCount: 0,
            totalCount: 4
        )
        let node = ProjectNode(
            name: "helpers",
            fullPath: "backend.api.helpers",
            stats: stats,
            children: []
        )

        let view = ProjectStatsRow(
            node: node,
            isExpanded: false,
            indentLevel: 2,
            onToggleExpand: {},
            onSelect: {},
            onShowBurndown: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 500, height: 50))
    }

    func testProjectStatsRowWithOverdue() {
        let stats = ProjectStats(
            name: "urgent",
            pendingCount: 2,
            activeCount: 3,
            completedCount: 5,
            overdueCount: 4,
            totalCount: 14
        )
        let node = ProjectNode(
            name: "urgent",
            fullPath: "urgent",
            stats: stats,
            children: []
        )

        let view = ProjectStatsRow(
            node: node,
            isExpanded: false,
            indentLevel: 0,
            onToggleExpand: {},
            onSelect: {},
            onShowBurndown: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 500, height: 50))
    }

    // MARK: - BurndownChartView Tests

    func testBurndownChartWithData() {
        let response = MockApiClient.sampleBurndown

        let view = BurndownChartView(data: response)

        assertViewSnapshot(view, size: CGSize(width: 500, height: 350))
    }

    func testBurndownChartEmpty() {
        let response = ProjectBurndownResponse(
            project: "empty-project",
            dataPoints: [],
            totalTasks: 0,
            totalCompleted: 0
        )

        let view = BurndownChartView(data: response)

        assertViewSnapshot(view, size: CGSize(width: 500, height: 350))
    }

    func testBurndownChartPartiallyComplete() {
        let response = ProjectBurndownResponse(
            project: "partial",
            dataPoints: [
                BurndownDataPoint(date: "2024-01-01", completedCumulative: 0, remaining: 10),
                BurndownDataPoint(date: "2024-01-15", completedCumulative: 3, remaining: 7),
                BurndownDataPoint(date: "2024-01-30", completedCumulative: 5, remaining: 5),
            ],
            totalTasks: 10,
            totalCompleted: 5
        )

        let view = BurndownChartView(data: response)

        assertViewSnapshot(view, size: CGSize(width: 500, height: 350))
    }

    // MARK: - ProjectOverviewHeader Tests

    func testProjectOverviewHeader() {
        let view = ProjectOverviewHeader(onClose: {})

        assertViewSnapshot(view, size: CGSize(width: 600, height: 60))
    }
}
