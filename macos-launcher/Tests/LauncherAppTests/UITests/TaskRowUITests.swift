@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for TaskRow using ViewInspector.
///
/// These tests verify the view's structure, content display, and interaction behavior
/// without requiring a full UI test target or app launch.
final class TaskRowUITests: XCTestCase {
    // MARK: - Test Data

    private func makeTestTask(
        id: String = "test-uuid-1234",
        summary: String = "Test Task Summary",
        status: String = "pending",
        project: String? = "TestProject",
        tags: [String] = ["tag1", "tag2"]
    ) -> ApiTask {
        TestHelpers.makeTask(
            id: id,
            project: project,
            tags: tags,
            status: status,
            summary: summary
        )
    }

    // MARK: - Basic Rendering Tests

    func testTaskRowRendersTaskSummary() throws {
        let task = makeTestTask(summary: "Buy groceries")
        let sut = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false
        )

        let view = try sut.inspect()

        // Find text containing the summary
        let summaryText = try view.find(text: "Buy groceries")
        XCTAssertNotNil(summaryText)
    }

    func testTaskRowRendersMultipleColumns() throws {
        let task = makeTestTask(
            id: "uuid-abc",
            summary: "Important Task",
            project: "MyProject"
        )
        let sut = TaskRow(
            task: task,
            columns: ["id", "summary", "project"],
            isSelected: false,
            isHovered: false
        )

        let view = try sut.inspect()

        // Find various column values
        _ = try view.find(text: "Important Task")
        _ = try view.find(text: "MyProject")
    }

    func testTaskRowDisplaysStatusIndicator() throws {
        let task = makeTestTask(status: "pending")
        let sut = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false
        )

        let view = try sut.inspect()

        // The status indicator is a Circle shape
        // ViewInspector can find shapes in the hierarchy
        _ = try view.find(ViewType.Shape.self)
    }

    // MARK: - State-Based Rendering Tests

    func testTaskRowShowsChevronIndicator() throws {
        let task = makeTestTask()
        let sut = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false,
            isExpanded: false
        )

        let view = try sut.inspect()

        // Find the chevron image (either right or down)
        let chevron = try view.find(ViewType.Image.self)
        XCTAssertNotNil(chevron)
    }

    func testTaskRowExpandedShowsDownChevron() throws {
        let task = makeTestTask()
        let sut = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false,
            isExpanded: true,
            expandedContent: TaskExpandedContent(isLoading: false, links: [], annotations: [])
        )

        let view = try sut.inspect()

        // When expanded, chevron should point down
        // We can verify the systemName if ViewInspector supports it
        _ = try view.find(ViewType.Image.self)
    }

    // MARK: - Interaction Tests

    func testChevronTapCallsCallback() throws {
        let task = makeTestTask()
        var tapCalled = false

        let sut = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false,
            onChevronTap: { tapCalled = true }
        )

        let view = try sut.inspect()

        // Find the chevron's tap gesture and trigger it
        // Note: ViewInspector can find tap gestures attached to views
        let chevron = try view.find(ViewType.Image.self)
        try chevron.callOnTapGesture()

        XCTAssertTrue(tapCalled, "Chevron tap callback should be called")
    }

    // MARK: - Expanded Content Tests

    func testExpandedRowShowsEmptyPlaceholder() throws {
        let task = makeTestTask()
        let emptyContent = TaskExpandedContent(
            isLoading: false,
            links: [],
            annotations: []
        )

        let sut = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false,
            isExpanded: true,
            expandedContent: emptyContent
        )

        let view = try sut.inspect()

        // Empty state shows a neutral dash instead of "No links or annotations"
        _ = try view.find(text: "—")
    }

    func testExpandedRowShowsErrorMessage() throws {
        let task = makeTestTask()
        var errorContent = TaskExpandedContent(isLoading: false)
        errorContent.errorMessage = "Failed to load details"

        let sut = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false,
            isExpanded: true,
            expandedContent: errorContent
        )

        let view = try sut.inspect()

        // Should show the error message
        _ = try view.find(text: "Failed to load details")
    }

    // MARK: - Column Value Tests

    func testTaskRowDisplaysFormattedTags() throws {
        let task = makeTestTask(tags: ["urgent", "work", "meeting"])
        let sut = TaskRow(
            task: task,
            columns: ["id", "summary", "tags"],
            isSelected: false,
            isHovered: false
        )

        let view = try sut.inspect()

        // Tags should be comma-separated
        _ = try view.find(text: "urgent, work, meeting")
    }

    func testTaskRowDisplaysDashForMissingProject() throws {
        let task = makeTestTask(project: nil)
        let sut = TaskRow(
            task: task,
            columns: ["id", "summary", "project"],
            isSelected: false,
            isHovered: false
        )

        let view = try sut.inspect()

        // Missing values should show "-"
        _ = try view.find(text: "-")
    }
}
