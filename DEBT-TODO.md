# DEBT TODO

## Summary
All debt issues resolved.

## Open Issues
(none)

## Archive (Resolved / No longer reproducible)
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
