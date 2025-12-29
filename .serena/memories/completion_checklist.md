# Completion checklist

When finishing a task:
- Ensure new functions have docstrings.
- Add/update unit tests for new or changed behavior.
- Run `cargo fmt`.
- Run `cargo clippy --all-targets --all-features`.
- Run `cargo test` (or crate-specific tests when appropriate).
- Summarize changes and mention tests run.