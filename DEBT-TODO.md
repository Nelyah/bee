# DEBT TODO

## Open Issues
### DEBT-0034: No way to save a search filter as a reusable report
- Priority: P0
- Effort: L
- Area: bee-api config + macos-launcher report UI
- Evidence: `crates/bee-api/src/config.rs`, `macos-launcher/Sources/LauncherApp/Models/ConfigModels.swift`, `macos-launcher/Sources/LauncherApp/ViewModels/LauncherViewModel.swift`
- Smells: missing-feature, data-persistence
- Problem (rough): Reports are static from config; users cannot save a current filter as a named report. No storage mechanism exists for user-defined reports.
- Suggested fix (rough):
  - Order: Should be done before DEBT-0030 if you want the selector to include user-defined reports.
  - Data model: introduce a user-report entity (name, filters, columns, column_names, is_default, created_at, updated_at). Decide whether to allow user overrides of columns or only filters.
  - Storage: add a DB table + migration in `crates/migration` and expose CRUD in `bee-core` storage layer.
  - API: add endpoints to list/create/delete/update user reports (e.g., `/v1/reports`), and update `/v1/config` to merge static + user-defined reports (user reports should not overwrite built-ins unless explicitly named the same).
  - Merge logic: define precedence rules (e.g., same-name user report overrides static, or disallow duplicates and surface an error).
  - UI flow: add “Save current filter as report…” action in command palette or menu; prompt for name; call API; refresh report list.
  - UX details: handle name collisions, validation, and empty filter cases; show success/failure toast.
  - Compatibility: ensure existing configs keep working; no change required if user reports are absent.
- Safety net: API tests for list/create/update/delete + config merge; migration test; UI tests for save flow + selecting newly saved report; add unit tests for merge precedence rules.

## Done
### DEBT-0035: Task list rows cannot expand to show links/annotations ✅
- Status: Completed (2025-12-31)
- Priority: P1
- Effort: M
- Area: macos-launcher list row UI
- Evidence: `macos-launcher/Sources/LauncherApp/Views/TaskRow.swift`, `macos-launcher/Sources/LauncherApp/Views/Components/TaskRowLinksPreview.swift`, `macos-launcher/Sources/LauncherApp/Views/Components/TaskRowAnnotationsPreview.swift`
- Resolution: Added expandable task rows with condensed previews of links and annotations. Each row shows a chevron indicator that toggles expansion. Tab key (in normal mode) toggles expansion. Expanded content shows compact link chips (provider icon + title + sync status) and annotation rows (date + text), with "+N more" indicators when truncated. Data lazy-loads when expanding. Added hint bar update showing "Tab: Expand" when task selected in normal mode.
- Safety net: Unit tests for expansion toggle (4 tests), Tab key mapping (1 test), and hint bar behavior (3 tests).

### DEBT-0039: Window configuration is scattered and fragile ✅
- Status: Completed (2025-12-31)
- Priority: P2
- Effort: M
- Area: macos-launcher window setup
- Evidence: `macos-launcher/Sources/LauncherApp/Utilities/Window/WindowConfiguration.swift`, `macos-launcher/Sources/LauncherApp/Views/Components/WindowAccessor.swift`
- Resolution: Consolidated window configuration into single-source-of-truth architecture. Created `WindowConfiguration.swift` documenting the complete "recipe" for borderless windows with only 6 essential NSWindow settings (reduced from 9, removed redundant ones). Created `WindowAccessor.swift` using idiomatic `NSViewRepresentable` pattern instead of iterating `NSApplication.shared.windows`. Removed 25-line `configureWindowAppearance()` from ContentView. All settings now documented with "why" explanations.
- Safety net: Manual verification of window appearance (no title bar gap, draggable, rounded corners, no traffic lights, works after focus changes).

