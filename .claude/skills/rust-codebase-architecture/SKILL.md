---
name: rust-codebase-architecture
description: Rust codebase architecture for bee task manager. Use when working on Rust crates (bee-core, bee-actions, bee-cli, bee-api), understanding the filter system, storage layer, actions, or error handling patterns.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__serena__*
---

# Bee Rust Codebase Architecture

This skill documents the architecture, patterns, and conventions for the Rust codebase.

## Crate Dependency Graph

```
bee-cli          bee-api
    \              /
     \            /
      bee-actions
            |
       bee-core
            |
        migration (SeaORM)
```

| Crate | Purpose | Layer |
|-------|---------|-------|
| `bee-core` | Domain model, filters, storage | Foundation |
| `bee-actions` | Action handlers, business logic | Application |
| `bee-cli` | CLI frontend | Presentation |
| `bee-api` | REST API (Axum) | Presentation |
| `migration` | Database migrations | Persistence |

## Data Flow

```
User Input (CLI args or HTTP request)
    ↓
Parser.parse() → ParsedCommand
    ↓
Store.load_tasks(filter, props) → TaskData
    ↓
ActionRegistry.get_action() → Box<dyn TaskAction>
    ↓
action.do_action(printer) → mutates tasks
    ↓
Store.write_tasks(tasks) → persist
    ↓
Store.log_undo(undos) → undo history
```

## Key Modules

### bee-core

| Module | Purpose | Key Types |
|--------|---------|-----------|
| `task/` | Domain model | `Task`, `TaskStatus`, `TaskProperties`, `ActionUndo` |
| `filters/` | Composable filtering | `Filter` trait, `AndFilter`, `OrFilter`, 14 filter types |
| `storage/` | Storage abstraction | `Store`, `AsyncStore` traits |
| `storage/db/` | SQLite implementation | `DbStore`, SeaORM integration |
| `config.rs` | Configuration | `ReportConfig`, external links |
| `lib.rs` | Error handling | `CoreError`, `UserFacingError`, `Printer` trait |

### bee-actions

| Module | Purpose |
|--------|---------|
| `action_type.rs` | Action registry & dispatch |
| `action_*.rs` | 15 action implementations |
| `command_parser.rs` | CLI argument parsing |
| `lib.rs` | `TaskAction` trait, `BaseTaskAction` |

### bee-cli / bee-api

| Module | Purpose |
|--------|---------|
| `bee.rs` / `main.rs` | Entry points |
| `cli.rs` / `api.rs` | Output/routing |
| `error_type.rs` | Layer-specific errors |

## Core Domain Model

```rust
pub struct Task {
    pub uuid: Uuid,
    pub id: Option<i32>,           // Sequential display ID
    pub title: String,
    pub description: String,
    pub status: TaskStatus,        // Pending|Active|Completed|Deleted|Blocked
    pub project: Option<Project>,
    pub tags: HashSet<String>,
    pub annotations: Vec<TaskAnnotation>,
    pub depends_on: HashSet<DependsOnIdentifier>,
    pub blocks: HashSet<Uuid>,
    pub due: Option<DateTime<Local>>,
    // ...
}
```

## Quick Reference

### Filter Composition

```rust
use filters::{and, or, from};

// AND: all conditions must match
let filter = and(vec![
    from(&["status:pending"]),
    from(&["project:backend"]),
]);

// OR: any condition matches
let filter = or(vec![
    from(&["tag:urgent"]),
    from(&["due:today"]),
]);
```

### Creating Actions

```rust
impl_taskaction_from_base!(MyAction);

impl BaseTaskAction for MyAction {
    fn action_type(&self) -> ActionType { ActionType::My }

    fn do_base_action(&self, printer: &dyn Printer) -> ActionResult {
        // Implementation
    }
}
```

### Error Handling

```rust
// In bee-core
CoreError::NotFound { message: "Task not found".into() }

// Implements UserFacingError
fn user_message(&self) -> String { "Task not found" }
fn developer_message(&self) -> String { "Task UUID: ..." }
fn code(&self) -> ErrorCode { ErrorCode::NotFound }
```

### Async Storage

```rust
let store = DbStore::new(&database_url).await?;
let task_data = store.load_tasks(&filter, &props).await?;
store.write_tasks(&modified_tasks).await?;
```

## Sub-Documents Index

Read these when working on specific areas:

| Document | Read When |
|----------|-----------|
| [FILTER-SYSTEM.md](FILTER-SYSTEM.md) | Working with filters, adding filter types |
| [STORAGE-LAYER.md](STORAGE-LAYER.md) | Database operations, migrations, SeaORM |
| [ACTIONS.md](ACTIONS.md) | Creating or modifying actions |
| [ERROR-HANDLING.md](ERROR-HANDLING.md) | Error patterns, UserFacingError trait |
| [ASYNC-PATTERNS.md](ASYNC-PATTERNS.md) | Tokio, async storage, concurrency |

## Commands

```bash
# Build
cargo build

# Test
cargo test

# Lint
cargo clippy --all-targets --all-features

# Format
cargo fmt

# Run CLI
cargo run -- list
cargo run -- add "New task"

# Run API
cargo run -p bee-api
```

## Guardrails

### Always Do
- Run `cargo fmt` before completing
- Run `cargo clippy` and fix warnings
- Add tests for new functionality
- Use `Result` and `?` for error handling
- Follow existing patterns in the crate

### Ask First
- Adding new crate dependencies
- Changing public API signatures
- Modifying database schema
- Changing error types

### Never Do
- Use `unwrap()`/`expect()` in production code (tests OK)
- Block the Tokio runtime with sync I/O
- Skip the clippy/fmt step
- Commit with failing tests
