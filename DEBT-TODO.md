# DEBT TODO

## Summary
- `CompletionEngine.detectContext` repeats prefix checks across token- and string-based paths; adding a new prefix requires edits in several branches.
- Keyboard shortcuts are split between `KeyHandlingDecider` and `ContentView`’s normal-mode monitor, which can drift over time.
- Collapsed-group persistence keys are private string literals duplicated in tests.
- Token classification still relies on stringly-typed token names in `TokenClassifier`/`HighlightSpan`, risking silent regressions.

## Open Issues
### DEBT-0009: Collapsed-group persistence uses stringly-typed keys across tests
- Priority: P2
- Effort: S
- Area: macos-launcher grouping persistence
- Evidence: `macos-launcher/Sources/LauncherApp/ViewModels/LauncherViewModel.swift:collapsedGroupsKey`, `macos-launcher/Tests/LauncherAppTests/LauncherViewModelTests.swift:collapsedGroupsKey`
- Smells: magic-string, coupling
- Problem (rough): Persistence keys are duplicated as string literals in tests because the production keys are private. Renaming keys requires updating multiple locations and can silently break tests.
- Suggested fix (rough):
- Expose keys via an internal `UserDefaultsKeys` or `SettingsStore` helper.
- Update tests to reference shared keys instead of local literals.
- Consider injecting a `UserDefaults` wrapper for easier future refactors.
- Safety net: Existing persistence tests should continue to pass after refactor.

### DEBT-0010: Token types are stringly-typed across highlighting and classification
- Priority: P2
- Effort: M
- Area: macos-launcher parsing/highlighting
- Evidence: `macos-launcher/Sources/LauncherApp/Models/ParseModels.swift:TokenSpan.tokenType`, `macos-launcher/Sources/LauncherApp/Utilities/TokenClassifier.swift`, `macos-launcher/Sources/LauncherApp/Utilities/HighlightSpan.swift`
- Smells: magic-string, coupling
- Problem (rough): Token types are represented as raw strings across parsing, classification, and highlighting. A typo or backend change can silently break highlighting or completion behavior without compiler errors.
- Suggested fix (rough):
- Introduce a `TokenType` enum with raw values matching API payloads.
- Convert `TokenSpan.tokenType` to `TokenType` in decoding (with safe fallback).
- Update `TokenClassifier` and `HighlightSpan` to use the enum instead of string literals.
- Safety net: Add tests for decoding unknown token types and for classification/highlighting on expected tokens.

## Archive (Resolved / No longer reproducible)
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
