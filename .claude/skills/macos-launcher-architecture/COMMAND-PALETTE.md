# Command Palette Architecture

**Read this when:** Extending the command palette with new commands, sections, or submenus.

## Overview

The command palette uses a **registry-based contributor pattern** with stack-based navigation for nested menus:

```
CommandPaletteView
       │
       ▼
CommandPaletteCoordinator (state + navigation stack)
       │
       ▼
CommandPaletteDataSource ◄─── SectionContributors
       │                           ├── ActionsSectionContributor (priority: 0)
       │                           ├── TaskLinkSectionContributor (priority: 4)
       │                           ├── GroupBySectionContributor (priority: 10)
       │                           ├── GoToSectionContributor (priority: 20)
       │                           ├── ShortcutsSectionContributor (priority: 100)
       │                           └── YourNewContributor
       ▼
CommandPaletteSection[]
       │
       ▼
CommandPaletteItem[] (action | submenu | suggestion | shortcut)
```

## Key Files

| File | Purpose |
|------|---------|
| `Utilities/CommandPalette/DataSource.swift` | Registry, aggregates and filters sections |
| `Utilities/CommandPalette/Contributors/*.swift` | Individual section contributors |
| `Utilities/CommandPalette/ActionHandler.swift` | Menu builders and action handlers |
| `Utilities/CommandPalette/CommandPaletteActionHandling.swift` | Protocol for action handlers |
| `Views/CommandPaletteView.swift` | UI rendering |
| `ViewModels/CommandPaletteCoordinator.swift` | Navigation stack, visibility state |
| `Models/CommandPaletteModels.swift` | Data structures |
| `LauncherViewModel+CommandPalette.swift` | ViewModel integration, contributor setup |

## Data Model

### Item Types

```swift
enum CommandPaletteItem {
    case action(CommandPaletteActionItem)      // Executable actions
    case submenu(CommandPaletteSubmenuItem)    // Push nested menu
    case suggestion(CommandPaletteSuggestionItem) // With metadata
    case shortcut(CommandPaletteShortcutItem)  // Display-only help
}
```

### Section and Menu

```swift
struct CommandPaletteSection {
    let id: String
    let title: String?  // Optional section header
    let items: [CommandPaletteItem]
}

struct CommandPaletteMenu {
    let id: String
    let title: String
    let sections: [CommandPaletteSection]
}
```

### Context

```swift
struct CommandPaletteContext {
    let hasSelectedTask: Bool
    let selectedTaskUUID: String?
    let currentReportName: String?
    let availableReports: [ReportSummary]
    let projects: [String]
    let tags: [String]
    let currentProjectScope: String?
}
```

## Adding a New Section Contributor

### Step 1: Create Contributor

```swift
// Utilities/CommandPalette/Contributors/MyFeatureSectionContributor.swift

struct MyFeatureSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "myFeature" }
    var priority: Int { 15 }  // Lower = appears first

    private let onItemSelected: (String) -> Void

    init(onItemSelected: @escaping (String) -> Void) {
        self.onItemSelected = onItemSelected
    }

    func buildSections(context: CommandPaletteContext, query: String)
        -> [CommandPaletteSection] {
        // Return [] if not applicable
        guard context.hasSelectedTask else { return [] }

        let items: [CommandPaletteItem] = [
            .action(CommandPaletteActionItem(
                id: "myfeature-action1",
                title: "Do Something",
                subtitle: "Description",
                icon: .system("star"),
                handler: { [onItemSelected] in onItemSelected("action1") }
            ))
        ]

        return [CommandPaletteSection(id: "myFeature", title: "My Feature", items: items)]
    }
}
```

### Step 2: Register Contributor

In `LauncherViewModel+CommandPalette.swift`:

```swift
func setupCommandPaletteContributors() {
    // ... existing contributors ...

    commandPalette.dataSource.register(MyFeatureSectionContributor(
        onItemSelected: { [weak self] itemId in
            self?.handleMyFeatureSelection(itemId)
        }
    ))
}
```

## Adding Nested Submenus

For multi-level navigation (e.g., Link to Task → Select Type → Select Target):

### Step 1: Add Protocol Methods

```swift
// CommandPaletteActionHandling.swift
@MainActor
protocol CommandPaletteActionHandling {
    // ... existing methods ...
    func buildMySubmenu(param: String) -> CommandPaletteMenu
}
```

### Step 2: Implement Menu Builder

```swift
// ActionHandler.swift
func buildMySubmenu(param: String) -> CommandPaletteMenu {
    let items: [CommandPaletteItem] = myOptions.map { option in
        .submenu(CommandPaletteSubmenuItem(
            id: "option-\(option.id)",
            title: option.title,
            subtitle: option.description,
            icon: .system(option.iconName),
            menuBuilder: { [weak self] in
                // Return next level menu
                self?.buildNestedMenu(option: option)
                    ?? CommandPaletteMenu(id: "empty", title: "", sections: [])
            }
        ))
    }

    let section = CommandPaletteSection(id: "options", title: "Select Option", items: items)
    return CommandPaletteMenu(id: "my-submenu", title: "My Feature", sections: [section])
}
```

