# Keyboard Navigation Architecture

This document describes the keyboard navigation pattern used in the macos-launcher. Use this when adding keyboard navigation to new views, understanding vim-style shortcuts, or considering extensibility.

## Architecture Overview

The keyboard navigation system uses a **pure-function pipeline** that separates concerns:

```
┌──────────────┐     ┌───────────────────┐     ┌──────────────────────┐
│   NSEvent    │ →   │ KeyHandlingDecider │ →   │ InteractionCoordinator│
│   Monitor    │     │  (key → action)    │     │   (action → effect)   │
└──────────────┘     └───────────────────┘     └──────────────────────┘
       ↑                     ↓                           ↓
 ContentView        NormalModeAction           NormalModeEffect
 installs           or KeyHandlingAction       executed by ViewModel
```

### Why This Pattern?

1. **Testability**: Pure functions (`KeyHandlingDecider`, `InteractionCoordinator`) are trivially unit-testable
2. **Separation**: Key parsing is separate from action semantics, which is separate from side effects
3. **Context-awareness**: `InteractionCoordinator` can map the same action to different effects based on context

### Why Not SwiftUI's `@FocusState`?

SwiftUI's focus system only supports Tab navigation between focusable elements. It cannot:
- Capture vim-style j/k keys (these go to the text field)
- Handle mode-aware shortcuts (normal vs insert mode)
- Work with custom NSEvent monitoring

We use `NSEvent.addLocalMonitorForEvents` at the window level to intercept keys before SwiftUI's responder chain.

## Key Components

### 1. KeyHandlingDecider (`KeyHandlingDecider.swift`)

**Location:** `Views/Components/TokenHighlight/KeyHandlingDecider.swift`

**Purpose:** Pure function mapping `KeyInput` → action enum. No side effects.

```swift
// Insert mode: decides what action to take when typing
static func action(for input: KeyInput, showCompletionMenu: Bool) -> KeyHandlingAction?

// Normal mode: vim-like navigation
static func normalModeAction(for input: KeyInput) -> NormalModeAction?
```

**Key insight:** This enum has NO state. Every method is `static` and pure. Easy to test.

### 2. InteractionCoordinator (`InteractionCoordinator.swift`)

**Location:** `Utilities/Coordinators/InteractionCoordinator.swift`

**Purpose:** Maps actions to effects based on context. Also pure.

```swift
// What should Escape do in this context?
static func escapeAction(for context: InteractionContext) -> EscapeAction

// What should a normal-mode action do?
static func normalModeEffect(action:, canToggleGroupCollapse:) -> NormalModeEffect
```

**Escape Actions:**
- `.closeCommandPalette` - Close command palette
- `.clearCompletions` - Clear autocomplete menu
- `.navigateBack` - **Pop the navigation stack** (returns to previous view)
- `.exitInsertMode` - Switch to normal mode
- `.closeWindow` - Close the launcher window

### 3. InteractionContextCoordinator (`InteractionContextCoordinator.swift`)

**Location:** `Utilities/Coordinators/InteractionContextCoordinator.swift`

**Purpose:** Determines current interaction context from app state. Used for:
- Deciding what hints to show in `BottomHintBar`
- Providing context to `InteractionCoordinator`

```swift
enum InteractionContext: Equatable {
    case commandPalette
    case completionMenu(selection: ListSelectionKind, isInsertMode: Bool)
    case detail
    case list(selection: ListSelectionKind, isInsertMode: Bool)
}
```

### 4. NSEvent Monitors (in ContentView)

**Location:** `Views/ContentView.swift`

Two monitors installed at the window level:

| Monitor | Purpose | Condition |
|---------|---------|-----------|
| `escapeMonitor` | Handle Escape key | Always active |
| `normalModeMonitor` | Handle vim keys (j/k/G/i/etc) | When `!isInsertMode` && `mode == .list` && `!commandPalette.isPresented` |

## Adding Keyboard Navigation to a New View

### Step 1: Define the Actions

Create or extend an action enum:

