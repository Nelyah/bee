# DEBT TODO

## Summary
- LauncherViewModel is still a large orchestrator, and remaining responsibilities (API + navigation) keep change risk high.
- Core utilities were extracted (completion, toast scheduling, task list coordination), but the view model still owns too many concerns.
- API client behavior now has tests; remaining debt is localized to view model structure.

## Open Issues
### DEBT-0001: LauncherViewModel is a god object with mixed responsibilities
- Priority: P1
- Effort: M
- Area: macos-launcher ViewModels
- Evidence: `macos-launcher/Sources/LauncherApp/ViewModels/LauncherViewModel.swift:7`, `macos-launcher/Sources/LauncherApp/Utilities/CompletionEngine.swift:1`, `macos-launcher/Sources/LauncherApp/Utilities/ParseErrorToastScheduler.swift:1`, `macos-launcher/Sources/LauncherApp/Utilities/TaskListCoordinator.swift:1`
- Smells: SRP, complexity, coupling
- Problem (rough): The view model still handles API requests, parsing, and UI navigation in a single large class. Completion, parse-error toast scheduling, and task list selection were extracted, but remaining concerns are still tightly coupled and make change risk high.
- Suggested fix (rough):
- Extract API/parse orchestration into a dedicated service (e.g., `LauncherActionService`).
- Move navigation state management into a small coordinator to reduce UI coupling.
- Keep `LauncherViewModel` as a thin orchestrator that composes these components.
- Safety net: Expand unit tests around completion detection, toast scheduling, and selection logic; add tests for the extracted components.

## Archive (Resolved / No longer reproducible)
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
