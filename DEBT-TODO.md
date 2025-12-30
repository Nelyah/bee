# DEBT TODO

## Summary
- LauncherViewModel is a large, multi-responsibility class mixing networking, parsing, completion logic, and UI state, which makes changes risky.
- Keyboard handling relies on hard-coded key codes and timing constants, which are opaque and hard to maintain.
- API client behavior is largely untested, leaving error handling and env configuration without coverage.

## Open Issues
### DEBT-0001: LauncherViewModel is a god object with mixed responsibilities
- Priority: P1
- Effort: M
- Area: macos-launcher ViewModels
- Evidence: `macos-launcher/Sources/LauncherApp/ViewModels/LauncherViewModel.swift:7`
- Smells: SRP, complexity, coupling
- Problem (rough): The view model handles API requests, parsing, completion caching, selection logic, toast scheduling, and UI navigation in a single 500+ line class. This increases cognitive load and makes changes to one concern more likely to affect unrelated behavior.
- Suggested fix (rough):
  - Extract a `CompletionEngine` that owns context detection, prefix parsing, and filtering.
  - Extract a `ToastScheduler` (or similar) to own delayed error toasts.
  - Extract a `TaskListCoordinator` for selection and sorting behavior.
  - Keep `LauncherViewModel` as a thin orchestrator that composes these components.
- Safety net: Expand unit tests around completion detection, toast scheduling, and selection logic; add tests for the extracted components.

### DEBT-0003: Hard-coded key codes and timing constants in input handling
- Priority: P2
- Effort: S
- Area: macos-launcher text input
- Evidence: `macos-launcher/Sources/LauncherApp/Views/Components/TokenHighlightTextView.swift:133`, `macos-launcher/Sources/LauncherApp/ViewModels/LauncherViewModel.swift:45`
- Smells: magic-number, docs
- Problem (rough): Keyboard shortcuts and timing values (key codes, toast delays, animation durations) are embedded as literal numbers, which makes intent opaque and complicates changes or platform adjustments.
- Suggested fix (rough):
  - Replace key codes with named constants or helper enums (and add comments for non-obvious values).
  - Lift timing constants (toast delay, animation durations) into a configuration struct or static constants.
  - Document the bindings in one place to avoid drift.
- Safety net: Lightweight tests for key handling paths (or snapshot tests where feasible) and validation that configured constants are applied.

### DEBT-0004: API client error handling lacks direct tests
- Priority: P2
- Effort: S
- Area: macos-launcher networking
- Evidence: `macos-launcher/Sources/LauncherApp/Networking/ApiClient.swift:1`, `macos-launcher/Tests/LauncherAppTests/LauncherViewModelTests.swift:1`
- Smells: missing-tests
- Problem (rough): The API client’s behavior (base URL selection, non-2xx errors, error payload decoding) is not directly unit tested, leaving key networking behavior unverified.
- Suggested fix (rough):
  - Add tests around `decodeErrorMessage` and non-2xx handling using a stubbed URL protocol or injectable session.
  - Add a small test to confirm environment variable overrides for the base URL.
- Safety net: Unit tests for API client error cases and base URL configuration.

## Archive (Resolved / No longer reproducible)
### DEBT-0002: Token classification is duplicated and stringly-typed
- Resolved on: 2025-12-30
- Note: Centralized token type checks in `TokenClassifier` and added tests; highlight and completion paths now share the same classification helpers.

## Definition of Done (for this skill)
- ✅ DEBT-TODO.md exists and follows the required structure
- ✅ Every Open issue has: Priority, Effort, Evidence, Problem, Suggested fix, Safety net
- ✅ Existing issues were re-validated; resolved ones moved out of Open
- ✅ No duplicate issues for the same underlying problem