```swift
// In KeyHandlingModels.swift or a new file
enum DetailViewAction: Equatable {
    case navigateUp       // j
    case navigateDown     // k
    case openLink         // o
    case copyFocused      // y
}
```

### Step 2: Create a Decider Function

Add to `KeyHandlingDecider` or create a new pure function:

```swift
static func detailViewAction(for input: KeyInput) -> DetailViewAction? {
    switch input.keyCode {
    case KeyCode.keyJ: return .navigateDown
    case KeyCode.keyK: return .navigateUp
    case KeyCode.keyO: return .openLink
    case KeyCode.keyY: return .copyFocused
    default: return nil
    }
}
```

### Step 3: Add Context to InteractionContext

Extend `InteractionContext` if needed:

```swift
enum InteractionContext: Equatable {
    // existing...
    case detail(focusedElement: DetailFocusKind)  // extended
}
```

### Step 4: Install Monitor Conditionally

In `ContentView` or the appropriate view, conditionally install a monitor:

```swift
private func installDetailModeMonitor() {
    guard detailMonitor == nil, viewModel.mode == .detail else { return }
    detailMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        guard let action = KeyHandlingDecider.detailViewAction(for: KeyInput(event: event)) else {
            return event
        }
        return viewModel.handleDetailAction(action) ? nil : event
    }
}
```

### Step 5: Handle Action in ViewModel

Add a handler method:

```swift
func handleDetailAction(_ action: DetailViewAction) -> Bool {
    switch action {
    case .navigateUp: detailFocusIndex = max(0, detailFocusIndex - 1)
    case .navigateDown: detailFocusIndex = min(maxIndex, detailFocusIndex + 1)
    case .openLink: openFocusedLink()
    case .copyFocused: copyFocusedItem()
    }
    return true
}
```

### Step 6: Update Hint Bar

Add hints in `BottomHintModelBuilder`:

```swift
case .detail(let focus):
    hints.append(BottomHint(key: "j/k", label: "Navigate"))
    hints.append(BottomHint(key: "o", label: "Open"))
    hints.append(BottomHint(key: "y", label: "Copy"))
```

## Testing Keyboard Navigation

### Unit Tests for Deciders

Test pure functions directly:

```swift
func testDetailViewActionJ() {
    let input = KeyInput(keyCode: KeyCode.keyJ, characters: "j", modifierFlags: [])
    XCTAssertEqual(KeyHandlingDecider.detailViewAction(for: input), .navigateDown)
}
```

### Integration Tests for Effects

Test that actions produce correct effects:

```swift
func testDetailModeNavigateChangesIndex() {
    viewModel.mode = .detail
    viewModel.detailFocusIndex = 0

    _ = viewModel.handleDetailAction(.navigateDown)

    XCTAssertEqual(viewModel.detailFocusIndex, 1)
}
```

### Snapshot Tests for Hint Bar

Verify correct hints appear:

```swift
func testWithDetailModeHints() {
    viewModel.mode = .detail
    let view = makeContentView()
    assertViewSnapshot(view, size: TestSizes.contentView)
}
```

## Migration Cost Assessment

If a full keyboard navigation framework is ever needed, the migration cost is **low** (~4-8 hours):

1. Current deciders already isolate key→action mapping
2. Coordinators already isolate action→effect mapping
3. Only need to add: routing layer, standardized handler protocol
4. No changes needed to views or ViewModel patterns

**Current recommendation:** Don't build framework until we have 4+ navigation contexts. We currently have 3:
- List mode (normal/insert)
- Command palette
- Detail mode (with navigation stack for back-navigation)

## Navigation Stack Integration

Escape handling integrates with the navigation stack for contextual back-navigation:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Escape Key Pressed                          │
└──────────────────────────┬──────────────────────────────────────┘
                           │
       ┌───────────────────┴───────────────────┐
       ▼                                       ▼
