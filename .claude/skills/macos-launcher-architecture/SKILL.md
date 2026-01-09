---
name: macos-launcher-architecture
description: macOS launcher SwiftUI architecture, patterns, and development workflows. Use when working on macos-launcher, SwiftUI views, ViewModels, services, command palette, keyboard navigation, vim-style shortcuts, or understanding the launcher codebase structure.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__serena__*
---

# macOS Launcher Architecture

This skill documents the architecture, patterns, and conventions for the macOS launcher (`macos-launcher/`).

## Quick Reference

| Layer | Location | Purpose |
|-------|----------|---------|
| **Xcode App** | `Bee/Bee/` | App entry, BackendManager, startup flow |
| **Views** | `Sources/.../Views/` | SwiftUI views (ContentView, TaskListView, TaskRow, etc.) |
| **ViewModels** | `Sources/.../ViewModels/` | State management (LauncherViewModel + extensions) |
| **Models** | `Sources/.../Models/` | Data structures (ApiTask, ConfigModels, etc.) |
| **Services** | `Sources/.../Utilities/Services/` | Dependency-injected services (Settings) |
| **Networking** | `Sources/.../Networking/` | ApiClient, transports (Unix socket, HTTP) |
| **Components** | `Sources/.../Views/Components/` | Reusable UI components (25+ components) |
| **Design** | `Sources/.../Utilities/Design/` | Theme, DesignTokens, StatusColor |
| **Build Scripts** | `Bee/Scripts/` | Backend compilation, resource bundling |

## Architecture Pattern: MVVM

```
┌─────────────────────────────────────────────────────────────┐
│                       Views (SwiftUI)                        │
│  ContentView → TaskListView → TaskRow → Components          │
└──────────────────────────┬──────────────────────────────────┘
                           │ @ObservedObject
┌──────────────────────────▼──────────────────────────────────┐
│                    LauncherViewModel                         │
│  @Published state, business logic, coordinates services      │
│  Extensions: +Reports, +Grouping, +Selection, +TaskDetail    │
└──────────────────────────┬──────────────────────────────────┘
                           │ Protocol injection
┌──────────────────────────▼──────────────────────────────────┐
│                   Services & Networking                      │
│  ApiClientProtocol, SettingsServiceProtocol                  │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                       Models                                 │
│  ApiTask, ParseResponse, ActionResponse, ConfigResponse      │
└─────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Purpose | When to Read |
|------|---------|--------------|
| `Bee/BeeApp.swift` | Xcode app entry, startup flow | App lifecycle, backend startup |
| `Bee/BackendManager.swift` | Backend process lifecycle | Backend issues, health checks |
| `Sources/.../ContentView.swift` | Root layout, mode switching | Layout changes |
| `Sources/.../LauncherViewModel.swift` | Central state (~600 lines) | Any state logic |
| `Sources/.../LauncherViewModel+*.swift` | Feature extensions | Specific features |
| `Sources/.../ApiClient.swift` | Network client, transport factory | API changes |
| `Sources/.../UnixSocketTransport.swift` | POSIX socket impl | Socket issues |
| `Sources/.../ApiTransport.swift` | Transport protocol | Adding transports |

## ViewModel Extensions

LauncherViewModel is split by feature area:

| Extension | Handles |
|-----------|---------|
| `+Reports` | Report selection, filter persistence |
| `+Grouping` | Group collapsing, strategy management |
| `+Selection` | Task selection, navigation |
| `+Completion` | Autocomplete menu state |
| `+TaskDetail` | Detail panel loading |
| `+TaskExpansion` | Inline task expansion |
| `+CommandPalette` | Command palette state |
| `+Toast` | Toast notifications |
| `+Navigation` | Navigation stack, back navigation, view history |
| `+KeyboardHandling` | Escape key, normal mode key handling |

**Pattern**: Add new functionality to existing extension or create new `+Feature.swift`.

## Dependency Injection

All services are protocol-based for testability:

```swift
// Production
let viewModel = LauncherViewModel(
    apiClient: ApiClient(),
    settingsService: UserDefaultsSettingsService()
)