### DEBT-0033: Missing "Go to…" menu for project-scoped views ✅
- Status: Completed (2025-12-31)
- Priority: P1
- Effort: M
- Area: macos-launcher command palette + filters
- Evidence: `macos-launcher/Sources/LauncherApp/ViewModels/LauncherViewModel.swift`, `macos-launcher/Sources/LauncherApp/Utilities/Services/LauncherActionService.swift`, `macos-launcher/Sources/LauncherApp/Utilities/CommandPalette/SectionContributors.swift`
- Resolution: Added "Go To" section in command palette showing all projects with "Current" indicator. Selecting a project sets a scope that layers as three-way AND: (report defaults) AND (project scope) AND (user input). Two clear mechanisms: clickable ProjectScopeChipView in header and "Clear Project Scope" command palette action. Filter composition handled in LauncherActionService with ProjectFilter type.
- Safety net: Unit tests for filter composition (4 tests), GoToSectionContributor (5 tests), and ActionsSectionContributor scope actions (2 tests).

### DEBT-0029: Bottom hint bar overlaps last list row ✅
- Status: Completed (2025-12-31)
- Priority: P1
- Effort: M
- Area: macos-launcher list layout
- Evidence: `macos-launcher/Sources/LauncherApp/Views/TaskListView.swift`
- Resolution: Used `safeAreaInset(edge: .bottom)` on ScrollView to reserve space for hint bar (50pt). This makes `scrollTo`, G command, and all scroll calculations respect the reserved area. Direction-aware anchor for smooth UX. Added frosted glass effect to hint bar.
- Safety net: Manual verification; last row visible when scrolled to bottom.

### DEBT-0037: Missing back navigation affordance in non-main views ✅
- Status: Completed (2025-12-31)
- Priority: P1
- Effort: S
- Area: macos-launcher navigation
- Evidence: `macos-launcher/Sources/LauncherApp/Views/TaskDetailView.swift`
- Resolution: Added clickable back button (chevron.left + "Back" text) to TaskDetailView header. Uses existing `onClose` callback. Button styled with `.plain` and `contentShape(Rectangle())` for full-area click handling.
- Safety net: Manual verification; escape key continues to work alongside back button.

### DEBT-0038: Command palette lacks a "Shortcuts" footer section ✅
- Status: Completed (2025-12-31)
- Priority: P1
- Effort: M
- Area: macos-launcher command palette
- Evidence: `macos-launcher/Sources/LauncherApp/Utilities/CommandPalette/SectionContributors.swift`
- Resolution: Added `ShortcutsSectionContributor` with priority 100 (appears last). Displays Escape, Return, Up/Ctrl+P, Down/Ctrl+N shortcuts. Section hides when filtering. Registered in `LauncherViewModel` during command palette setup.
- Safety net: Contributor integration tested through existing section builder tests.

### DEBT-0032: Group-by options are not configurable or user-visible ✅
- Status: Completed (2025-12-31)
- Priority: P1
- Effort: M
- Area: macos-launcher grouping + command palette
- Evidence: `macos-launcher/Sources/LauncherApp/Utilities/Grouping/`
- Resolution: Extended TaskGroupingStrategy protocol with `groupKeys()` and `showsHeaders`. Added DueDateGroupingStrategy (overdue/today/tomorrow/future/no due date), TagGroupingStrategy (tasks appear in all tag groups), and NoGroupingStrategy (flat list). Exposed "Group By" menu in command palette with current selection indicator. Persisted selection in UserDefaults.
- Safety net: Added GroupingStrategyTests with coverage for all strategies, bucket ordering, multi-group support, and coordinator integration.

