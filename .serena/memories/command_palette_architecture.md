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

## Section Contributors

### Complete List (by Priority)

| Priority | Contributor | Purpose |
|----------|-------------|---------|
| 0 | `ActionsSectionContributor` | Main actions (reports, GitLab, Jira links) |
| 4 | `TaskLinkSectionContributor` | Task linking (new) |
| 10 | `GroupBySectionContributor` | Grouping options |
| 20 | `GoToSectionContributor` | Project navigation |
| 30 | `ColumnsSectionContributor` | Column management |
| 40 | `TaskStateSectionContributor` | Task state changes |
| 50 | `SaveReportSectionContributor` | Report saving |
| 100 | `ShortcutsSectionContributor` | Keyboard shortcuts (display only) |

### TaskLinkSectionContributor (Priority: 4)
**Location**: `Contributors/TaskLinkSectionContributor.swift`

Shows "Link to Task..." when task selected. Uses nested submenus:
1. Link Type Menu → 6 options (Blocks, Depends on, Parent of, Child of, Related to, Duplicates)
2. Task Selector Menu → Lists tasks (excludes current task)
3. On selection → Creates link via action system

```swift
struct TaskLinkSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "taskLink" }
    var priority: Int { 4 }
    
    private let actionHandler: CommandPaletteActionHandling
    
    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        guard context.hasSelectedTask, let taskUUID = context.selectedTaskUUID else { return [] }
        
        let items: [CommandPaletteItem] = [
            .submenu(CommandPaletteSubmenuItem(
                id: "link-to-task",
                title: "Link to Task",
                subtitle: nil,
                icon: .system("link"),
                menuBuilder: { [actionHandler] in
                    actionHandler.buildLinkTypeMenu(taskUUID: taskUUID)
                }
            ))
        ]
        return [CommandPaletteSection(id: "taskLink", title: nil, items: items)]
    }
}
```

---

## Pattern: Nested Submenus with Action Handler

For multi-level navigation (e.g., Link to Task → Select Type → Select Target):

1. **Extend `CommandPaletteActionHandling` protocol** with menu builder methods
2. **Implement in `CommandPaletteActionHandler`** (has ViewModel + ApiClient access)
3. **Contributor creates `.submenu` item** that calls action handler
4. **Each level returns a menu** that may contain more submenus

Example flow:
```
TaskLinkSectionContributor
    └── .submenu("Link to Task...")
            └── actionHandler.buildLinkTypeMenu(taskUUID:)
                    └── .submenu("Blocks...")
                            └── actionHandler.buildTaskSelectorMenu(linkType:sourceTaskUUID:)
                                    └── .action(handler: handleTaskLinkSelection)
```

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
