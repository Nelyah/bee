# Command Palette Architecture - macOS Launcher

## Overview
The command palette uses a **registry-based, extensible architecture** with section contributors that build sections dynamically based on context and query.

Key characteristics:
- **Stack-based navigation**: Supports arbitrary nesting depth with breadcrumbs
- **Section contributor pattern**: Pluggable sections via `CommandPaletteSectionContributor` protocol
- **Fuzzy filtering**: Weighted scoring system for search
- **Context-driven**: Sections built from `CommandPaletteContext` containing task, report, and project data

---

## Core Models

### CommandPaletteItem (Enum with 4 cases)
```swift
enum CommandPaletteItem {
    case action(CommandPaletteActionItem)        // Executable actions
    case submenu(CommandPaletteSubmenuItem)      // Push nested menu
    case suggestion(CommandPaletteSuggestionItem) // With metadata (GitLab, Jira)
    case shortcut(CommandPaletteShortcutItem)    // Display-only help text
}
```

**Key properties**:
- `displayTitle`: Works across all types
- `subtitle`: Optional descriptor
- `icon`: Optional (CommandPaletteIcon enum)
- `isSelectable`: False only for shortcuts

### CommandPaletteSection
```swift
struct CommandPaletteSection {
    let id: String
    let title: String?  // Optional section header
    let items: [CommandPaletteItem]
}
```

### CommandPaletteContext
Data passed to contributors for building sections:
- `hasSelectedTask`: Bool
- `selectedTaskUUID`: String?
- `currentReportName`: String?
- `availableReports`: [ReportSummary]
- **projects: [String]** ← For "Go To" section
- `tags`: [String]

### CommandPaletteMenu (Navigation)
```swift
struct CommandPaletteMenu {
    let id: String
    let title: String
    let sections: [CommandPaletteSection]
}
```

### CommandPaletteStack
Manages navigation stack:
- `push()`, `pop()`, `reset()`, `clear()`
- `currentMenu`: The topmost menu
- `isAtRoot`: True if depth <= 1
- `breadcrumb`: [String] for display

---

## Section Contributor Pattern

### Protocol
```swift
protocol CommandPaletteSectionContributor {
    var contributorId: String { get }  // Unique ID for registration
    var priority: Int { get }          // Lower values appear first (0-100+)
    
    func buildSections(context: CommandPaletteContext, query: String) 
        -> [CommandPaletteSection]
}
```

**Key design principles**:
1. Stateless: Rebuilds sections on each call
2. Query-aware: Can implement custom filtering
3. Context-aware: Access to all palette context
4. Priority-ordered: Sorted ascending, lowest priority first

---

## Existing Section Contributors

### 1. ActionsSectionContributor (Priority: 0)
**Location**: `SectionContributors.swift` lines 22-92

Always shows:
- **Select Report**: Submenu with all available reports
- **Add GitLab Link**: When task selected, builds async menu
- **Add Jira Link**: When task selected, builds async menu

```swift
struct ActionsSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "actions" }
    var priority: Int { 0 }
    
    private let actionHandler: CommandPaletteActionHandling
    // ...
}
```

**Integration**: Requires `CommandPaletteActionHandler` (wires to LauncherViewModel)

### 2. GroupBySectionContributor (Priority: 10)
**Location**: `SectionContributors.swift` lines 181-212

Shows grouping options:
- Project, Due Date, Tag, None
- Shows "Current" subtitle for selected option
- Callback: `onGroupBySelect: (GroupByOption) -> Void`

```swift
struct GroupBySectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "groupBy" }
    var priority: Int { 10 }
    
    private let currentGroupBy: () -> GroupByOption
    private let onGroupBySelect: (GroupByOption) -> Void
}
```

### 3. ShortcutsSectionContributor (Priority: 100)
**Location**: `SectionContributors.swift` lines 100-141

Display-only shortcuts section (only shown when query is empty):
- Close/Back (Esc)
- Select (Return)
- Move Up (↑/Ctrl+P)
- Move Down (↓/Ctrl+N)

```swift
struct ShortcutsSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "shortcuts" }
    var priority: Int { 100 }
    // Uses .shortcut items which are not selectable
}
```

### 4. GoToSectionContributor (Priority: 20) - STUB
**Location**: `SectionContributors.swift` lines 214-246

**Status**: DEBT-0033 placeholder (currently unused)

```swift
struct GoToSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "goTo" }
    var priority: Int { 20 }
    
    private let onProjectSelect: (String) -> Void
    
    func buildSections(context: CommandPaletteContext, query: String) 
        -> [CommandPaletteSection] {
        guard !context.projects.isEmpty else { return [] }
        
        let items: [CommandPaletteItem] = context.projects.map { project in
            .action(
                CommandPaletteActionItem(
                    id: "goto-\(project)",
                    title: project,
                    icon: .system("folder"),
                    handler: { [onProjectSelect] in onProjectSelect(project) }
                )
            )
        }
        
        return [CommandPaletteSection(id: "goTo", title: "Go To", items: items)]
    }
}
```

**To enable**: 
1. Wire `onProjectSelect` callback to view model
2. Populate `context.projects` 
3. Register with data source

---

## CommandPaletteDataSource (Registry)

**Location**: `Utilities/CommandPalette/DataSource.swift`

Manages contributor registration and filtering:

```swift
@MainActor
final class CommandPaletteDataSource: ObservableObject {
    private var contributors: [CommandPaletteSectionContributor] = []
    
    func register(_ contributor: CommandPaletteSectionContributor) {
        contributors.append(contributor)
        contributors.sort { $0.priority < $1.priority }
    }
    
    func unregister(contributorId: String) { ... }
    func clearContributors() { ... }
    
    func buildSections(context: CommandPaletteContext, query: String) 
        -> [CommandPaletteSection] {
        // 1. Call each contributor in priority order
        // 2. Filter/rank items using fuzzy scorer
        // 3. Return non-empty sections
    }
}
```