### DEBT-0031: Clicking the input in normal mode doesn't return to insert mode ✅
- Status: Completed (2025-12-31)
- Priority: P1
- Effort: S
- Area: macos-launcher input focus handling
- Evidence: `macos-launcher/Sources/LauncherApp/Views/Components/TokenHighlightTextView.swift`, `macos-launcher/Sources/LauncherApp/Views/ContentView.swift`
- Smells: UX-regression, focus-state
- Problem (rough): When in normal mode, clicking the text input does not reliably set `isInsertMode = true` or focus the input. This breaks expected macOS behavior and frustrates mouse users.
- Resolution: Keep the window keyable while hiding the title bar, and force focus on mouse-down when in insert mode.
- Safety net: Added unit test coverage for mouse-down focus requests.
### DEBT-0036: Command palette architecture is hard to extend ✅
- Status: Completed (2025-12-31)
- Priority: P1
- Effort: L
- Area: macos-launcher command palette
- Evidence: `macos-launcher/Sources/LauncherApp/ViewModels/CommandPaletteCoordinator.swift`, `macos-launcher/Sources/LauncherApp/Views/CommandPaletteView.swift`, `macos-launcher/Sources/LauncherApp/ViewModels/LauncherViewModel.swift`
- Smells: SRP, coupling, extensibility
- Problem (rough): The command palette mixes action selection, suggestion filtering, and view logic, making new workflows (group-by, go-to, shortcuts sections) difficult to add.
- Suggested fix (rough):
  - Order: Foundational for DEBT-0032, DEBT-0033, and DEBT-0038 (sectioned palette).
  - Data model:
    - Add `CommandPaletteSection` (id, title, items).
    - Add `CommandPaletteItem` enum (action, suggestion, report, groupBy, shortcut, header, etc.).
    - Add `CommandPaletteStack` to support nested menus (push/pop).
    - Registration: allow any feature to register a palette entry with optional section + keybind, and optionally define submenu nodes.
  - Navigation behavior:
    - Escape should pop one level of the stack; only close palette if already at root.
    - Enter should drill into a submenu if the selected item is a container.
    - Provide a breadcrumb or header indicating current menu path.
    - Submenus should be explicit menu nodes registered to the palette (not arbitrary suggestion items).
    - At root, Escape closes the palette and returns to the prior task list mode.
  - Coordinator refactor:
    - Move filtering/ranking into a separate `CommandPaletteDataSource` or builder.
    - Coordinator should own navigation stack + selection index only.
    - Expose a single `currentSections` computed property for the view.
  - View updates:
    - Render sections with headers.
    - Support nested menus and “Back” row at top when not at root.
    - Selection should move linearly through all items; section headers are not selectable.
  - Extensibility:
    - Create registry-style functions for section contributors (actions, reports, group-by, goto, shortcuts).
    - Allow new sections to be appended without modifying view logic.
  - Interaction handling:
    - Map escape to “back one level” in `InteractionCoordinator` or view model.
    - Ensure command palette close only occurs at root.
- Safety net:
  - Unit tests for stack navigation (push/pop), escape behavior, and selection persistence.
  - Tests for section ordering and filtering with multiple sections.
  - UI test to verify escape from nested menu returns to previous menu, not full close.

## Archive (Resolved / No longer reproducible)
### DEBT-0030: Report selector is not clickable in the main search header
- Resolved on: 2025-12-31
- Note: Replaced the static badge with a report menu button wired to `selectReport` and added a small pressed-state flicker.
### DEBT-0028: Utilities/ folder is flat with 21 files
- Resolved on: 2025-12-30
- Note: Created Coordinators/, Services/, Design/, Formatters/ subfolders. Moved 17 files to appropriate locations. Utilities/ root now has 5 misc files.
### DEBT-0027: Hover state pattern repeated with identical .onHover handlers
- Resolved on: 2025-12-30
- Note: Created HoverableButton and HoverableLink components. Eliminated 5 @State hover variables from ExternalLinkRow and ExternalLinksProviderSection.
### DEBT-0024: TaskDetailView embeds large private structs
- Resolved on: 2025-12-30
- Note: Extracted ExternalLinkRow (323 LOC), LinkStatusBadge, and TimelineRow to Views/Components/. TaskDetailView reduced from 796 to 369 lines.
### DEBT-0025: ApiClient duplicates error handling across send/get/post
- Resolved on: 2025-12-30
- Note: Extracted validateResponse() helper to consolidate HTTP response validation from send/get/post methods.
### DEBT-0026: Button style duplication between QuietRefreshButtonStyle and QuietTextButtonStyle
- Resolved on: 2025-12-30
- Note: Created unified QuietButtonStyle with configurable parameters in new Styles/ folder.
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
