@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for TaskRow to catch visual regressions.
///
/// These tests capture the rendered appearance of TaskRow in various states
/// and compare against stored reference images.
///
/// ## Recording New Snapshots
/// Set `isRecording = true` in the test class or individual test,
/// then run the tests. Reference images are stored in `__Snapshots__/`.
final class TaskRowSnapshotTests: SnapshotTestCase {
    // MARK: - Test Data

    private func makeTestTask(
        dbId: Int = 1,
        summary: String = "Implement user authentication",
        status: String = "pending",
        project: String? = "Backend",
        tags: [String] = ["api", "security"]
    ) -> ApiTask {
        ApiTask(
            dbId: dbId,
            uuid: "test-uuid-12345678",
            status: status,
            summary: summary,
            project: project,
            tags: tags,
            dateCreated: "2024-01-15T10:30:00Z",
            dateCompleted: nil,
            dateDue: "2024-02-01T00:00:00Z",
            urgency: 5
        )
    }

    // MARK: - Basic States

    func testTaskRowDefault() {
        let task = makeTestTask()
        let view = TaskRow(
            task: task,
            columns: ["id", "summary", "project"],
            isSelected: false,
            isHovered: false
        )

        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRowSelected() {
        let task = makeTestTask()
        let view = TaskRow(
            task: task,
            columns: ["id", "summary", "project"],
            isSelected: true,
            isHovered: false
        )

        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRowHovered() {
        let task = makeTestTask()
        let view = TaskRow(
            task: task,
            columns: ["id", "summary", "project"],
            isSelected: false,
            isHovered: true
        )

        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRowSelectedAndHovered() {
        let task = makeTestTask()
        let view = TaskRow(
            task: task,
            columns: ["id", "summary", "project"],
            isSelected: true,
            isHovered: true
        )

        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    // MARK: - Expanded States

    func testTaskRowExpandedEmpty() {
        let task = makeTestTask()
        let content = TaskExpandedContent(
            isLoading: false,
            links: [],
            annotations: []
        )

        let view = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false,
            isExpanded: true,
            expandedContent: content
        )

        assertViewSnapshot(view, size: TestSizes.taskRowExpanded)
    }

    func testTaskRowExpandedWithError() {
        let task = makeTestTask()
        var content = TaskExpandedContent(isLoading: false)
        content.errorMessage = "Network error: Unable to fetch details"

        let view = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false,
            isExpanded: true,
            expandedContent: content
        )

        assertViewSnapshot(view, size: TestSizes.taskRowExpanded)
    }

    // MARK: - Column Variations

    func testTaskRowMinimalColumns() {
        let task = makeTestTask()
        let view = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false
        )

        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRowAllColumns() {
        let task = makeTestTask()
        let view = TaskRow(
            task: task,
            columns: ["id", "summary", "project", "tags", "urgency"],
            isSelected: false,
            isHovered: false
        )

        // Wider size for more columns
        assertViewSnapshot(view, size: CGSize(width: 800, height: 60))
    }

    // MARK: - Status Variations

    func testTaskRowCompletedStatus() {
        let task = ApiTask(
            dbId: 1,
            uuid: "completed-task-uuid",
            status: "completed",
            summary: "Finished task",
            project: "Done",
            tags: [],
            dateCreated: "2024-01-01T00:00:00Z",
            dateCompleted: "2024-01-10T15:30:00Z",
            dateDue: nil,
            urgency: nil
        )

        let view = TaskRow(
            task: task,
            columns: ["id", "summary", "status"],
            isSelected: false,
            isHovered: false
        )

        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    // MARK: - Edge Cases

    func testTaskRowLongSummary() {
        let task = ApiTask(
            dbId: 1,
            uuid: "long-summary-uuid",
            status: "pending",
            summary: "This is a very long task summary that should be truncated properly without breaking the layout of the task row component",
            project: "Testing",
            tags: ["overflow", "truncation", "long-text"],
            dateCreated: "2024-01-01T00:00:00Z",
            dateCompleted: nil,
            dateDue: nil,
            urgency: 10
        )

        let view = TaskRow(
            task: task,
            columns: ["id", "summary", "tags"],
            isSelected: false,
            isHovered: false
        )

        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRowNoProject() {
        let task = makeTestTask(project: nil)
        let view = TaskRow(
            task: task,
            columns: ["id", "summary", "project"],
            isSelected: false,
            isHovered: false
        )

        assertViewSnapshot(view, size: TestSizes.taskRow)
    }

    func testTaskRowNoTags() {
        let task = makeTestTask(tags: [])
        let view = TaskRow(
            task: task,
            columns: ["id", "summary", "tags"],
            isSelected: false,
            isHovered: false
        )

        assertViewSnapshot(view, size: TestSizes.taskRow)
    }
}