**Key behavior**:
- Contributors called in priority order
- Items filtered by fuzzy score against title and subtitle
- Empty sections automatically removed
- Sections from all contributors merged in result

---

## CommandPaletteCoordinator (Main Controller)

**Location**: `ViewModels/CommandPaletteCoordinator.swift`

State and navigation management:

```swift
@MainActor
final class CommandPaletteCoordinator: ObservableObject {
    @Published var isPresented: Bool
    @Published var query: String
    @Published var selectionIndex: Int
    let dataSource: CommandPaletteDataSource
    @Published var navigationStack: CommandPaletteStack
    
    var currentSections: [CommandPaletteSection] {
        // If nested: filter current menu sections by query
        // If root: build sections from context via dataSource
    }
    
    var selectableItems: [CommandPaletteItem] {
        currentSections.flatMap { $0.items.filter { $0.isSelectable } }
    }
    
    func open(context: CommandPaletteContext) -> String?
    func close()
    func handleEscape() -> Bool    // Pops stack, returns true if handled
    func handleEnter()              // Executes/navigates selected item
    func pushMenu(_ menu: CommandPaletteMenu)
    func moveSelection(delta: Int)
    func updateContext(_ context: CommandPaletteContext)
}
```

---

## Integration in LauncherViewModel

**Location**: `ViewModels/LauncherViewModel.swift` lines 116-132

```swift
private func setupCommandPaletteContributors() {
    // Register shortcuts first (highest priority 100)
    commandPalette.dataSource.register(ShortcutsSectionContributor())
    
    // Register action handler with callbacks
    let actionHandler = CommandPaletteActionHandler(
        viewModel: self, 
        apiClient: apiClient
    )
    commandPalette.dataSource.register(
        ActionsSectionContributor(actionHandler: actionHandler)
    )
    
    // Register group-by with closures
    commandPalette.dataSource.register(GroupBySectionContributor(
        currentGroupBy: { [weak self] in self?.currentGroupByOption ?? .project },
        onGroupBySelect: { [weak self] option in self?.setGroupingStrategy(option) }
    ))
}
```

**Key pattern**: Each contributor is registered separately, passed closures/handlers for callbacks.

---

## Navigation Flow

### Root Menu
Opened via `coordinator.open(context:)`:
1. Store context
2. Build root menu from all contributors
3. Push to stack
4. Set `isPresented = true`

### Nested Menus
Triggered by `.submenu` item selection:
1. Call `submenu.menuBuilder()` to get menu
2. `navigationStack.push(menu)`
3. Display new sections, clear query, reset selection

### Back Navigation
- **Escape key**: Pops stack (unless at root, then closes)
- **Back button**: `navigateBack()` pops and resets state

### Breadcrumb
Shown when `!isAtRoot`:
```
Command Palette > Submenu > Sub-submenu
```

---

## Fuzzy Scoring

**Location**: `Utilities/CommandPalette/FuzzyScorer.swift`

Weighted scoring:
1. Exact match: 1000 points
2. Prefix match: 800 points  
3. Word prefix: 600 points
4. Substring: 400 points
5. Fuzzy match: 200-300 points

Search targets:
- Item `displayTitle` (primary)
- Item `subtitle` (fallback)
- Empty query returns all items

---

## Adding a New Section Contributor

### Template
```swift
struct MyNewSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "myId" }
    var priority: Int { 15 }  // Position in menu
    
    // Optional: store closures for callbacks
    private let onItemSelected: (String) -> Void
    
    init(onItemSelected: @escaping (String) -> Void) {
        self.onItemSelected = onItemSelected
    }
    
    func buildSections(context: CommandPaletteContext, query: String) 
        -> [CommandPaletteSection] {
        // Return [] if not applicable (e.g., !context.hasSelectedTask)
        
        let items: [CommandPaletteItem] = ...
        return [CommandPaletteSection(id: "myId", title: "Section Title", items: items)]
    }
}
```

### Register in LauncherViewModel
```swift
private func setupCommandPaletteContributors() {
    // ... existing contributors ...
    
    commandPalette.dataSource.register(MyNewSectionContributor(
        onItemSelected: { [weak self] itemId in
            self?.handleMySelection(itemId)
        }
    ))
}
```

---

## Key Files Reference

- **Models**: `/macos-launcher/Sources/LauncherApp/Models/CommandPaletteModels.swift`
- **Contributors**: `/macos-launcher/Sources/LauncherApp/Utilities/CommandPalette/SectionContributors.swift`
- **DataSource**: `/macos-launcher/Sources/LauncherApp/Utilities/CommandPalette/DataSource.swift`
- **Coordinator**: `/macos-launcher/Sources/LauncherApp/ViewModels/CommandPaletteCoordinator.swift`
- **Action Handler**: `/macos-launcher/Sources/LauncherApp/Utilities/CommandPalette/ActionHandler.swift`
- **Fuzzy Scorer**: `/macos-launcher/Sources/LauncherApp/Utilities/CommandPalette/FuzzyScorer.swift`
- **View**: `/macos-launcher/Sources/LauncherApp/Views/CommandPaletteView.swift`

---

## DEBT-0036 Refactor Summary

Commit: `1eb28f8`

Replaced monolithic mode-based architecture with:
- Sectioned data model with composable sections
- Registry-style extensibility via contributor protocol
- Navigation stack for arbitrary nesting
- Weighted fuzzy scoring
- Cleaner separation of concerns

This enables easy addition of new sections (like "Go To Projects") without modifying core palette logic.
