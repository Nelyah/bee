# Skill Writing Examples

Each example below is prefaced with when to reference it. Only read the sections relevant to your current task.

---

## 1. Decision Tree Scenarios

**Read this when:** Deciding whether to put knowledge in a Skill, CLAUDE.md, or Serena Memory.

### Scenario A: Build Commands
> "I need to document `cargo build --release` and `swift test` commands"

**Answer: CLAUDE.md**
- Build commands are needed for nearly every interaction
- They should always be in context
- Small, universal footprint

### Scenario B: LauncherViewModel Patterns
> "I want to document how LauncherViewModel handles state, its dependencies, and the patterns used"

**Answer: Skill**
- Only relevant when working on LauncherViewModel
- Too large for CLAUDE.md if comprehensive
- Natural trigger: "working on LauncherViewModel", "launcher state management"

### Scenario C: Creating Menu Entries
> "I repeatedly explain how to add new menu entries to the command palette"

**Answer: Skill (Task)**
- Repeated task with specific steps
- Clear trigger: "add menu entry", "new command palette item"
- Steps are consistent each time

### Scenario D: Database Schema Discovery
> "I just discovered that the tasks table has a `parent_id` field for subtasks"

**Answer: Serena Memory**
- Cross-session learning
- Specific discovery worth persisting
- Not a task or large reference, just a fact

### Scenario E: Universal Code Style
> "All code should use 4-space indentation and follow Rust's naming conventions"

**Answer: CLAUDE.md**
- Applies to ALL code interactions
- Universal convention, not domain-specific
- Small enough to always have in context

---

## 2. Architecture Reference Skill

**Read this when:** Creating a skill that documents architecture/patterns for a specific area of the codebase.

### Example: ViewModel Patterns Skill

```yaml
---
name: launcher-viewmodel-patterns
description: Documents LauncherViewModel architecture, state management, and dependencies. Use when working on LauncherViewModel, launcher state, or view model logic in the macOS launcher.
allowed-tools: Read, Glob, Grep
---

# LauncherViewModel Architecture

## Overview

LauncherViewModel is the central state coordinator for the macOS launcher. It follows MVVM with unidirectional data flow.

## Key Files

| File | Purpose |
|------|---------|
| `LauncherViewModel.swift` | Core state and task management |
| `LauncherViewModel+Grouping.swift` | Task grouping logic |
| `LauncherViewModel+Reports.swift` | Report generation |
| `LauncherViewModel+TaskDetail.swift` | Task detail handling |

## State Management Pattern

1. **Published properties** drive SwiftUI updates
2. **Async methods** handle data loading
3. **Combine** used for reactive bindings
4. **No direct view manipulation** - views observe state

## Dependencies

- `TaskManager` - CRUD operations on tasks
- `SettingsService` - User preferences
- `ReportService` - Report generation

## Extension Pattern

Large ViewModels are split into extensions by domain:
- Core state → main file
- Grouping logic → `+Grouping.swift`
- Reports → `+Reports.swift`

Follow this pattern when adding significant new functionality.

## Guardrails

### Always Do
- Keep state mutations on main actor
- Use `@Published` for observable state
- Follow existing extension naming convention

### Ask First
- Adding new dependencies to ViewModel
- Changing state update patterns

### Never Do
- Direct view manipulation from ViewModel
- Blocking calls on main thread
```

---

## 3. Task Skill (Testing Focus)

**Read this when:** Creating a skill for testing-related tasks.

### Example: Writing UI Tests Skill

```yaml
---
name: swiftui-tests
description: Writes SwiftUI UI tests using ViewInspector for behavior testing and swift-snapshot-testing for visual regression. Use when asked to write UI tests, view tests, snapshot tests, or test SwiftUI views in the macos-launcher.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# SwiftUI UI Testing

## Frameworks

| Framework | Purpose | When to Use |
|-----------|---------|-------------|
| ViewInspector | Behavior testing | Button taps, state changes, content verification |
| swift-snapshot-testing | Visual regression | Layout, styling, appearance |

## ViewInspector Quick Reference

```swift
// Find and tap button
let button = try view.find(ViewType.Button.self)
try button.tap()

// Find text content
_ = try view.find(text: "Expected Text")

// Get actual view for assertions
let actualView = try view.actualView()
```

## Snapshot Testing Quick Reference

```swift
final class MyViewSnapshotTests: SnapshotTestCase {
    func testDefaultState() {
        let view = MyView(title: "Test")
        assertViewSnapshot(view, size: TestSizes.compact)
    }
}
```

## Workflow

1. Decide: behavior test (ViewInspector) or visual test (snapshot)
2. Create test file following naming convention (`*UITests.swift` or `*SnapshotTests.swift`)
3. Write test with appropriate assertions
4. Run with `swift test --filter "TestClassName"`
5. For snapshots: record reference images on first run

## Guardrails

### Always Do
- Use meaningful test method names (they become snapshot filenames)
- Commit snapshot references to git
- Test states, not implementation

### Never Do
- Skip recording step for new snapshot tests
- Leave `isRecording = true` in committed code
```

---

## 4. Task Skill (Workflow Focus)

**Read this when:** Creating a skill for process/workflow tasks.

### Example: Creating PRs Skill

