# macos-launcher

Minimal macOS SwiftUI launcher for bee.

## Prereqs
- macOS 14+
- Xcode 15+ (or Swift 5.9 toolchain)
- `beed` running locally (default: http://127.0.0.1:3000)

## Run (Xcode)
1. Open `macos-launcher/Package.swift` in Xcode.
2. Select the `macos-launcher` scheme and run on “My Mac”.

## Run (CLI)
```bash
cd macos-launcher
swift build
swift run macos-launcher
```

## Configure API URL
Set `BEE_API_BASE_URL` if your API is not on the default port:

```bash
BEE_API_BASE_URL="http://127.0.0.1:3000" swift run macos-launcher
```

## Configuration

The launcher fetches its configuration from the bee API at startup (`GET /v1/config`). Columns and default filters are configured in your `bee.toml` file.

### Report Configuration

```toml
[report.default]
columns = ["id", "date_created", "summary", "date_due", "tags", "urgency"]
column_names = ["ID", "Date", "Summary", "Due", "Tags", "Urgency"]
default = true
filters = ['status:pending or status:active']
```

| Field | Description |
|-------|-------------|
| `columns` | Field names to display (id, uuid, summary, status, project, tags, urgency, date_created, date_completed, date_due) |
| `column_names` | Display headers for each column |
| `default` | Whether this is the default report |
| `filters` | Default filter expressions applied to task list |

### Available Columns

| Column | Description |
|--------|-------------|
| `id` | Database ID |
| `uuid` | Task UUID (truncated to 8 chars) |
| `summary` | Task description |
| `status` | Task status (pending, active, completed, deleted) |
| `project` | Project name |
| `tags` | Comma-separated tags |
| `urgency` | Calculated urgency score |
| `date_created` | Creation date |
| `date_completed` | Completion date |
| `date_due` | Due date |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Enter` | Execute action |
| `Esc` | Close detail view / clear |
| `↑` / `Ctrl-P` | Select previous task |
| `↓` / `Ctrl-N` | Select next task |
| `Alt-F` | Move cursor forward one word |
| `Alt-B` | Move cursor backward one word |
| `Ctrl-W` | Delete previous word |

## Notes
- The launcher sends a request to `/v1/parse` on every keystroke, then calls `/v1/action` with the parsed action + filter.
- Columns and filters are dynamically loaded from the API configuration.
