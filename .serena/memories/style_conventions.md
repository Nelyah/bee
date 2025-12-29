# Style & conventions

- New functions should have docstrings (per AGENTS.md).
- New functions should have unit tests (per AGENTS.md).
- Keep changes minimal and cohesive; avoid new deps unless justified.
- Use Result-based error handling; avoid panics outside tests.
- Tests are colocated with source modules (some in-module test blocks).
- DB invariants are enforced via migrations; SQLite foreign keys must be enabled.

Rust-specific:
- Follow existing naming (snake_case, PascalCase types).
- Use Tokio for async paths.
