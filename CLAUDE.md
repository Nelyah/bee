# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bee is a task management CLI application written in Rust, inspired by Taskwarrior. It's currently under active development as a pet project and supports task creation, modification, filtering, dependencies, urgency calculation, and undo functionality.

## Build and Test Commands

### Basic Commands
```bash
# Build the project
cargo build

# Run the application
cargo run -- help

# Run with specific command (e.g., list tasks)
cargo run -- list

# Build and install locally
cargo install --path crates/bee-cli
```

### Testing
```bash
# Run all tests
cargo test

# Run tests for a specific crate
cargo test -p bee-core
cargo test -p bee-actions
cargo test -p bee-cli

# Run a specific test
cargo test test_name

# Run tests with output
cargo test -- --nocapture

# Generate code coverage report (requires tarpaulin)
./code_coverage.sh
# or
cargo tarpaulin --out Html
```

### Development
```bash
# Check code without building
cargo check

# Run clippy for lints
cargo clippy

# Format code
cargo fmt

# Run a specific test file's tests
cargo test --test integration_test_name
```

## Architecture

### Crate Structure

The project is organized as a Cargo workspace with four crates:

1. **bee-core**: Core domain logic and data structures
   - Task models and TaskData container
   - Filter system for querying tasks
   - Storage abstractions (Store and AsyncStore traits)
   - Config management (reports, columns, urgency coefficients)
   - Parser and lexer for task properties and filters

2. **bee-actions**: Action implementations (commands)
   - Each action is a separate module (e.g., `action_add.rs`, `action_done.rs`)
   - TaskAction trait defines action behavior
   - ActionRegistry for command registration and dispatch
   - All actions support undo via ActionUndo system

3. **bee-cli**: CLI interface and presentation layer
   - Binary entry point in `src/bee.rs`
   - SimpleTaskTextPrinter implements the Printer trait
   - Table rendering for task lists
   - CLI-specific configuration

4. **migration**: SeaORM database migrations
   - Database schema definitions

### Key Architectural Patterns

#### Task Flow
1. CLI parses arguments via `command_parser::Parser`
2. Filters are constructed from arguments and report config
3. Tasks are loaded from storage (SQLite via DbStore)
4. Action is created and executed with filtered tasks
5. Modified tasks are written back to storage
6. Undo information is logged

#### Filter System
Filters use a compositional tree structure:
- Base filters: StringFilter, StatusFilter, TagFilter, ProjectFilter, DateCreatedFilter, etc.
- Logical filters: AndFilter, OrFilter, XorFilter
- Filters can be nested arbitrarily deep
- The `Filter` trait uses `typetag::serde` for polymorphic serialization
- Use helper functions: `filters::and()`, `filters::or()`, `filters::from()`

#### Storage Abstraction
Storage is handled via the async DbStore (SQLite). The database schema includes:
- tasks (main task data)
- tags, projects, annotations (related data)
- links (task dependencies and relationships)
- history (task change history)
- undo_actions (for undo functionality)

#### Undo System
- Every action that modifies tasks logs undo information
- ActionUndo contains ActionUndoType (Add or Modify) and task snapshots
- Undos are loaded at startup and applied to task data
- The undo action reverses the last operation

#### Task Properties vs Task
- **TaskProperties**: User-facing structure for setting task fields (parsed from CLI)
- **Task**: Internal task representation with full data
- TaskProperties are applied to Tasks via `task.apply_properties(props)`

#### Urgency Calculation
Urgency is calculated from coefficients defined in config:
- Each coefficient has a field (e.g., "status"), optional value, and coefficient weight
- Tasks accumulate urgency scores based on matching criteria
- Used for sorting and prioritization

### Important Files

- `crates/bee-core/src/task.rs`: Core Task struct, TaskData container, TaskProperties
- `crates/bee-core/src/filters.rs`: Filter trait and composition functions
- `crates/bee-core/src/storage/mod.rs`: Storage trait definitions
- `crates/bee-core/src/storage/db/inserts_update.rs`: Database operations (WIP)
- `crates/bee-actions/src/action_type.rs`: Action enumeration and factory
- `crates/bee-actions/src/lib.rs`: TaskAction trait and BaseTaskAction
- `crates/bee-cli/src/bee.rs`: Main entry point and orchestration

### Task Links/Dependencies

Tasks can have links between them (e.g., "depends on", "blocks"):
- Stored in the `links` table with from_task_id, to_task_id, and type
- DependsOnFilter allows filtering by dependency relationships
- When a task's blocking status changes, related tasks are updated
- Link updates are tracked as "extra tasks" in undo logs

### Testing Patterns

Tests are co-located with source files using the pattern:
```rust
#[path = "module_test.rs"]
#[cfg(test)]
mod module_test;
```

Common test helpers:
- `all_asserts` crate provides `assert_true`, `assert_false`, etc.
- Most tests create temporary task data and apply actions
- Filter tests validate task matching logic

### Configuration

Configuration is loaded from TOML files (location customizable via ENV):
- **Reports**: Named filter + column configurations
- **Columns**: Which fields to display in list view
- **Coefficients**: Urgency calculation weights

Default report shows: id, date_created, summary, tags, urgency

### SeaORM and Database

The project uses:
- SeaORM 1.1.0 with SQLite backend
- Async runtime: Tokio
- Database connection managed in `storage/db/inserts_update.rs`
- Entity models auto-generated in `storage/db/tables/`

When modifying the schema:
1. Update migration in `crates/migration/src/m20250329_*.rs`
2. Run migrations
3. Regenerate entities if needed (see TODO comment in `storage/db/mod.rs`)

## Development Notes

### Adding a New Action

1. Create `crates/bee-actions/src/action_<name>.rs`
2. Implement TaskAction trait (use `impl_taskaction_from_base!` macro)
3. Add action to ActionType enum in `action_type.rs`
4. Register in `ActionType::as_dict()` with aliases and settings
5. Add module declaration in `lib.rs`

### Adding a New Filter

1. Create filter struct in `crates/bee-core/src/filters/filters_impl.rs`
2. Implement Filter trait with `#[typetag::serde]`
3. Add to FilterKind enum
4. Add parsing logic in `filters/parser.rs`
5. Export via `filters.rs` if needed

### Working with Tests

Tests are named with `_test.rs` suffix and placed alongside source files. To run tests for a specific module while developing:
```bash
cargo test -p bee-core task_test
```

Always use context7 when I need code generation, setup or configuration steps, or
library/API documentation. This means you should automatically use the Context7 MCP
tools to resolve library id and get library docs without me having to explicitly ask.
