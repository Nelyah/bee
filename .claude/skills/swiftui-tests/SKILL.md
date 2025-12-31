---
name: swiftui-tests
description: Write SwiftUI UI tests using ViewInspector for behavior testing and swift-snapshot-testing for visual regression testing. Use this skill when asked to write UI tests, view tests, snapshot tests, or test SwiftUI views in the macos-launcher.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__serena__*, mcp__context7__*
---

# SwiftUI UI Testing Guide

This skill helps you write UI tests for SwiftUI views in the `macos-launcher` project using two complementary frameworks:

1. **ViewInspector** — For testing view behavior (button taps, text content, state)
2. **swift-snapshot-testing** — For visual regression testing (pixel comparisons)

## Project Setup

Dependencies are already configured in `macos-launcher/Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
]
```

## Writing ViewInspector Tests

### Step 1: Add Inspectable Conformance

Every view you want to test must conform to `Inspectable`. Add extensions in `Tests/LauncherAppTests/TestSupport/ViewInspectorExtensions.swift`:

```swift
import ViewInspector
@testable import LauncherApp

extension MyNewView: Inspectable {}
```

### Step 2: Write the Test

Create a test file following the naming convention `*UITests.swift`:

```swift
import SwiftUI
@testable import LauncherApp
import ViewInspector
import XCTest

final class MyViewUITests: XCTestCase {

    func testViewDisplaysTitle() throws {
        let sut = MyView(title: "Hello")
        let view = try sut.inspect()

        // Find text by content
        _ = try view.find(text: "Hello")
    }

    func testButtonTapTriggersAction() throws {
        var actionCalled = false
        let sut = MyView(onTap: { actionCalled = true })

        let view = try sut.inspect()
        let button = try view.find(ViewType.Button.self)
        try button.tap()

        XCTAssertTrue(actionCalled)
    }

    func testViewContainsImage() throws {
        let sut = MyView()
        let view = try sut.inspect()

        _ = try view.find(ViewType.Image.self)
    }
}
```

### Common ViewInspector Patterns

| Task | Code |
|------|------|
| Find text | `try view.find(text: "Hello")` |
| Find button and tap | `try view.find(ViewType.Button.self).tap()` |
| Find image | `try view.find(ViewType.Image.self)` |
| Find shape | `try view.find(ViewType.Shape.self)` |
| Find by type | `try view.find(ViewType.TextField.self)` |
| Call onTapGesture | `try view.callOnTapGesture()` |
| Get actual view | `try view.actualView()` |

## Writing Snapshot Tests

### Step 1: Create Test Class

Extend `SnapshotTestCase` from `Tests/LauncherAppTests/TestSupport/SnapshotTestCase.swift`:

```swift
import SnapshotTesting
import SwiftUI
@testable import LauncherApp
import XCTest

final class MyViewSnapshotTests: SnapshotTestCase {

    func testDefaultState() {
        let view = MyView(title: "Test")
        assertViewSnapshot(view, size: CGSize(width: 400, height: 100))
    }

    func testSelectedState() {
        let view = MyView(title: "Test", isSelected: true)
        assertViewSnapshot(view, size: CGSize(width: 400, height: 100))
    }
}
```

### Step 2: Record Reference Images

On first run, tests will "fail" and record reference images to `__Snapshots__/` directories. Run tests again to verify they pass against the recorded references.

### Common Test Sizes

Use predefined sizes from `SnapshotTestCase.TestSizes`:

```swift
TestSizes.compact        // CGSize(width: 300, height: 400)
TestSizes.regular        // CGSize(width: 520, height: 600)
TestSizes.wide           // CGSize(width: 800, height: 600)
TestSizes.taskRow        // CGSize(width: 600, height: 60)
TestSizes.taskRowExpanded // CGSize(width: 600, height: 150)
TestSizes.commandPalette // CGSize(width: 520, height: 400)
```

### Re-recording Snapshots

To update reference images after intentional UI changes:

1. Set `isRecording = true` in your test class:
   ```swift
   override var isRecording: Bool { true }
   ```
2. Run tests to record new references
3. Set back to `false` and commit the new snapshots

## File Organization

```
Tests/LauncherAppTests/
├── TestSupport/
│   ├── TestHelpers.swift           # Test data factories
│   ├── ViewInspectorExtensions.swift # Inspectable conformances
│   └── SnapshotTestCase.swift      # Snapshot test base class
├── MyViewUITests.swift             # ViewInspector behavior tests
├── MyViewSnapshotTests.swift       # Snapshot visual tests
└── __Snapshots__/
    └── MyViewSnapshotTests/        # Reference images (auto-created)
        ├── testDefaultState.1.png
        └── testSelectedState.1.png
```

## Running Tests

```bash
# Run all tests
swift test

# Run specific test class
swift test --filter "MyViewUITests"

# Run specific test method
swift test --filter "MyViewUITests/testButtonTapTriggersAction"
```

## When to Use Each Approach

| Use Case | Framework |
|----------|-----------|
| Testing button/gesture callbacks | ViewInspector |
| Verifying text content | ViewInspector |
| Testing state changes | ViewInspector |
| Checking view hierarchy | ViewInspector |
| Detecting layout regressions | Snapshot |
| Verifying styling/theming | Snapshot |
| Testing responsive layouts | Snapshot (multiple sizes) |
| Documenting UI states | Snapshot |

## Tips

1. **Keep tests fast** — ViewInspector tests run in milliseconds; prefer them for logic
2. **Use meaningful snapshot names** — The test method name becomes the file name
3. **Test states, not implementation** — Focus on what users see, not internal structure
4. **Commit snapshots to git** — Reference images should be version controlled
5. **Review snapshot diffs in PRs** — Visual changes should be intentional
