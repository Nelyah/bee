# ViewModel Patterns

**Read this when:** Working on LauncherViewModel state management.

## LauncherViewModel Structure

The ViewModel is the central state coordinator, split across multiple files:

```
ViewModels/
├── LauncherViewModel.swift              # Core state, initialization
├── LauncherViewModel+Reports.swift      # Report selection
├── LauncherViewModel+Grouping.swift     # Task grouping
├── LauncherViewModel+Selection.swift
├── LauncherViewModel+Completion.swift
├── LauncherViewModel+TaskDetail.swift
├── LauncherViewModel+TaskExpansion.swift
├── LauncherViewModel+CommandPalette.swift
├── LauncherViewModel+Toast.swift
├── LauncherViewModel+Navigation.swift   # Navigation stack, back navigation
└── LauncherViewModel+KeyboardHandling.swift
```

## State Declaration Patterns

### Published Properties

```swift
// Simple state
@Published var input: String = ""
@Published var isLoading: Bool = false

// Collections
@Published var tasks: [ApiTask] = []
@Published var selectedTaskIds: Set<UUID> = []

// Optional state
@Published var selectedTask: ApiTask? = nil
@Published var errorMessage: String? = nil
```

### Computed Properties

```swift
// Derived state (no storage, always computed)
var hasSelection: Bool {
    selectedTaskIds.isEmpty == false
}

var visibleTasks: [ApiTask] {
    tasks.filter { !$0.isHidden }
}
```

## Async Patterns

### Loading Data

```swift
@Published var isLoading: Bool = false
@Published var loadError: Error? = nil

func loadTasks() async {
    isLoading = true
    loadError = nil

    do {
        let response = try await apiClient.fetchTasks()
        await MainActor.run {
            self.tasks = response.tasks
            self.isLoading = false
        }
    } catch {
        await MainActor.run {
            self.loadError = error
            self.isLoading = false
        }
    }
}
```

### Task-Based Operations

```swift
private var loadTask: Task<Void, Never>?

func refresh() {
    // Cancel previous load if still running
    loadTask?.cancel()

    loadTask = Task {
        await loadTasks()
    }
}
```

### Debouncing Input

```swift
private var debounceTask: Task<Void, Never>?

func handleInputChange(_ newValue: String) {
    input = newValue

    debounceTask?.cancel()
    debounceTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        guard !Task.isCancelled else { return }
        await parseInput()
    }
}
```

## Service Integration

### Protocol-Based Injection

```swift
class LauncherViewModel: ObservableObject {
    private let apiClient: ApiClientProtocol
    private let settingsService: SettingsServiceProtocol

    init(
        apiClient: ApiClientProtocol,
        settingsService: SettingsServiceProtocol
    ) {
        self.apiClient = apiClient
        self.settingsService = settingsService

        // Load initial state from settings
        self.selectedReportId = settingsService.getSelectedReportId()
    }
}
```

### Settings Persistence

```swift
// Read on init
init(...) {
    self.groupingStrategy = settingsService.getGroupingStrategy()
}

// Write on change
func setGroupingStrategy(_ strategy: TaskGroupingStrategy) {
    self.groupingStrategy = strategy
    settingsService.setGroupingStrategy(strategy)
}
```

## Extension Patterns

### Adding a New Extension

1. Create file: `LauncherViewModel+{Feature}.swift`
2. Add extension with feature-specific state and methods:

```swift
// LauncherViewModel+Feature.swift
import Foundation

extension LauncherViewModel {

    // MARK: - State

    // Note: @Published properties must be in the main class
    // Use computed properties or methods here

    // MARK: - Actions

    func featureAction() {
        // Implementation
    }

    // MARK: - Private Helpers

    private func helperMethod() {
        // Internal logic
    }
}
```

### When to Create New Extension

Create a new extension when:
- Adding 3+ related methods
- Feature is logically distinct (e.g., "toasts", "grouping")
- Improves file organization and reduces merge conflicts

Keep in main file when:
- Core initialization logic
- Properties used across many features
- Simple one-off methods

## Combine Integration

### Publishers for Reactive Binding

```swift
import Combine

class LauncherViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    init(...) {
        // React to input changes
        $input
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.parseInput(newValue)
            }
            .store(in: &cancellables)
    }
}
```

### Cleanup

```swift
deinit {
    cancellables.removeAll()
}
```

## Common Patterns

### Loading States

```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(Error)
}

@Published var taskState: LoadingState<[ApiTask]> = .idle
```

### Selection Management

```swift
@Published var selectedIndex: Int = 0

func selectNext() {
    guard !tasks.isEmpty else { return }
    selectedIndex = min(selectedIndex + 1, tasks.count - 1)
}

func selectPrevious() {
    selectedIndex = max(selectedIndex - 1, 0)
}

var selectedTask: ApiTask? {
    guard tasks.indices.contains(selectedIndex) else { return nil }
    return tasks[selectedIndex]
}
```

### Mode/State Machines (Navigation Stack Pattern)

The app uses a **navigation stack** to track view history. Mode is derived from the stack:

```swift
// NavigationEntry represents a view in the stack
enum NavigationEntry: Equatable {
    case taskList
    case taskDetail(uuid: String, previousSelectedIndex: Int?)
    case projectOverview
}

// ViewNavigationStack manages the history
class ViewNavigationStack: ObservableObject {
    @Published private(set) var entries: [NavigationEntry] = [.taskList]

    var current: NavigationEntry { entries.last ?? .taskList }
    var canGoBack: Bool { entries.count > 1 }

    func push(_ entry: NavigationEntry) { ... }
    func pop() -> NavigationEntry? { ... }
}

// Mode is synced from the stack via Combine
class LauncherViewModel {
    let navigationStack = ViewNavigationStack()
    @Published private(set) var mode: LauncherMode = .list

    init(...) {
        navigationStack.$entries
            .map { $0.last?.mode ?? .list }
            .removeDuplicates()
            .sink { [weak self] in self?.mode = $0 }
            .store(in: &cancellables)
    }

    // Navigation via stack (NOT direct mode assignment)
    func navigateBack() -> Bool {
        guard let popped = navigationStack.pop() else { return false }
        // Restore state based on destination...
        return true
    }
}
```

**Important**: Never set `mode` directly. Use `pushTaskDetail()`, `pushProjectOverview()`, `navigateBack()`, or `navigateToRoot()`.

## Testing ViewModels

```swift
func testStateChange() {
    // Arrange
    let mockApi = MockApiClient()
    let mockSettings = MockSettingsService()
    let viewModel = LauncherViewModel(
        apiClient: mockApi,
        settingsService: mockSettings
    )

    // Act
    viewModel.someAction()

    // Assert
    XCTAssertEqual(viewModel.someState, expectedValue)
}

func testAsyncOperation() async {
    let mockApi = MockApiClient()
    mockApi.fetchTasksResult = .success([testTask])

    let viewModel = LauncherViewModel(apiClient: mockApi, ...)

    await viewModel.loadTasks()

    XCTAssertEqual(viewModel.tasks.count, 1)
    XCTAssertFalse(viewModel.isLoading)
}
```
