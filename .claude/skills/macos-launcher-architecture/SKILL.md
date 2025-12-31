---
name: macos-launcher-architecture
description: macOS launcher SwiftUI architecture, patterns, and development workflows. Use when working on macos-launcher, SwiftUI views, ViewModels, services, command palette, or understanding the launcher codebase structure.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__serena__*
---

# macOS Launcher Architecture

This skill documents the architecture, patterns, and conventions for the macOS launcher (`macos-launcher/`).

## Quick Reference

| Layer | Location | Purpose |
|-------|----------|---------|
| **Views** | `Views/` | SwiftUI views (ContentView, TaskListView, TaskRow, etc.) |
| **ViewModels** | `ViewModels/` | State management (LauncherViewModel + extensions) |
| **Models** | `Models/` | Data structures (ApiTask, ConfigModels, etc.) |
| **Services** | `Utilities/Services/` | Dependency-injected services (ApiClient, Settings) |
| **Networking** | `Networking/` | API client protocol and implementations |
| **Components** | `Views/Components/` | Reusable UI components (25+ components) |
| **Design** | `Utilities/Design/` | Theme, DesignTokens, StatusColor |

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
| `LauncherApp.swift` | App entry, WindowGroup, global shortcuts | App lifecycle |
| `ContentView.swift` | Root layout, mode switching | Layout changes |
| `LauncherViewModel.swift` | Central state (~600 lines) | Any state logic |
| `LauncherViewModel+*.swift` | Feature extensions | Specific features |
| `ApiClientProtocol.swift` | Network interface | API changes |
| `SettingsServiceProtocol.swift` | Settings interface | Preferences |

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

## Coordinators

Pure functions for complex state transitions:

| Coordinator | Purpose |
|-------------|---------|
| `InteractionCoordinator` | Escape key handling, normal-mode effects |
| `TaskListCoordinator` | Task grouping, selection within groups |
| `CompletionCoordinator` | Autocomplete state machine |
| `CommandPaletteCoordinator` | Palette visibility, positioning |

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