```yaml
---
name: creating-prs
description: Creates well-structured GitHub pull requests with proper descriptions and review preparation. Use when asked to create a PR, submit changes for review, or prepare a pull request.
allowed-tools: Bash, Read, Grep
---

# Creating Pull Requests

## Workflow

1. **Verify clean state**
   ```bash
   git status
   git diff --staged
   ```

2. **Check commit history**
   ```bash
   git log main..HEAD --oneline
   ```

3. **Create PR**
   ```bash
   gh pr create --title "type(scope): description" --body "$(cat <<'EOF'
   ## Summary
   - Key change 1
   - Key change 2

   ## Test Plan
   - [ ] Manual testing completed
   - [ ] Unit tests pass
   - [ ] No regressions

   ## Notes for Reviewers
   [Anything reviewers should know]
   EOF
   )"
   ```

4. **Verify PR created**
   ```bash
   gh pr view --web
   ```

## Title Conventions

| Type | When |
|------|------|
| `feat(scope):` | New feature |
| `fix(scope):` | Bug fix |
| `refactor(scope):` | Code restructuring |
| `docs(scope):` | Documentation only |
| `chore(scope):` | Maintenance tasks |

## Guardrails

### Always Do
- Include test plan in description
- Reference related issues
- Summarize changes for reviewers

### Ask First
- Creating draft vs ready PR
- Requesting specific reviewers

### Never Do
- Create PR with failing tests
- Skip the test plan section
```

---

## 5. Minimal Skill

**Read this when:** Creating a quick, focused utility skill.

### Example: Quick Commands Skill

```yaml
---
name: quick-db-commands
description: Common database commands for the bee project. Use when running migrations, resetting the database, or checking database state.
allowed-tools: Bash
---

# Database Commands

| Task | Command |
|------|---------|
| Run migrations | `sea-orm-cli migrate up` |
| Reset database | `rm -f ~/.local/share/bee/tasks.db && sea-orm-cli migrate up` |
| Check status | `sea-orm-cli migrate status` |
| Generate entity | `sea-orm-cli generate entity -o crates/bee-core/src/entity` |

## Notes
- Database location: `~/.local/share/bee/tasks.db`
- Migrations in: `crates/migration/src/`
```

---

## 6. Description Writing Examples

**Read this when:** Writing or improving skill descriptions.

### Good Descriptions

```yaml
# Specific, includes triggers, third person
description: Reviews Rust code for idiomatic patterns, error handling, and async correctness. Use when reviewing Rust PRs, asking for code review, or checking Rust best practices.

# Clear scope, multiple triggers
description: Manages Git workflow including commits, branches, and PR creation. Use for git operations, creating commits, branching, or preparing pull requests.

# Domain-specific with clear activation
description: Documents BigQuery table schemas and common query patterns for the analytics team. Use when working with BigQuery, writing analytics queries, or exploring data schemas.
```

### Bad Descriptions

```yaml
# Too vague
description: Helps with code

# Wrong person (should be third person)
description: I can help you write tests

# No triggers, unclear when to use
description: Testing stuff

# Missing the "when to use" part
description: Processes PDF files  # Better: "...Use when extracting text from PDFs or working with PDF documents."
```

---

## 7. Progressive Disclosure Structure

**Read this when:** Splitting content across multiple files.

### Example Structure

```
.claude/skills/api-patterns/
├── SKILL.md              # Overview, quick reference, links to details
├── ENDPOINTS.md          # Detailed endpoint documentation
├── AUTHENTICATION.md     # Auth patterns and examples
├── ERROR-HANDLING.md     # Error codes and handling
└── EXAMPLES.md           # Full request/response examples
```

### SKILL.md Content

```yaml
---
name: api-patterns
description: API conventions, authentication, and endpoint patterns for the REST API. Use when working on API endpoints, authentication, or HTTP handling.
---

# API Patterns

## Quick Reference

| Method | Path Pattern | Use |
|--------|--------------|-----|
| GET | `/resource` | List |
| GET | `/resource/:id` | Get one |
| POST | `/resource` | Create |
| PATCH | `/resource/:id` | Update |
| DELETE | `/resource/:id` | Delete |

## Authentication

All endpoints require Bearer token. See [AUTHENTICATION.md](AUTHENTICATION.md) for details.

## Detailed Documentation

- **[ENDPOINTS.md](ENDPOINTS.md)** - Complete endpoint specs (read when implementing new endpoints)
- **[AUTHENTICATION.md](AUTHENTICATION.md)** - Auth flow details (read when working on auth)
- **[ERROR-HANDLING.md](ERROR-HANDLING.md)** - Error patterns (read when handling errors)
- **[EXAMPLES.md](EXAMPLES.md)** - Request/response examples (read when unsure of format)
```

---

## 8. Three-Tier Boundaries

**Read this when:** Defining guardrails for a skill.

### Comprehensive Example

```markdown
## Guardrails

### Always Do
- Run `cargo fmt` before completing Rust changes
- Run `swift build` to verify Swift changes compile
- Follow existing patterns in the file being modified
- Add tests for new functionality
- Update related documentation

### Ask First
- Adding new external dependencies
- Changing public API signatures
- Modifying database schema
- Changing configuration file formats
- Deleting files (vs just modifying)
- Creating new top-level modules

### Never Do
- Commit with `--no-verify`
- Force push to main/master
- Commit secrets, credentials, or API keys
- Disable linter warnings without explicit permission
- Remove TODO comments unless the TODO is resolved
- Make breaking changes without migration path
```

### Minimal Example (for focused skills)

```markdown
## Guardrails

### Always Do
- Run tests after changes
- Follow existing code style

### Never Do
- Skip the test step
- Introduce breaking changes
```