┌──────────────────┐                   ┌──────────────────┐
│ Command Palette? │ → Yes → Close it  │ Completion Menu? │ → Yes → Clear it
│   or Modal UI    │                   │                  │
└────────┬─────────┘                   └────────┬─────────┘
         │ No                                   │ No
         └───────────────┬──────────────────────┘
                         ▼
                ┌──────────────────┐
                │  In Detail View  │ → Yes → navigateBack() → pop stack
                │  or ProjectView? │
                └────────┬─────────┘
                         │ No (at list root)
                         ▼
                ┌──────────────────┐
                │  Insert Mode?    │ → Yes → exitInsertMode()
                └────────┬─────────┘
                         │ No
                         ▼
                ┌──────────────────┐
                │  Close Window    │
                └──────────────────┘
```

**Key insight**: The `.navigateBack` action calls `viewModel.navigateBack()` which pops the navigation stack. This means:
- Escape from TaskDetail → returns to previous TaskDetail OR TaskList (depending on history)
- Escape from ProjectOverview → returns to wherever you came from (could be TaskDetail)

See main skill document section "Navigation Stack" for stack implementation details.

## Detail Focus Navigation (Coordinate-Based)

The task detail view uses a **coordinate-based navigation system** that enables vim-style h/j/k/l movement between focusable elements. This is distinct from the pure-function pipeline above—it manages spatial positions of UI elements.

### Architecture Overview

```
┌────────────────────────────────────────────────────────────────────┐
│                      DetailFocusableItem                           │
│  Enum defining all navigable elements (taskName, tag, attachment) │
└──────────────────────────┬─────────────────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────────────────┐
│                      NavigationRegistry                            │
│  Tracks on-screen coordinates via .navigationRegistrable()        │
│  Enables spatial h/j/k/l navigation between registered items      │
└──────────────────────────┬─────────────────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────────────────┐
│                    LauncherViewModel+DetailFocus                   │
│  - buildDetailFocusableItems(): logical ordering                  │
│  - focusedDetailItem: current selection                           │
│  - openFocusedDetailItem(), deleteFocusedDetailItem(): handlers   │
└────────────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `DetailFocusableItem` | `Models/DetailFocusableItem.swift` | Enum with cases for each navigable element |
| `NavigationRegistry` | `Utilities/Navigation/NavigationRegistry.swift` | Spatial coordinate tracking, h/j/k/l logic |
| `.navigationRegistrable()` | View modifier | Registers item position with registry |
| `DetailFocusRing` | `Views/Components/DetailFocusRing.swift` | Blue outline visual indicator |
| `LauncherViewModel+DetailFocus` | `ViewModels/` | Focus state, action handlers |

### DetailFocusableItem Enum

Each navigable element has a case with associated data for actions:

```swift
enum DetailFocusableItem: Equatable, Identifiable {
    case taskName(String)           // Task name at top
    case tag(String, index: Int)    // Individual tag
    case addTagButton               // "+" button
    case attachment(AttachmentDto)  // File attachment
    case importantLink(LinkDto)     // Important link
    case addImportantLinkButton     // "+" add link button
    // ... more cases

    var id: String { /* unique identifier */ }
    var openURL: URL? { /* for 'o' key */ }
    var copyValue: String { /* for 'y' key */ }
    var copyLabel: String { /* toast message */ }
}
```

### Adding a New Navigable Element

Follow this checklist when adding keyboard navigation to a new detail section:

#### 1. Add enum cases to `DetailFocusableItem`

```swift
// In Models/DetailFocusableItem.swift
case newItem(NewItemDto)
case addNewItemButton

var id: String {
    // ...existing cases...
    case let .newItem(item): "newItem-\(item.id)"
    case .addNewItemButton: "addNewItemButton"
}

var openURL: URL? { /* if applicable */ }
var copyValue: String { /* what 'y' copies */ }
var copyLabel: String { /* toast label */ }
```

#### 2. Update `buildDetailFocusableItems()`

```swift
// In ViewModels/LauncherViewModel+DetailFocus.swift
func buildDetailFocusableItems() {
    // ...existing items...

    // Add new items (order determines tab sequence)
    for item in detail.newItems {
        items.append(.newItem(item))
    }
    if !isAddingNewItem {
        items.append(.addNewItemButton)
    }
}
```

