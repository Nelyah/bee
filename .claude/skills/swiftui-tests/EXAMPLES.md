# SwiftUI Test Examples

Detailed examples from the macos-launcher codebase.

## ViewInspector: Testing TaskRow

```swift
import SwiftUI
@testable import LauncherApp
import ViewInspector
import XCTest

final class TaskRowUITests: XCTestCase {

    // MARK: - Test Data Factory

    private func makeTestTask(
        id: String = "test-uuid-1234",
        summary: String = "Test Task",
        status: String = "pending",
        project: String? = "TestProject",
        tags: [String] = ["tag1"]
    ) -> ApiTask {
        TestHelpers.makeTask(
            id: id,
            project: project,
            tags: tags,
            status: status,
            summary: summary
        )
    }

    // MARK: - Content Tests

    func testRendersTaskSummary() throws {
        let task = makeTestTask(summary: "Buy groceries")
        let sut = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false
        )

        let view = try sut.inspect()
        _ = try view.find(text: "Buy groceries")
    }

    func testDisplaysFormattedTags() throws {
        let task = makeTestTask(tags: ["urgent", "work"])
        let sut = TaskRow(
            task: task,
            columns: ["id", "summary", "tags"],
            isSelected: false,
            isHovered: false
        )

        let view = try sut.inspect()
        _ = try view.find(text: "urgent, work")
    }

    // MARK: - Interaction Tests

    func testChevronTapCallsCallback() throws {
        var tapCalled = false
        let task = makeTestTask()

        let sut = TaskRow(
            task: task,
            columns: ["id", "summary"],
            isSelected: false,
            isHovered: false,
            onChevronTap: { tapCalled = true }
        )

        let view = try sut.inspect()
        let chevron = try view.find(ViewType.Image.self)
        try chevron.callOnTapGesture()

        XCTAssertTrue(tapCalled)
    }

    // MARK: - State Tests

    func testExpandedRowShowsEmptyMessage() throws {
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
        _ = try view.find(text: "No links or annotations")
    }
}
```

## Snapshot Testing: Component States

```swift
import SnapshotTesting
import SwiftUI
@testable import LauncherApp
import XCTest

final class ComponentSnapshotTests: SnapshotTestCase {

    // MARK: - ToastView

    func testToastViewSuccess() {
        let toast = ToastMessage(message: "Task completed", icon: .success)
        let view = ToastView(toast: toast)
        assertViewSnapshot(view, size: CGSize(width: 300, height: 50))
    }

    func testToastViewWarning() {
        let toast = ToastMessage(message: "Connection failed", icon: .warning)
        let view = ToastView(toast: toast)
        assertViewSnapshot(view, size: CGSize(width: 300, height: 50))
    }

    // MARK: - GroupHeaderRow States

    func testGroupHeaderCollapsed() {
        let header = GroupHeader(
            key: "pending",
            displayName: "Pending Tasks",
            isCollapsed: true
        )
        let view = GroupHeaderRow(
            header: header,
            isHovered: false,
            isSelected: false
        )
        assertViewSnapshot(view, size: CGSize(width: 600, height: 40))
    }

    func testGroupHeaderExpanded() {
        let header = GroupHeader(
            key: "pending",
            displayName: "Pending Tasks",
            isCollapsed: false
        )
        let view = GroupHeaderRow(
            header: header,
            isHovered: false,
            isSelected: false
        )
        assertViewSnapshot(view, size: CGSize(width: 600, height: 40))
    }

    func testGroupHeaderHovered() {
        let header = GroupHeader(
            key: "pending",
            displayName: "Pending Tasks",
            isCollapsed: false
        )
        let view = GroupHeaderRow(
            header: header,
            isHovered: true,
            isSelected: false
        )
        assertViewSnapshot(view, size: CGSize(width: 600, height: 40))
    }

    // MARK: - LinkStatusBadge States

    func testLinkStatusPending() {
        let view = LinkStatusBadge(state: .pending, timestamp: nil)
        assertViewSnapshot(view, size: CGSize(width: 100, height: 24))
    }

    func testLinkStatusSynced() {
        let view = LinkStatusBadge(state: .synced(Date()), timestamp: nil)
        assertViewSnapshot(view, size: CGSize(width: 150, height: 24))
    }

    func testLinkStatusError() {
        let view = LinkStatusBadge(
            state: .error("Connection timeout"),
            timestamp: nil
        )
        assertViewSnapshot(view, size: CGSize(width: 100, height: 24))
    }
}
```

## Testing Multiple Sizes

```swift
func testResponsiveLayout() {
    let view = MyResponsiveView()

    assertViewSnapshots(
        view,
        sizes: [
            "compact": CGSize(width: 300, height: 200),
            "regular": CGSize(width: 500, height: 200),
            "wide": CGSize(width: 800, height: 200),
        ]
    )
}
```

## Adding New Inspectable View

When testing a new view, add its `Inspectable` conformance:

```swift
// In Tests/LauncherAppTests/TestSupport/ViewInspectorExtensions.swift

// Add at the appropriate section:
extension MyNewView: Inspectable {}
```

## Test Data Helpers

Use `TestHelpers` for creating test data:

```swift
// Create a task with defaults
let task = TestHelpers.makeTask(id: "abc123")

// Create a task with specific properties
let task = TestHelpers.makeTask(
    id: "abc123",
    urgency: 5,
    project: "Backend",
    tags: ["api", "urgent"],
    status: "pending",
    summary: "Fix authentication bug"
)
```
