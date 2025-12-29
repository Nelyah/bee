This is a rust application. It is a todo application (task maangement software).
It includes a Rust backend (core + API + CLI) and a macOS SwiftUI launcher app.

It consists of a couple of crates:
# bee-core

This is where the main objects are defined. This is also where the database is defined. 

## Important traits and structs:

### Printer

Should be implemented to define how we're going to show something.

### Task (lives in `task.rs`)

This is the base object representing a task. It contains the properties related to it.

### TaskProperties

This is an object that is used to register changes we want to apply. It is created by parsing
the command line from the user.
Its fields are intentionally private. The only way for other crates to instantiate it is by parsing input.
We can easily apply a TaskProperties to a task to change its fields.

### TaskData

This is an object that contains a set of tasks. Usually the set of tasks that are loaded. 
It also indexes them to be able to have mappings from id_to_uuid and so on.

## Database

The database used is defined under `db/`. We are using sqlite for now.
We are using SeaORM to interface with the actual DB.

# bee-actions

This is where I define actions. Actions are applied to individual tasks and modify them.
Actions usually take care of creating a "UndoAction". This undo action is useful if you want to
revert the change. 

# bee-cli

This is the CLI application. It relies on the rest to provide a CLI interface. It implements how things
will look in the terminal, will take care of writing the main function, retrieving tasks from the database, 
reading the configuration file.

# macos-launcher

This is the macOS SwiftUI launcher app. It provides a GUI over the API, with MVVM-style ViewModels.
It talks to the running API server over HTTP (see `ApiClient`), and surfaces errors from the API
to the UI (toasts). Mock data is available via `MockApiClient` for previews and local testing.

# Quick navigation

- Start here for backend behavior: `crates/bee-api/src/api.rs`
- Database connection + pragmas: `crates/bee-core/src/storage/db/connection.rs`
- Task model and properties: `crates/bee-core/src/task.rs`
- macOS entry point + window styling: `macos-launcher/Sources/LauncherApp/LauncherApp.swift`
- macOS navigation flow (list/detail switch, Escape handling): `macos-launcher/Sources/LauncherApp/Views/ContentView.swift`
- macOS data flow (inputs/actions/toasts): `macos-launcher/Sources/LauncherApp/ViewModels/LauncherViewModel.swift`

# Coding guidelines

New functions should have docstrings.
New functions should have unit tests.

Always use context7 when I need code generation, setup or configuration steps, or
library/API documentation. This means you should automatically use the Context7 MCP
tools to resolve library id and get library docs without me having to explicitly ask.
