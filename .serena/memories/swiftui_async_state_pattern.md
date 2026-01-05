# SwiftUI Async State Update Pattern

## The Pattern

When updating `@Published` state inside an async `Task { }` block, any **derived state** that depends on the updated value must be explicitly rebuilt after the async update completes.

## Example Bug

```swift
// BAD: Derived state not rebuilt after async update
func loadTaskDetail(taskUUID: String) {
    Task {
        let detail = try await apiClient.fetchTaskDetail(taskUUID: taskUUID)
        taskDetailState = TaskDetailState(detail: detail)  // State updated
        // BUG: detailFocusableItems still has stale data!
    }
}
```

## Correct Pattern

```swift
// GOOD: Rebuild derived state after async update
func loadTaskDetail(taskUUID: String) {
    Task {
        let detail = try await apiClient.fetchTaskDetail(taskUUID: taskUUID)
        taskDetailState = TaskDetailState(detail: detail)
        buildDetailFocusableItems()  // Rebuild derived state
    }
}
```

## Why This Happens

SwiftUI's `@Published` triggers view updates when the property changes, but:
1. Computed properties that aggregate multiple `@Published` values won't automatically rebuild
2. Cached/derived state (like `detailFocusableItems`) needs manual refresh
3. The async context means the caller has already continued, so no automatic re-render of derived data

## Files with this pattern in bee macOS launcher

- `LauncherViewModel+TaskDetail.swift`: `loadTaskDetail()`, `loadExternalLinks()`
- `LauncherViewModel+Tags.swift`: Tag add/remove operations

## Testing

Write async tests that verify derived state is updated:

```swift
func testLoadTaskDetailRebuildsDetailFocusableItems() async throws {
    // Before loading
    XCTAssertEqual(attachmentsBefore.count, 0)
    
    viewModel.loadTaskDetail(taskUUID: uuid)
    try await Task.sleep(nanoseconds: 100_000_000) // Wait for async
    
    // After loading - derived state should be updated
    XCTAssertGreaterThan(attachmentsAfter.count, 0)
}
```
