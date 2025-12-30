# Repository Guidelines

## Project Structure & Module Organization
- `Sources/LauncherApp/`: SwiftUI app code.
- `Sources/LauncherApp/Views/` and `Sources/LauncherApp/Views/Components/`: UI and reusable view components.
- `Sources/LauncherApp/ViewModels/`: state and view model logic.
- `Sources/LauncherApp/Networking/`: API client and request models.
- `Sources/LauncherApp/Models/`: domain models and DTOs.
- `Sources/LauncherApp/Utilities/`: shared helpers.
- `Tests/LauncherAppTests/`: XCTest test target.

## Build, Test, and Development Commands
```bash
swift build
swift run macos-launcher
```
Builds and runs the Swift package from the CLI. For Xcode: open `Package.swift`, select the `macos-launcher` scheme, run on “My Mac”.

```bash
swift test
```
Runs XCTest for the launcher target.

## Coding Style & Naming Conventions
- Swift 5.9+ (Xcode 15+) and macOS 14+.
- Use standard SwiftUI and Swift API naming: `UpperCamelCase` for types, `lowerCamelCase` for variables/functions.
- Indentation: 4 spaces, no tabs.
- Keep view files focused; push logic into view models and utilities.

## Testing Guidelines
- Framework: XCTest in `Tests/LauncherAppTests/`.
- Prefer `*Tests` naming for test classes.
- Run tests with `swift test` (CLI) or the Test navigator in Xcode.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits (e.g., `feat(macos): …`, `fix(config): …`, `chore: …`).
- PRs should include a short summary, testing notes (what you ran), and screenshots for UI changes.

## Configuration & Architecture Notes
- The launcher loads config from the bee API at startup (`GET /v1/config`) and relies on `bee.toml` for report columns and default filters.
- API base URL is configurable via `BEE_API_BASE_URL`:
```bash
BEE_API_BASE_URL="http://127.0.0.1:3000" swift run macos-launcher
```
