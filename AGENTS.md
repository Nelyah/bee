# AGENTS.md

Guidance for Codex when working in this repository.

## Very important rules

- Keep changes minimal and focused. Prefer existing conventions and keep instructions actionable.
- Never remove TODO comments unless the TODO has been fully addressed.
- If you think that what you are being asked is a bad idea, stop and say so. Explain why.
- If you think the user is missing something, let them know.
- If you are looking for the macOS version or Xcode/Swift toolchain, look in the ./macos-launcher/ folder
- NEVER EVER EVER commit with `--no-verify`. If there are issues, you need to fix them before commiting
- NEVER disable swiftlint warnings without asking first

- When you encounter flaky tests, do the following:
    - Look at the flaky test, and fix it. It may require being run multiple times

- When you explore a new folder that does NOT have an AGENTS.md in the code:
    - Stop what you were doing
    - Document VERY SHORTLY what this current folder is about and what the files do (one line per file)
    - Make a CLAUDE.md symbolic link that points to that AGENTS.md
    - Continue what you were doing

- If you read an AGENTS.md and you realise it has outdated information:
    - Stop what you were doing
    - Update the outdated information in the AGENTS.md
    - Continue what you were doing

- When you learn to do something specific in the code base, or have understood a way to use a complicated pattern in the code base, do the following:
    - Stop what you are doing
    - Check whether you already have a skill for this specific thing
    - If you do not, have the skill, make a new SKILL for yourself regarding that information
    - Continue what you were doing

- If you are using a skill to do something on the code base and you realise it is out of date, do the following:
    - Stop what you are doing
    - Update the skill content with up-to-date information
    - Continue what you were doing

- Always use Context7 when you need code generation, setup/configuration steps, or library/API documentation.

- Initialise Serena and figure out what it can do

## Token Optimization (IMPORTANT)

These patterns save significant tokens. Follow them strictly:

1. **Use the Explore agent for open-ended code discovery:**
   - When: "Where is X handled?", "How does Y work?", "Find all places that do Z"
   - Use: `Task(subagent_type="Explore", prompt="Find where...")`
   - Why: Search-and-read cycle stays in separate context, only answer returns

2. **Use line-limited file reads:**
   - When: You know approximately where content is (e.g., after a Grep)
   - Use: `Read(file_path, offset=LINE-10, limit=50)` instead of reading entire file
   - First use `Grep(pattern, output_mode="content", -n=true)` to find line numbers

3. **Use Serena symbolic tools for code symbols:**
   - When: Finding classes, functions, methods
   - Use: `mcp__serena__find_symbol(name_path, include_body=true)`
   - Why: Returns just the symbol, not the whole file

4. **Check Serena memories before exploring:**
   - Run `mcp__serena__list_memories` at session start
   - Read relevant memories like `token_optimization_patterns`, `project_overview`

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
lefthook run pre-commit --all-files
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