// Testing
let viewModel = LauncherViewModel(
    apiClient: MockApiClient(),
    settingsService: MockSettingsService()
)
```

**Protocols to know:**
- `ApiClientProtocol` → `ApiClient` / `MockApiClient`
- `SettingsServiceProtocol` → `UserDefaultsSettingsService` / `MockSettingsService`
- `TaskGroupingStrategy` → `ProjectGroupingStrategy`, `TagGroupingStrategy`, etc.
- `Theme` → `CatppuccinTheme`, `OneDarkTheme`

## Adding a Feature (Quick Guide)

1. **State**: Add `@Published` property to LauncherViewModel (or extension)
2. **Logic**: Add methods to appropriate ViewModel extension
3. **View**: Create/modify SwiftUI view, inject ViewModel
4. **Tests**: Add ViewInspector behavior test + snapshot test

See [ADDING-FEATURES.md](ADDING-FEATURES.md) for detailed walkthrough.

## Navigation Stack

The app uses a **view navigation stack** (`ViewNavigationStack`) to track view history, enabling proper back navigation:

```
┌─────────────┐   push    ┌─────────────┐   push    ┌─────────────┐
│  TaskList   │ ───────→  │ TaskDetail  │ ───────→  │ TaskDetail  │
│   (root)    │           │  (Task A)   │           │  (Task B)   │
└─────────────┘   ←───────└─────────────┘   ←───────└─────────────┘
                   pop (escape)              pop (escape)
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `NavigationEntry` | `Models/NavigationEntry.swift` | Enum: `.taskList`, `.taskDetail(uuid:)`, `.projectOverview` |
| `ViewNavigationStack` | `Utilities/Navigation/NavigationStack.swift` | Stack manager with push/pop/reset |
| `+Navigation` | `ViewModels/LauncherViewModel+Navigation.swift` | ViewModel navigation methods |

### Usage Pattern

```swift
// Forward navigation - pushes onto stack
viewModel.pushTaskDetail(uuid: linkedTaskUUID)
viewModel.pushProjectOverview()

// Back navigation - pops stack
viewModel.navigateBack()  // Returns to previous view

// Reset to root
viewModel.navigateToRoot()  // Clears to TaskList
```

### Mode Synchronization

The `mode` property is derived from the navigation stack via Combine:

```swift
// In LauncherViewModel.init()
navigationStack.$entries
    .map { $0.last?.mode ?? .list }
    .removeDuplicates()
    .sink { [weak self] newMode in
        self?.mode = newMode
    }
    .store(in: &cancellables)
```

**Important**: Never set `mode` directly. Use navigation methods (`pushTaskDetail`, `navigateBack`, etc.) which update the stack, and mode syncs automatically.

## Coordinators

Pure functions for complex state transitions:

| Coordinator | Purpose |
|-------------|---------|
| `InteractionCoordinator` | Escape key handling (`navigateBack`), normal-mode effects |
| `InteractionContextCoordinator` | Context calculation, hint bar building |
| `KeyHandlingDecider` | Pure key→action mapping for keyboard nav |
| `TaskListCoordinator` | Task grouping, selection within groups |
| `CompletionCoordinator` | Autocomplete state machine |
| `CommandPaletteCoordinator` | Palette visibility, positioning |

See [KEYBOARD-NAVIGATION.md](KEYBOARD-NAVIGATION.md) for keyboard navigation architecture.

## Backend Integration

The macOS app bundles and manages its own Rust backend (`beed`) for true network isolation.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Bee.app (Xcode)                          │
│  BeeApp.swift → BackendManager → beed (bundled binary)      │
└──────────────────────────┬──────────────────────────────────┘
                           │ Unix Socket