#### 3. Add action handlers

```swift
// In openFocusedDetailItem()
if case let .newItem(item) = focusedDetailItem,
   let url = URL(string: item.url) {
    NSWorkspace.shared.open(url)
    return true
}
if case .addNewItemButton = focusedDetailItem {
    startAddingNewItem()
    return true
}

// In deleteFocusedDetailItem()
if case let .newItem(item) = focusedDetailItem {
    Task { await removeNewItem(item) }
    return true
}
```

#### 4. Update the Section view

```swift
// In Views/Components/NewItemSection.swift
struct NewItemSection: View {
    let items: [NewItemDto]
    let focusedItem: DetailFocusableItem?  // Add this

    // Focus helpers
    private func isItemFocused(_ item: NewItemDto) -> Bool {
        if case let .newItem(focused) = focusedItem {
            return focused.id == item.id
        }
        return false
    }

    private var isAddButtonFocused: Bool {
        if case .addNewItemButton = focusedItem { return true }
        return false
    }

    var body: some View {
        ForEach(items) { item in
            NewItemRow(item: item, isFocused: isItemFocused(item))
                .navigationRegistrable(.newItem(item))  // Register for nav
        }
        addButton
            .navigationRegistrable(.addNewItemButton)
    }
}
```

#### 5. Add focus ring to Row view

```swift
struct NewItemRow: View {
    let item: NewItemDto
    var isFocused: Bool = false

    var body: some View {
        HStack { /* content */ }
            .modifier(DetailFocusRing(isFocused: isFocused))
    }
}
```

#### 6. Wire through TaskDetailView

```swift
// In Views/TaskDetailView.swift
NewItemSection(
    items: detail.newItems,
    focusedItem: focusedItem,  // Pass focus state
    // ... other params
)
```

### Key Bindings in Detail Mode

| Key | Action | Handler |
|-----|--------|---------|
| `h/j/k/l` | Navigate between items | `navigationRegistry.navigate()` |
| `o` or `Return` | Open/edit focused item | `openFocusedDetailItem()` |
| `y` | Copy focused item value | `copyFocusedDetailItem()` |
| `x` | Delete focused item | `deleteFocusedDetailItem()` |

### How Spatial Navigation Works

The `NavigationRegistry` maintains a mapping of `DetailFocusableItem` → screen coordinates. When you press `j`:

1. Registry finds current item's position
2. Looks for items below (higher Y coordinate)
3. Picks closest one in the same column (similar X)
4. Updates `focusedItem` state

This means physical layout matters—items visually below appear "below" in j/k navigation.

## File Quick Reference

| File | Purpose |
|------|---------|
| `KeyHandlingDecider.swift` | Pure key→action mapping |
| `KeyHandlingModels.swift` | Action/effect enums |
| `InteractionCoordinator.swift` | Action→effect with context |
| `InteractionContextCoordinator.swift` | Context calculation, hint building |
| `ContentView.swift` | NSEvent monitor installation |
| `LauncherViewModel.swift` | Effect handlers (handleEscape, handleNormalModeAction) |
| `LauncherViewModel+Navigation.swift` | Navigation stack methods (`navigateBack`, `pushTaskDetail`) |
| `LauncherViewModel+DetailFocus.swift` | Detail focus state, action handlers |
| `NavigationStack.swift` | `ViewNavigationStack` class (push/pop/reset) |
| `NavigationRegistry.swift` | Coordinate-based h/j/k/l navigation |
| `NavigationEntry.swift` | Navigation entry enum |
| `DetailFocusableItem.swift` | Enum for navigable detail elements |
| `DetailFocusRing.swift` | Visual focus indicator modifier |

## Guardrails

### Always Do
- Keep deciders as pure functions (no ViewModel access)
- Return `nil` from monitors to consume events, return `event` to pass through
- Add tests for new key bindings

### Ask First
- Adding new context types to `InteractionContext`
- Changing existing key bindings

### Never Do
- Access ViewModel state from inside decider functions
- Forget to remove monitors in `onDisappear`
- Install duplicate monitors (check for `nil` first)
