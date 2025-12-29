# Bee project overview

## Purpose
Bee is a Rust CLI task management app (Taskwarrior-inspired). It supports task creation, modification, filtering, dependencies, urgency scoring, and undo. It is under active development.

## Tech stack
- Language: Rust (edition 2024 in workspace)
- Async runtime: Tokio
- DB: SQLite via SeaORM
- CLI: bee-cli crate
- Actions: bee-actions crate
- Core domain/storage/config: bee-core crate
- Migrations: migration crate (SeaORM migrations)

## Codebase structure
- `crates/bee-core`: domain models (Task, TaskData, TaskProperties), filters, parsers/lexer, storage abstraction (Store/AsyncStore), DB code under `storage/db/`.
- `crates/bee-actions`: command/action implementations; each action produces Undo data.
- `crates/bee-cli`: CLI entrypoint (`src/bee.rs`), formatting, config, table output.
- `crates/migration`: DB migrations and schema definitions.

## Key concepts
- TaskProperties is created only via parsing CLI input and applied to Task.
- TaskData holds loaded tasks and ID↔UUID mappings.
- Filters are composable (And/Or/Xor + base filters).
- Undo system logs action snapshots; undo reverts last action.

## Config
- TOML-based config (reports, columns, urgency coefficients). Default report includes id, date_created, summary, tags, urgency.