┌──────────────────────────▼──────────────────────────────────┐
│                   Transport Layer (SPM)                      │
│  ApiTransport ← UnixSocketTransport / HTTPTransport         │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                      ApiClient                               │
│  Uses transport abstraction, same interface regardless       │
└─────────────────────────────────────────────────────────────┘
```

### Key Files

| File | Location | Purpose |
|------|----------|---------|
| `BackendManager.swift` | `Bee/Bee/` | Backend process lifecycle (start/stop/health) |
| `BeeApp.swift` | `Bee/Bee/` | App entry, startup flow, error handling |
| `ApiTransport.swift` | `Sources/.../Networking/` | Transport protocol |
| `UnixSocketTransport.swift` | `Sources/.../Networking/` | POSIX socket transport |
| `HTTPTransport.swift` | `Sources/.../Networking/` | URLSession transport |
| `build-backend.sh` | `Bee/Scripts/` | Xcode build phase script |

### Transport Layer

```swift
// Protocol for transport abstraction
protocol ApiTransport: Sendable {
    func send(method:path:queryItems:body:headers:) async throws -> (Data, Int)
}

// Two implementations:
// 1. UnixSocketTransport - Local backend (POSIX sockets)
// 2. HTTPTransport - Remote servers (URLSession)

// Factory methods on ApiClient:
ApiClient.unixSocket(path: "/tmp/bee-123.sock")  // Local
ApiClient.http(baseURL: URL(string: "http://...")!)  // Remote
```

### Startup Flow

1. `BeeApp.body` shows `StartupView` initially
2. `.task` calls `startBackend()`
3. `BackendManager.start()`:
   - Locates `beed` in app bundle Resources
   - Creates unique socket path `/var/folders/.../T/bee-{PID}.sock`
   - Spawns backend process with `BEE_API_SOCKET` env var
   - Polls `/v1/config` until 2 consecutive successes
4. Creates `ApiClient.unixSocket(path:)`
5. Sets `viewModel`, which triggers `ContentView` to show

### Build System

The Xcode project has a "Build Backend" run script phase that:
1. Runs `cargo build -p bee-api` (debug or release based on config)
2. Copies `beed` binary to `Bee/Resources/`
3. Binary is bundled in `Bee.app/Contents/Resources/beed`

**Important**: App Sandbox is disabled (`ENABLE_APP_SANDBOX = NO`) for file system access.

## Design System

| Component | Purpose |
|-----------|---------|
| `ThemeManager` | Global theme provider |
| `DesignTokens` | Spacing, sizing, shadows |
| `StatusColor` | Task status → color mapping |
| `AssetIcon` | Icon asset constants |

## Testing

Two frameworks:

| Framework | Purpose | File Pattern |
|-----------|---------|--------------|
| **ViewInspector** | Behavior tests (taps, state) | `*UITests.swift` |
| **swift-snapshot-testing** | Visual regression | `*SnapshotTests.swift` |

See [TESTING.md](TESTING.md) for patterns and examples.

## Sub-Documents Index

Read these when working on specific areas:

| Document | Read When |
|----------|-----------|
| [ADDING-FEATURES.md](ADDING-FEATURES.md) | Adding new functionality end-to-end |
| [VIEWMODEL-PATTERNS.md](VIEWMODEL-PATTERNS.md) | Working on state management |
| [COMMAND-PALETTE.md](COMMAND-PALETTE.md) | Extending command palette |
| [KEYBOARD-NAVIGATION.md](KEYBOARD-NAVIGATION.md) | Adding keyboard shortcuts, vim-style navigation |
| [TESTING.md](TESTING.md) | Writing UI or snapshot tests |
| [COMPONENTS.md](COMPONENTS.md) | Creating or modifying reusable components |

## Guardrails

### Always Do
- Use `@Published` for observable state
- Follow existing extension naming (`+Feature.swift`)
- Add tests for new views/functionality
- Use protocol injection for services

### Ask First
- Adding new dependencies to Package.swift
- Changing ViewModel initialization
- Modifying shared components

### Never Do
- Direct view manipulation from ViewModel
- Blocking calls on main thread
- Skip snapshot recording step
