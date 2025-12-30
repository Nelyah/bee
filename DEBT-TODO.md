# DEBT TODO

## Summary
- External link suggestion state/pipeline values are stringly-typed and mapped directly in the view.
- Core task domain types are concentrated in a single large module with mixed responsibilities.
- DB task loading performs per-task queries, risking N+1 patterns and scaling issues.
- CLI formatting and parser error handling rely on hacks/unwraps instead of explicit behavior.
- UI styling tokens (spacing, typography, radii, colors) are inconsistent across launcher views.
- Detail/list/palette views show inconsistent hierarchy and low-contrast states, making key info hard to scan.

## Open Issues
### DEBT-0013: External link statuses are stringly-typed and mapped in the view
- Priority: P2
- Effort: M
- Area: macos-launcher/Models + Views
- Evidence: macos-launcher/Sources/LauncherApp/Models/ExternalLinkModels.swift:3-24, macos-launcher/Sources/LauncherApp/Views/CommandPaletteView.swift:177-298
- Smells: magic-string, duplication, coupling
- Problem (rough): GitLab MR `state`/`pipelineStatus` are plain strings and the view hard-codes mapping to icons/labels. This duplicates business rules in the UI layer and risks mismatches if the API adds new states.
- Suggested fix (rough):
- Introduce enums for MR state and pipeline status with an `unknown(String)` fallback.
- Decode raw strings into the enums in `ExternalLinkModels`.
- Move icon/label mapping into model helpers or a dedicated formatter.
- Update `CommandPaletteView` to consume typed status data.
- Safety net: Unit tests for enum decoding and mapping; add a UI snapshot/unit test if feasible.

### DEBT-0015: Task domain logic is concentrated in a monolithic module
- Priority: P1
- Effort: M
- Area: crates/bee-core/task
- Evidence: crates/bee-core/src/task.rs:1-1078
- Smells: SRP, complexity, coupling
- Problem (rough): `task.rs` mixes multiple responsibilities (Task model, TaskData store, property parsing helpers, history/urgency computation, serialization). The file size and cross-cutting logic make it difficult to change or test in isolation.
- Suggested fix (rough):
- Split `task.rs` into focused modules (`task/model.rs`, `task/data.rs`, `task/properties.rs`, `task/history.rs`).
- Move orchestration methods (`apply`, `add_task`, `filter`) into `TaskData`-focused modules.
- Keep public API stable via `mod task; pub use ...` re-exports.
- Safety net: Keep existing task tests green; add focused unit tests per module.

### DEBT-0016: Task loading uses per-task queries (N+1 risk)
- Priority: P1
- Effort: M
- Area: crates/bee-core/storage/db
- Evidence: crates/bee-core/src/storage/db/task_read.rs:92-343
- Smells: performance, coupling, complexity
- Problem (rough): `tasks_from_filter` iterates models and `task_model_to_object` performs multiple queries per task (project, tags, annotations, history, links), which can cause N+1 query patterns and poor scaling as task counts grow.
- Suggested fix (rough):
- Batch-fetch related entities (tags, annotations, history, links) for all tasks in one query per table.
- Build maps keyed by task_id to assemble `Task` objects without per-task queries.
- Consider SeaORM relations/preload once the ORM version allows.
- Safety net: Add integration tests that validate task hydration; add a lightweight benchmark or query-count assertion in tests if possible.

### DEBT-0017: Parser uses panics/unwraps in production paths
- Priority: P2
- Effort: S
- Area: crates/bee-core/parser
- Evidence: crates/bee-core/src/parser.rs:33-308
- Smells: error-handling, correctness-risk
- Problem (rough): Date parsing and token navigation use `unwrap` and `panic!`, which can crash on unexpected input or parser state drift.
- Suggested fix (rough):
- Replace panics/unwraps with `Result` errors that propagate to callers.
- Centralize conversion failures into a structured parse error type.
- Add tests for invalid date expressions and backtracking edge cases.
- Safety net: Add parser tests for malformed inputs; ensure CLI/API surfaces clean errors.

### DEBT-0018: CLI table formatting relies on date-based indentation hack
- Priority: P2
- Effort: S
- Area: crates/bee-cli/table
- Evidence: crates/bee-cli/src/table.rs:470-520
- Smells: magic-number, hack, coupling
- Problem (rough): `wrap_text` changes indentation based on a date regex and inline comments note it as a hack. This behavior is implicit and not validated by tests.
- Suggested fix (rough):
- Move annotation formatting into a dedicated formatter that explicitly controls indentation.
- Add unit tests for wrapping annotations vs. plain text.
- Document the formatting rule in code or config.
- Safety net: Extend `table_test.rs` to assert expected wrapping behavior.