### Step 3: Create Entry Point in Contributor

```swift
// In your contributor's buildSections:
.submenu(CommandPaletteSubmenuItem(
    id: "my-feature",
    title: "My Feature...",
    subtitle: nil,
    icon: .system("star"),
    menuBuilder: { [actionHandler] in
        actionHandler.buildMySubmenu(param: someValue)
    }
))
```

## Pattern: Action Handler for Complex Menus

When a contributor needs to build complex menus with async data or multiple levels:

1. **Extend `CommandPaletteActionHandling` protocol** with new methods
2. **Implement in `CommandPaletteActionHandler`** (has access to ViewModel and ApiClient)
3. **Pass action handler to contributor** via initializer
4. **Contributor delegates menu building** to action handler

Example flow for task linking:
```
TaskLinkSectionContributor
    └── .submenu("Link to Task...")
            └── actionHandler.buildLinkTypeMenu(taskUUID:)
                    └── .submenu("Blocks...")
                            └── actionHandler.buildTaskSelectorMenu(linkType:sourceTaskUUID:)
                                    └── .action(handler: handleTaskLinkSelection)
```

## Navigation Stack

The coordinator maintains a navigation stack:

```swift
// Push submenu
commandPalette.navigationStack.push(menu)

// Pop (back button or Escape)
commandPalette.navigationStack.pop()

// Reset to root
commandPalette.navigationStack.reset()

// Check depth
if !commandPalette.navigationStack.isAtRoot {
    // Show breadcrumb
}
```

## Async Menu Loading

For menus that load data asynchronously:

```swift
func buildAsyncMenu(taskUUID: String) -> CommandPaletteMenu {
    // Start loading immediately
    Task { [weak self] in
        await self?.loadDataAndUpdateMenu(taskUUID: taskUUID)
    }

    // Return empty menu initially
    return CommandPaletteMenu(id: "async", title: "Loading...", sections: [])
}

private func loadDataAndUpdateMenu(taskUUID: String) async {
    guard let viewModel else { return }

    viewModel.commandPalette.isLoading = true
    defer { viewModel.commandPalette.isLoading = false }

    do {
        let data = try await apiClient.fetchData()
        let items = buildItems(from: data)

        let menu = CommandPaletteMenu(id: "async", title: "Select", sections: [
            CommandPaletteSection(id: "data", title: nil, items: items)
        ])

        // Replace current menu
        viewModel.commandPalette.navigationStack.pop()
        viewModel.commandPalette.navigationStack.push(menu)
    } catch {
        viewModel.showToast(message: "Failed to load: \(error.localizedDescription)")
    }
}
```

## Testing

### Contributor Tests

```swift
func testContributorShowsItemWhenTaskSelected() {
    let context = CommandPaletteContext(hasSelectedTask: true, selectedTaskUUID: "uuid")
    let contributor = MyFeatureSectionContributor(onItemSelected: { _ in })

    let sections = contributor.buildSections(context: context, query: "")

    XCTAssertEqual(sections.count, 1)
    XCTAssertEqual(sections[0].items.count, 1)
}

func testContributorHiddenWhenNoTask() {
    let context = CommandPaletteContext(hasSelectedTask: false)
    let contributor = MyFeatureSectionContributor(onItemSelected: { _ in })

    let sections = contributor.buildSections(context: context, query: "")

    XCTAssertTrue(sections.isEmpty)
}
```

### Action Handler Tests

```swift
func testBuildSubmenuReturnsCorrectItems() {
    let handler = CommandPaletteActionHandler(viewModel: mockViewModel, apiClient: mockClient)

    let menu = handler.buildMySubmenu(param: "test")

    XCTAssertEqual(menu.id, "my-submenu")
    XCTAssertEqual(menu.sections.count, 1)
    XCTAssertEqual(menu.sections[0].items.count, expectedCount)
}
```

## Priority Reference

| Priority | Contributor | Description |
|----------|-------------|-------------|
| 0 | ActionsSectionContributor | Main actions (reports, external links) |
| 4 | TaskLinkSectionContributor | Task linking |
| 10 | GroupBySectionContributor | Grouping options |
| 20 | GoToSectionContributor | Project navigation |
| 30 | ColumnsSectionContributor | Column management |
| 40 | TaskStateSectionContributor | Task state changes |
| 50 | SaveReportSectionContributor | Report saving |
| 100 | ShortcutsSectionContributor | Keyboard shortcuts (display only) |

Lower priority = appears first in the palette.
