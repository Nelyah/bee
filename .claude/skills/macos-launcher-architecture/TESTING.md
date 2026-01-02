# Testing Guide

**Read this when:** Writing UI tests (ViewInspector) or snapshot tests.

## Testing Frameworks

| Framework | Purpose | Test Type |
|-----------|---------|-----------|
| **ViewInspector** | Behavior testing | Button taps, state changes, content verification |
| **swift-snapshot-testing** | Visual regression | Layout, styling, pixel-perfect comparisons |

## Test File Organization

```
Tests/LauncherAppTests/
├── TestSupport/
│   ├── SnapshotTestCase.swift      # Base class for snapshots
│   ├── TestHelpers.swift           # Test data factories
│   └── ViewInspectorExtensions.swift
├── UITests/
│   ├── ContentViewUITests.swift
│   ├── TaskListViewUITests.swift
│   └── TaskRowUITests.swift
├── SnapshotTests/
│   ├── ContentViewSnapshotTests.swift
│   ├── TaskRowSnapshotTests.swift
│   └── __Snapshots__/              # Reference images (auto-created)
└── UnitTests/
    ├── ViewModelTests.swift
    └── CoordinatorTests.swift
```

## ViewInspector Testing

### Basic Pattern

```swift
import SwiftUI
@testable import LauncherApp
import ViewInspector
import XCTest

final class MyViewUITests: XCTestCase {

    func testDisplaysContent() throws {
        let sut = MyView(title: "Hello")
        let view = try sut.inspect()

        // Find text by content
        _ = try view.find(text: "Hello")
    }

    func testButtonTriggersAction() throws {
        var actionCalled = false
        let sut = MyView(onTap: { actionCalled = true })

        let view = try sut.inspect()
        let button = try view.find(ViewType.Button.self)
        try button.tap()

        XCTAssertTrue(actionCalled)
    }
}
```

### Common Inspection Methods

| Task | Code |
|------|------|
| Find text | `try view.find(text: "Hello")` |
| Find button and tap | `try view.find(ViewType.Button.self).tap()` |
| Find image | `try view.find(ViewType.Image.self)` |
| Find by type | `try view.find(ViewType.TextField.self)` |
| Call onTapGesture | `try view.callOnTapGesture()` |
| Get actual view | `try view.actualView()` |
| Find by identifier | `try view.find(viewWithAccessibilityIdentifier: "myId")` |

### Gotcha: Button Finding Fragility

**Problem:** `find(ViewType.Button.self)` returns the FIRST button in the view hierarchy. Adding new buttons (e.g., collapsible section headers) can break existing tests.

```swift
// Fragile - will break if a new button is added before "Back"
let button = try view.find(ViewType.Button.self)
try button.tap()

// Robust - finds the specific button by its content
let backButton = try view.find(ViewType.Button.self, where: { button in
    (try? button.find(text: "Back")) != nil
})
try backButton.tap()
```

**Rule:** When testing button taps, use the `where:` parameter to identify the specific button by its label, icon, or other distinguishing content.

### Testing with ViewModel

```swift
func testViewModelIntegration() throws {
    let viewModel = LauncherViewModel(
        apiClient: MockApiClient(),
        settingsService: MockSettingsService()
    )
    viewModel.input = "test input"

    let sut = ContentView(viewModel: viewModel)
    let view = try sut.inspect()

    // Verify view reflects ViewModel state
    let textField = try view.find(ViewType.TextField.self)
    XCTAssertEqual(try textField.input(), "test input")
}
```

## Snapshot Testing

### Basic Pattern

```swift
import SnapshotTesting
import SwiftUI
@testable import LauncherApp
import XCTest

final class MyViewSnapshotTests: SnapshotTestCase {

    func testDefaultState() {
        let view = MyView(title: "Test")
        assertViewSnapshot(view, size: TestSizes.compact)
    }

    func testSelectedState() {
        let view = MyView(title: "Test", isSelected: true)
        assertViewSnapshot(view, size: TestSizes.compact)
    }

    func testMultipleSizes() {
        let view = MyView(title: "Test")

        assertViewSnapshot(view, size: TestSizes.compact, named: "compact")
        assertViewSnapshot(view, size: TestSizes.regular, named: "regular")
        assertViewSnapshot(view, size: TestSizes.wide, named: "wide")
    }
}
```

### Standard Test Sizes

```swift
// From SnapshotTestCase
enum TestSizes {
    static let compact = CGSize(width: 300, height: 400)
    static let regular = CGSize(width: 520, height: 600)
    static let wide = CGSize(width: 800, height: 600)
    static let taskRow = CGSize(width: 600, height: 60)
    static let taskRowExpanded = CGSize(width: 600, height: 150)
    static let commandPalette = CGSize(width: 520, height: 400)
}
```

### Recording New Snapshots

**First time (or after intentional UI changes):**

1. Set `isRecording = true` in test class:
   ```swift
   override var isRecording: Bool { true }
   ```

2. Run tests to record reference images

3. Set back to `false`:
   ```swift
   override var isRecording: Bool { false }
   ```

4. Run tests again to verify they pass

5. Commit snapshot files to git

### Snapshot File Location

```
Tests/LauncherAppTests/SnapshotTests/__Snapshots__/
└── MyViewSnapshotTests/
    ├── testDefaultState.1.png
    └── testSelectedState.1.png
```

## Test Helpers

### Creating Test Data

```swift
// TestSupport/TestHelpers.swift

enum TestHelpers {
    static func makeTask(
        title: String = "Test Task",
        status: TaskStatus = .pending,
        tags: [String] = []
    ) -> ApiTask {
        ApiTask(
            uuid: UUID(),
            title: title,
            status: status,
            tags: tags,
            // ... other properties with defaults
        )
    }

    static func makeViewModel(
        tasks: [ApiTask] = []
    ) -> LauncherViewModel {
        let mock = MockApiClient()
        mock.tasks = tasks
        return LauncherViewModel(
            apiClient: mock,
            settingsService: MockSettingsService()
        )
    }
}
```

### Using in Tests

```swift
func testWithMultipleTasks() throws {
    let tasks = [
        TestHelpers.makeTask(title: "Task 1"),
        TestHelpers.makeTask(title: "Task 2"),
        TestHelpers.makeTask(title: "Task 3")
    ]
    let viewModel = TestHelpers.makeViewModel(tasks: tasks)

    // ... test
}
```

## Running Tests

```bash
# All tests
swift test

# Specific test file
swift test --filter "TaskRowUITests"

# Specific test method
swift test --filter "TaskRowUITests/testDisplaysTitle"

# Snapshot tests only
swift test --filter "SnapshotTests"

# UI tests only
swift test --filter "UITests"
```

## When to Use Each Type

| Use Case | Test Type |
|----------|-----------|
| Button triggers action | ViewInspector |
| Text displays correctly | ViewInspector |
| State changes propagate | ViewInspector |
| View hierarchy structure | ViewInspector |
| Layout looks correct | Snapshot |
| Styling/colors correct | Snapshot |
| Responsive layouts | Snapshot (multiple sizes) |
| Visual regression detection | Snapshot |

## Troubleshooting

### "Inspectable" Deprecation Warnings

As of ViewInspector 0.10.0+, `Inspectable` conformance is **not required**. Existing extensions in `ViewInspectorExtensions.swift` are legacy and can be ignored.

### Snapshot Failures

1. Check if UI intentionally changed → re-record
2. Check for non-deterministic content (dates, random IDs)
3. Ensure test runs on consistent macOS version

### Flaky Tests

- Use `XCTWaiter` for async operations
- Avoid timing-dependent assertions
- Use deterministic test data
