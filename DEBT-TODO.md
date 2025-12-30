# DEBT TODO

## Summary
- **TaskDetailView** embeds 5 private structs (450+ LOC) that should be extracted to Components/
- **ApiClient** has ~17 lines of error handling duplicated 3 times across `send/get/post`
- **Utilities/** folder is flat with 21 files; could be grouped into subcategories
- **Button styles** are duplicated between QuietRefreshButtonStyle and QuietTextButtonStyle
- **Hover state pattern** repeated 5+ times with identical `.onHover` handlers

## Open Issues

### DEBT-0024: TaskDetailView embeds large private structs
- Priority: P1
- Effort: M
- Area: Views/TaskDetailView.swift
- Evidence: `TaskDetailView.swift:260-777` - 5 private structs totaling ~450 LOC:
  - `DetailSection` (lines 260-286, 26 LOC)
  - `ExternalLinksProviderSection` (lines 288-351, 63 LOC)
  - `ExternalLinkRow` (lines 365-687, 323 LOC) - **largest, should be separate file**
  - `LinkStatusBadge` (lines 689-741, 52 LOC)
  - `TimelineRow` (lines 755-777, 22 LOC)
- Smells: SRP, coupling, testability
- Problem (rough): ExternalLinkRow alone is 323 lines embedded in TaskDetailView. These private structs cannot be reused or tested independently. The main view file is 796 lines, making it hard to navigate.
- Suggested fix (rough):
  - Extract `ExternalLinkRow.swift` to Views/Components/ (highest priority)
  - Extract `LinkStatusBadge.swift` to Views/Components/
  - Extract `TimelineRow.swift` to Views/Components/
  - Keep `DetailSection` private (it's small and specific to this view)
  - Consider grouping external-link-related components in Views/ExternalLinks/
- Safety net: Add unit tests for LinkStatusBadge state/color logic before extraction

### DEBT-0025: ApiClient duplicates error handling across send/get/post
- Priority: P1
- Effort: S
- Area: Networking/ApiClient.swift
- Evidence: `ApiClient.swift:129-148`, `ApiClient.swift:167-186`, `ApiClient.swift:205-224` - identical ~17-line blocks in each method:
  ```swift
  guard let http = response as? HTTPURLResponse else { ... }
  guard (200..<300).contains(http.statusCode) else {
      let payload = decodeErrorPayload(from: data)
      // ... logging and throw
  }
  ```
- Smells: duplication, DRY violation
- Problem (rough): Same error handling logic copied three times. If error handling needs to change (e.g., add retry logic, change logging), all three places must be updated.
- Suggested fix (rough):
  - Extract `private func handleResponse(_ response: URLResponse, data: Data, path: String) throws`
  - Have each method call the shared helper after `session.data(for:)`
  - Keep `decodeErrorPayload` as-is (already extracted)
- Safety net: Existing `ApiClientTests` cover error handling; run tests after refactor

### DEBT-0026: Button style duplication between QuietRefreshButtonStyle and QuietTextButtonStyle
- Priority: P2
- Effort: S
- Area: Views/TaskDetailView.swift
- Evidence: `TaskDetailView.swift:353-363` vs `TaskDetailView.swift:743-753`:
  ```swift
  // QuietRefreshButtonStyle
  .opacity(configuration.isPressed ? 0.6 : 1)
  .scaleEffect(configuration.isPressed ? 0.96 : 1)
  .animation(.easeOut(duration: 0.15), ...)

  // QuietTextButtonStyle
  .opacity(configuration.isPressed ? 0.7 : 1)
  .scaleEffect(configuration.isPressed ? 0.98 : 1)
  .animation(.easeOut(duration: 0.12), ...)
  ```
- Smells: duplication, near-identical code
- Problem (rough): Two button styles with nearly identical implementation (only opacity/scale values differ slightly). If press animation behavior needs to change, both must be updated.
- Suggested fix (rough):
  - Create a single `QuietButtonStyle` with configurable parameters
  - Or consolidate into one style with consistent animation values
  - Move to a Styles/ folder for reuse across views
- Safety net: Visual regression check; no unit tests needed

### DEBT-0027: Hover state pattern repeated with identical .onHover handlers
- Priority: P2
- Effort: S
- Area: Views/TaskDetailView.swift, Views/CommandPaletteView.swift
- Evidence: `TaskDetailView.swift:297,370-373,394,444,512,529` - pattern appears 6+ times:
  ```swift
  @State private var isHoveringTitle = false
  // ...
  .onHover { hovering in
      isHoveringTitle = hovering
  }
  ```
- Smells: duplication, boilerplate
- Problem (rough): Every hoverable element requires a separate `@State` variable and identical `.onHover` closure. This adds visual noise and requires remembering to wire up both pieces.
- Suggested fix (rough):
  - Create a `HoverableButton` component that encapsulates hover state
  - Or create a `@Hoverable` property wrapper / ViewModifier
  - Alternative: Use a `HoverTracker` helper that can be shared
- Safety net: Visual regression check; no unit tests needed

### DEBT-0028: Utilities/ folder is flat with 21 files
- Priority: P2
- Effort: L
- Area: Utilities/
- Evidence: `macos-launcher/Sources/LauncherApp/Utilities/` contains 21 files at one level:
  - Formatters: `RelativeDateFormatter.swift`, `TokenClassifier.swift`
  - Coordinators: `TaskListCoordinator.swift`, `NavigationCoordinator.swift`, `InteractionCoordinator.swift`, `InteractionContextCoordinator.swift`
  - Services: `LauncherActionService.swift`, `SerialTaskQueue.swift`, `ParseErrorToastScheduler.swift`
  - Design: `DesignTokens.swift`, `StatusColor.swift`, `AssetIcon.swift`
  - Engine: `CompletionEngine.swift`, `HighlightSpan.swift`
  - Keys: `KeyCode.swift`, `UserDefaultsKeys.swift`
  - Plus Themes/ subfolder (5 files)
- Smells: flat structure, navigation overhead
- Problem (rough): Finding related files requires scanning 21 items. Conceptually related files (e.g., all coordinators) are not grouped.
- Suggested fix (rough):
  - Create `Utilities/Coordinators/` for *Coordinator files
  - Create `Utilities/Services/` for action service, queue, toast scheduler
  - Create `Utilities/Design/` for design tokens, status colors, asset icons (move Themes/ under it)
  - Create `Utilities/Formatters/` for date formatter, token classifier
  - Keep `Utilities/` for truly miscellaneous helpers
- Safety net: Update imports across codebase; run `swift build` after each move

## Archive (Resolved / No longer reproducible)
### DEBT-0019: `blocks:` property is defined but not parsed
- Resolved on: 2025-12-30
- Note: Added `blocks:` tokenization and parsing with unit coverage for mixed depends/blocks inputs.
### DEBT-0018: CLI table formatting relies on date-based indentation hack
- Resolved on: 2025-12-30
- Note: Reworked wrapping to use explicit hanging-indent detection and kept wrap tests green.
### DEBT-0017: Parser uses panics/unwraps in production paths
- Resolved on: 2025-12-30
- Note: Replaced parser unwraps/panics with error handling and defensive token navigation.
### DEBT-0016: Task loading uses per-task queries (N+1 risk)
- Resolved on: 2025-12-30
- Note: Batched task hydration for tags/annotations/history/links in `task_read`.
### DEBT-0015: Task domain logic is concentrated in a monolithic module
- Resolved on: 2025-12-30
- Note: Split `task.rs` into focused model/data/properties modules with re-exports and tests.
### DEBT-0013: External link statuses are stringly-typed and mapped in the view
- Resolved on: 2025-12-30
- Note: Added typed GitLab state/pipeline enums with unknown fallback and moved icon/label mapping into model helpers.
### DEBT-0023: Selected/hover states risk low contrast in dark theme
- Resolved on: 2025-12-30
- Note: Increased contrast for selected/hover states and text in list, headers, detail badge, and completion menu.
### DEBT-0022: Detail view presents raw values with weak hierarchy
- Resolved on: 2025-12-30
- Note: Added formatted dates/UUIDs with tooltips and aligned typography/spacing.
### DEBT-0021: Search input affordance is weak and vertically cramped
- Resolved on: 2025-12-30
- Note: Added placeholder and increased input height/spacing to match text size.
### DEBT-0020: UI lacks centralized design tokens (spacing, radii, type)
- Resolved on: 2025-12-30
- Note: Introduced `DesignTokens` and aligned core view spacing/typography/radii.
### DEBT-0014: Navigation bindings/keyboard handling are split across panes
- Resolved on: 2025-12-30
- Note: Centralized escape/normal-mode handling in `InteractionCoordinator` and delegated view handling with tests.
### DEBT-0012: Command palette flows lack unit coverage
- Resolved on: 2025-12-30
- Note: Added coordinator + view model tests for filtering, selection bounds, and submit-without-task flow.
### DEBT-0011: LauncherViewModel still spans multiple domains
- Resolved on: 2025-12-30
- Note: Extracted `CommandPaletteCoordinator` and `CompletionCoordinator`, wired orchestration, and added tests.
### DEBT-0010: Token types are stringly-typed across highlighting and classification
- Resolved on: 2025-12-30
- Note: Introduced `TokenType` enum with unknown fallback and updated classifier/highlighting/tests.
### DEBT-0009: Collapsed-group persistence uses stringly-typed keys across tests
- Resolved on: 2025-12-30
- Note: Added `UserDefaultsKeys` helper and switched production/tests to shared keys.
### DEBT-0008: Keyboard shortcut mappings split across view layers
- Resolved on: 2025-12-30
- Note: Centralized normal-mode key mapping in `KeyHandlingDecider` and added tests.
### DEBT-0007: Duplicated prefix logic in completion context detection
- Resolved on: 2025-12-30
- Note: Consolidated prefix checks into shared helper lists in `CompletionEngine` and expanded context tests.
### DEBT-0006: TaskListView layout constants are hard-coded
- Resolved on: 2025-12-30
- Note: Centralized layout constants in `TaskListView` for padding, spacing, and column widths.
### DEBT-0005: KeyHandlingTextView mixes input handling and rendering without tests
- Resolved on: 2025-12-30
- Note: Extracted key handling decisions into `KeyHandlingDecider` with unit tests for key bindings.
### DEBT-0001: LauncherViewModel is a god object with mixed responsibilities
- Resolved on: 2025-12-30
- Note: Extracted action service, completion engine, toast scheduler, task list coordinator, and navigation coordinator; `LauncherViewModel` now orchestrates these helpers with tests in place.
### DEBT-0004: API client error handling lacks direct tests
- Resolved on: 2025-12-30
- Note: Added URLProtocol-backed tests for base URL override and non-2xx error payload handling.
### DEBT-0003: Hard-coded key codes and timing constants in input handling
- Resolved on: 2025-12-30
- Note: Introduced named key code constants and centralized toast timing constants.
### DEBT-0002: Token classification is duplicated and stringly-typed
- Resolved on: 2025-12-30
- Note: Centralized token type checks in `TokenClassifier` and added tests; highlight and completion paths now share the same classification helpers.

## Definition of Done (for this skill)
- [x] DEBT-TODO.md exists and follows the required structure
- [x] Every Open issue has: Priority, Effort, Evidence, Problem, Suggested fix, Safety net
- [x] Existing issues were re-validated; resolved ones moved out of Open
- [x] No duplicate issues for the same underlying problem