### DEBT-0019: `blocks:` property is defined but not parsed
- Priority: P2
- Effort: M
- Area: crates/bee-core/task
- Evidence: crates/bee-core/src/task/task_prop_parser.rs:1-120, crates/bee-core/src/task.rs:90-120
- Smells: missing-feature, docs
- Problem (rough): `TaskProperties` supports `blocks`, but the property parser does not recognize `blocks:` tokens (explicit TODO). This creates a mismatch between data model and CLI/API input capabilities.
- Suggested fix (rough):
- Implement `blocks:` parsing in `TaskPropertyParser` (mirroring `depends:` handling).
- Add parser tests for `blocks:` and mixed `depends:`/`blocks:` inputs.
- Update any user-facing docs/help if needed.
- Safety net: Add unit tests in `task_prop_parser_test.rs` and integration tests for actions that rely on blocking relationships.

### DEBT-0020: UI lacks centralized design tokens (spacing, radii, type)
- Priority: P2
- Effort: S
- Area: macos-launcher/Views + Utilities
- Evidence: macos-launcher/Sources/LauncherApp/Views/TaskListView.swift:3-25, macos-launcher/Sources/LauncherApp/Views/TaskDetailView.swift:9-46, macos-launcher/Sources/LauncherApp/Views/CommandPaletteView.swift:25-58, macos-launcher/Sources/LauncherApp/Views/Components/CompletionMenuView.swift:31-55, macos-launcher/Sources/LauncherApp/Views/Components/ToastView.swift:14-33
- Smells: duplication, inconsistency
- Problem (rough): Multiple views define their own font sizes, paddings, and corner radii, leading to uneven rhythm and visual inconsistency across list, detail, palette, and toast surfaces.
- Suggested fix (rough):
- Introduce a `DesignTokens` (or expand `TaskListLayout`) with shared spacing, radius, and type scale.
- Replace ad-hoc values with tokens and align common elements (cards, pills, rows).
- Document the intended hierarchy for titles/body/metadata.
- Safety net: Add snapshot/UI tests for core views (list/detail/palette) to catch visual drift.

### DEBT-0021: Search input affordance is weak and vertically cramped
- Priority: P2
- Effort: S
- Area: macos-launcher/Views
- Evidence: macos-launcher/Sources/LauncherApp/Views/TaskListView.swift:33-94, macos-launcher/Sources/LauncherApp/Views/Components/TokenHighlightTextView.swift:24-39
- Smells: UX, layout
- Problem (rough): The search field uses a text view with no placeholder and a 22pt height while the font is 18pt, which makes it look tight and less discoverable when empty.
- Suggested fix (rough):
- Add placeholder/ghost hint when `input` is empty (e.g., “Search tasks…”).
- Increase input height and padding to match the text size.
- Align the magnifying glass with baseline using consistent vertical metrics.
- Safety net: Add a preview or UI snapshot for empty input and focused input states.

### DEBT-0022: Detail view presents raw values with weak hierarchy
- Priority: P2
- Effort: S
- Area: macos-launcher/Views
- Evidence: macos-launcher/Sources/LauncherApp/Views/TaskDetailView.swift:14-43, macos-launcher/Sources/LauncherApp/Views/TaskRow.swift:29-79
- Smells: hierarchy, readability
- Problem (rough): Detail view shows raw UUIDs and ISO timestamps without formatting while list rows show relative dates. This creates a jarring shift in visual hierarchy and makes details hard to scan.
- Suggested fix (rough):
- Format UUIDs and dates consistently with list views (short/relative + tooltip for full values).
- Increase label/value contrast or spacing to separate metadata from the title.
- Consider grouping metadata into sections (Timing, Tags, Status).
- Safety net: Add snapshot/UI tests for detail view with long values.

### DEBT-0023: Selected/hover states risk low contrast in dark theme
- Priority: P2
- Effort: S
- Area: macos-launcher/Views + Themes
- Evidence: macos-launcher/Sources/LauncherApp/Views/Components/CompletionMenuView.swift:37-63, macos-launcher/Sources/LauncherApp/Views/GroupHeaderRow.swift:10-50, macos-launcher/Sources/LauncherApp/Views/TaskDetailView.swift:18-30, macos-launcher/Sources/LauncherApp/Utilities/Themes/OneDarkTheme.swift:36-78
- Smells: accessibility, contrast
- Problem (rough): Selected states use `ThemeManager.current.base` text on blue backgrounds and subtle surface0/surface1 fills, which may not meet contrast expectations for readability, especially at 10–12pt sizes.
- Suggested fix (rough):
- Define explicit selected-state text colors per theme (e.g., `onAccent`).
- Increase contrast for hover/selected surfaces and small metadata text.
- Add a lightweight contrast check in design review or documentation.
- Safety net: Add snapshot comparisons for selected/hover states in list and completion menu.

## Archive (Resolved / No longer reproducible)
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
- ✅ DEBT-TODO.md exists and follows the required structure
- ✅ Every Open issue has: Priority, Effort, Evidence, Problem, Suggested fix, Safety net
- ✅ Existing issues were re-validated; resolved ones moved out of Open
- ✅ No duplicate issues for the same underlying problem
