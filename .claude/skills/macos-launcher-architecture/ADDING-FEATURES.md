# Adding Features to macOS Launcher

**Read this when:** Adding new functionality end-to-end.

## Feature Addition Workflow

### Step 1: Plan the Feature

Identify which layers need changes:
- [ ] **State**: New `@Published` properties in ViewModel?
- [ ] **Logic**: New methods in ViewModel extension?
- [ ] **View**: New view or modifications to existing?
- [ ] **Service**: New API calls or settings?
- [ ] **Tests**: Behavior tests + snapshot tests?

### Step 2: Add State to ViewModel

Choose the appropriate extension or create new one:

```swift
// In LauncherViewModel+YourFeature.swift
extension LauncherViewModel {

    // State
    @Published var featureEnabled: Bool = false

    // Logic
    func enableFeature() {
        featureEnabled = true
        // Persist if needed
        settingsService.setFeatureEnabled(true)
    }
}
```

**Extension naming**: `LauncherViewModel+{Feature}.swift`

### Step 3: Create/Modify Views

Views observe ViewModel via `@ObservedObject`:

```swift
struct FeatureView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        if viewModel.featureEnabled {
            FeatureContent()
        }
    }
}
```

**File location**:
- New views: `Views/YourFeatureView.swift`
- Reusable components: `Views/Components/YourComponent.swift`

### Step 4: Add Service Methods (if needed)

If you need new API calls or settings:

```swift
// Protocol (Networking/ApiClientProtocol.swift)
protocol ApiClientProtocol {
    func fetchFeatureData() async throws -> FeatureResponse
}

// Implementation (Networking/ApiClient.swift)
extension ApiClient: ApiClientProtocol {
    func fetchFeatureData() async throws -> FeatureResponse {
        // Implementation
    }
}

// Mock (for testing)
class MockApiClient: ApiClientProtocol {
    var fetchFeatureDataResult: Result<FeatureResponse, Error> = .success(FeatureResponse())

    func fetchFeatureData() async throws -> FeatureResponse {
        try fetchFeatureDataResult.get()
    }
}
```

### Step 5: Add Tests

**Behavior test (ViewInspector):**

```swift
// Tests/LauncherAppTests/UITests/FeatureViewUITests.swift
final class FeatureViewUITests: XCTestCase {

    func testFeatureToggle() throws {
        let viewModel = LauncherViewModel(
            apiClient: MockApiClient(),
            settingsService: MockSettingsService()
        )
        let sut = FeatureView(viewModel: viewModel)

        XCTAssertFalse(viewModel.featureEnabled)

        // Trigger action
        viewModel.enableFeature()

        XCTAssertTrue(viewModel.featureEnabled)
    }
}
```

**Snapshot test:**

```swift
// Tests/LauncherAppTests/SnapshotTests/FeatureViewSnapshotTests.swift
final class FeatureViewSnapshotTests: SnapshotTestCase {

    func testEnabledState() {
        let viewModel = makeViewModel()
        viewModel.featureEnabled = true

        let view = FeatureView(viewModel: viewModel)
        assertViewSnapshot(view, size: TestSizes.compact)
    }

    func testDisabledState() {
        let viewModel = makeViewModel()
        viewModel.featureEnabled = false

        let view = FeatureView(viewModel: viewModel)
        assertViewSnapshot(view, size: TestSizes.compact)
    }
}
```

### Step 6: Run Tests

```bash
# All tests
swift test

# Specific test class
swift test --filter "FeatureViewUITests"

# Record new snapshots (first run or after intentional changes)
# Set isRecording = true in test class, run, then set back to false
```

## Complete Example: Adding a "Favorites" Feature

### 1. State (LauncherViewModel+Favorites.swift)

```swift
extension LauncherViewModel {
    @Published var favoriteTaskIds: Set<UUID> = []
    @Published var showOnlyFavorites: Bool = false

    func toggleFavorite(taskId: UUID) {
        if favoriteTaskIds.contains(taskId) {
            favoriteTaskIds.remove(taskId)
        } else {
            favoriteTaskIds.insert(taskId)
        }
        settingsService.setFavoriteTaskIds(favoriteTaskIds)
    }

    func toggleShowOnlyFavorites() {
        showOnlyFavorites.toggle()
    }

    var displayedTasks: [ApiTask] {
        if showOnlyFavorites {
            return tasks.filter { favoriteTaskIds.contains($0.uuid) }
        }
        return tasks
    }
}
```

### 2. View (FavoriteButton.swift)

```swift
struct FavoriteButton: View {
    @ObservedObject var viewModel: LauncherViewModel
    let taskId: UUID

    private var isFavorite: Bool {
        viewModel.favoriteTaskIds.contains(taskId)
    }

    var body: some View {
        Button(action: { viewModel.toggleFavorite(taskId: taskId) }) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundColor(isFavorite ? .yellow : .gray)
        }
        .buttonStyle(.plain)
    }
}
```

### 3. Integration (TaskRow.swift modification)

```swift
// Add to TaskRow
HStack {
    FavoriteButton(viewModel: viewModel, taskId: task.uuid)
    // ... existing content
}
```

### 4. Settings Protocol Update

```swift
// SettingsServiceProtocol
func getFavoriteTaskIds() -> Set<UUID>
func setFavoriteTaskIds(_ ids: Set<UUID>)

// MockSettingsService
var favoriteTaskIds: Set<UUID> = []
func getFavoriteTaskIds() -> Set<UUID> { favoriteTaskIds }
func setFavoriteTaskIds(_ ids: Set<UUID>) { favoriteTaskIds = ids }
```

### 5. Tests

```swift
// UITests/FavoriteButtonUITests.swift
func testToggleFavorite() throws {
    let viewModel = makeViewModel()
    let taskId = UUID()

    XCTAssertFalse(viewModel.favoriteTaskIds.contains(taskId))

    viewModel.toggleFavorite(taskId: taskId)
    XCTAssertTrue(viewModel.favoriteTaskIds.contains(taskId))

    viewModel.toggleFavorite(taskId: taskId)
    XCTAssertFalse(viewModel.favoriteTaskIds.contains(taskId))
}

// SnapshotTests/FavoriteButtonSnapshotTests.swift
func testFavorited() {
    let viewModel = makeViewModel()
    viewModel.favoriteTaskIds = [testTaskId]

    let view = FavoriteButton(viewModel: viewModel, taskId: testTaskId)
    assertViewSnapshot(view, size: CGSize(width: 40, height: 40))
}
```

## Checklist

- [ ] State added to ViewModel (or extension)
- [ ] Views created/modified
- [ ] Protocol updated if new service methods needed
- [ ] Mock updated for testing
- [ ] Behavior tests written (ViewInspector)
- [ ] Snapshot tests written (record + verify)
- [ ] All tests passing (`swift test`)
