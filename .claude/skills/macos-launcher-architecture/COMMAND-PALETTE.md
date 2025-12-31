# Command Palette Architecture

**Read this when:** Extending the command palette with new commands or sections.

## Overview

The command palette uses a **contributor pattern** for extensibility:

```
CommandPaletteView
       │
       ▼
CommandPaletteDataSource ◄─── SectionContributors
       │                           ├── ActionSectionContributor
       │                           ├── ReportSectionContributor
       │                           ├── SettingsSectionContributor
       │                           └── YourNewContributor
       ▼
CommandPaletteSection[]
       │
       ▼
CommandPaletteItem[]
```

## Key Files

| File | Purpose |
|------|---------|
| `Utilities/CommandPalette/CommandPaletteDataSource.swift` | Aggregates sections from contributors |
| `Utilities/CommandPalette/SectionContributors.swift` | Protocol definition |
| `Utilities/CommandPalette/Contributors/*.swift` | Individual contributors |
| `Views/CommandPaletteView.swift` | UI rendering |
| `ViewModels/CommandPaletteCoordinator.swift` | Visibility state |
| `LauncherViewModel+CommandPalette.swift` | Integration with ViewModel |

## Data Model

```swift
struct CommandPaletteSection {
    let title: String
    let items: [CommandPaletteItem]
}

struct CommandPaletteItem {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String?
    let action: () -> Void
}
```

## Adding a New Command Section

### Step 1: Create Contributor

```swift
// Utilities/CommandPalette/Contributors/MyFeatureContributor.swift

struct MyFeatureContributor: CommandPaletteSectionContributor {
    let viewModel: LauncherViewModel

    var sectionTitle: String { "My Feature" }

    var items: [CommandPaletteItem] {
        [
            CommandPaletteItem(
                id: "myfeature.action1",
                title: "Do Something",
                subtitle: "Description of what it does",
                icon: "star",
                action: { viewModel.doSomething() }
            ),
            CommandPaletteItem(
                id: "myfeature.action2",
                title: "Do Something Else",
                subtitle: nil,
                icon: "gear",
                action: { viewModel.doSomethingElse() }
            )
        ]
    }

    // Optional: filter based on search
    func matches(query: String) -> Bool {
        items.contains { $0.title.localizedCaseInsensitiveContains(query) }
    }
}
```

### Step 2: Register Contributor

In `CommandPaletteDataSource.swift`:

```swift
struct CommandPaletteDataSource {
    let viewModel: LauncherViewModel

    var contributors: [CommandPaletteSectionContributor] {
        [
            ActionSectionContributor(viewModel: viewModel),
            ReportSectionContributor(viewModel: viewModel),
            SettingsSectionContributor(viewModel: viewModel),
            MyFeatureContributor(viewModel: viewModel)  // Add here
        ]
    }

    var sections: [CommandPaletteSection] {
        contributors.map { contributor in
            CommandPaletteSection(
                title: contributor.sectionTitle,
                items: contributor.items
            )
        }
    }
}
```

### Step 3: Add ViewModel Support (if needed)

In `LauncherViewModel+MyFeature.swift`:

```swift
extension LauncherViewModel {
    func doSomething() {
        // Implementation
        closeCommandPalette()
    }

    func doSomethingElse() {
        // Implementation
        closeCommandPalette()
    }
}
```

## Adding Items to Existing Sections

Modify the existing contributor:

```swift
// Contributors/ActionSectionContributor.swift
var items: [CommandPaletteItem] {
    var result = [
        // Existing items...
    ]

    // Add conditionally
    if viewModel.someCondition {
        result.append(CommandPaletteItem(
            id: "action.newitem",
            title: "New Action",
            ...
        ))
    }

    return result
}
```

## Search/Filtering

The data source handles filtering based on user input:

```swift
func filteredSections(for query: String) -> [CommandPaletteSection] {
    if query.isEmpty {
        return sections
    }

    return sections.compactMap { section in
        let matchingItems = section.items.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
            (item.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
        }

        guard !matchingItems.isEmpty else { return nil }
        return CommandPaletteSection(title: section.title, items: matchingItems)
    }
}
```

## Keyboard Navigation

Handled in `CommandPaletteView`:

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate items |
| `Enter` | Execute selected item |
| `Escape` | Close palette |
| Type | Filter items |

## State Management

```swift
// LauncherViewModel+CommandPalette.swift

@Published var isCommandPaletteVisible: Bool = false
@Published var commandPaletteQuery: String = ""
@Published var commandPaletteSelectedIndex: Int = 0

func openCommandPalette() {
    commandPaletteQuery = ""
    commandPaletteSelectedIndex = 0
    isCommandPaletteVisible = true
}

func closeCommandPalette() {
    isCommandPaletteVisible = false
}

func executeSelectedCommand() {
    let dataSource = CommandPaletteDataSource(viewModel: self)
    let sections = dataSource.filteredSections(for: commandPaletteQuery)

    // Find item at selected index
    var currentIndex = 0
    for section in sections {
        for item in section.items {
            if currentIndex == commandPaletteSelectedIndex {
                item.action()
                return
            }
            currentIndex += 1
        }
    }
}
```

## Testing

```swift
func testContributorItems() {
    let viewModel = makeViewModel()
    let contributor = MyFeatureContributor(viewModel: viewModel)

    XCTAssertEqual(contributor.items.count, 2)
    XCTAssertEqual(contributor.items[0].id, "myfeature.action1")
}

func testActionExecution() {
    let viewModel = makeViewModel()
    let contributor = MyFeatureContributor(viewModel: viewModel)

    contributor.items[0].action()

    XCTAssertTrue(viewModel.somethingWasDone)
}
```
