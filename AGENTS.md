# AGENTS.md

Guidance for Codex when working in this repository.

- Keep changes minimal and focused. Prefer existing conventions and keep instructions actionable.
- Never remove TODO comments unless the TODO has been fully addressed.
- If you think that what you are being asked is a bad idea, stop and say so. Explain why.
- If you think the user is missing something, let them know.
- If you are looking for the macOS version or Xcode/Swift toolchain, look in the ./macos-launcher/ folder
- NEVER EVER EVER commit with `--no-verify`. If there are issues, you need to fix them before commiting
- NEVER disable swiftlint warnings without asking first 
- When you encounter flaky tests, you should stop to fix them. Run them multiple times to figure out why they are flaky.

## Quick start
```bash
# Build the workspace
cargo build

# Run CLI (replace <args> with a subcommand like "list" or "help")
cargo run -- <args>

# Run API server
cargo run -p bee-api
```

## Test & Dev commands
```bash
pre-commit run --all-files
```

## Repo layout (high level)
- `crates/bee-core`: Core domain logic, task models, filters, storage abstractions
- `crates/bee-actions`: Action implementations and undo
- `crates/bee-cli`: CLI entry point and presentation
- `crates/bee-api`: REST API server
- `crates/migration`: SeaORM migrations
- `macos-launcher/`: macOS launcher UI

## Key concepts (brief)
- Task flow: parse args → build filters → load tasks (SQLite) → execute action → persist → log undo.
- Filters are composable trees; use helpers in `filters::and()` / `filters::or()` / `filters::from()`.
- Undo is required for any action that mutates tasks.
- `TaskProperties` are user-facing inputs; they are applied to `Task` with `task.apply_properties(props)`.

## Important files
- `crates/bee-core/src/task.rs`
- `crates/bee-core/src/filters.rs`
- `crates/bee-core/src/storage/mod.rs`
- `crates/bee-actions/src/action_type.rs`
- `crates/bee-cli/src/bee.rs`

## Adding features (short)
### New action
1. Add `crates/bee-actions/src/action_<name>.rs`
2. Implement `TaskAction` (often via `impl_taskaction_from_base!`)
3. Register in `action_type.rs` and `lib.rs`

### New filter
1. Add filter struct in `crates/bee-core/src/filters/filters_impl.rs`
2. Implement `Filter` with `#[typetag::serde]`
3. Update `FilterKind` and parser

## Testing pattern
Unit tests are colocated with source files using:
```rust
#[path = "module_test.rs"]
#[cfg(test)]
mod module_test;
```

## Docs lookup
Always use Context7 when you need code generation, setup/configuration steps, or library/API documentation.

## Setup
Initialise Serena and figure out what it can do
