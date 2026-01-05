---
name: ui-ux-screenshots
description: Screenshot catalog and generation commands for macOS launcher UI review. Use when performing UI/UX reviews, generating screenshots for visual inspection, or needing to capture specific component states.
allowed-tools: Bash, Read, Glob
---

# UI/UX Screenshot Catalog

Reference for generating and locating screenshots of the macOS launcher for visual review.

## Quick Start

```bash
# Generate a specific screenshot
RECORD_SNAPSHOTS=1 swift test --filter "ScreenshotCatalog/<TEST_NAME>"

# Generate ALL screenshots
RECORD_SNAPSHOTS=1 swift test --filter "ScreenshotCatalog"
```

## Screenshot Location

All screenshots are saved to:
```
macos-launcher/Tests/LauncherAppTests/SnapshotTests/__Snapshots__/ScreenshotCatalog/
```

After generating, use the Read tool on the PNG file to view it.

---

## Screenshot Catalog

### Content View (Full App)

| Test Name | Description | Output File |
|-----------|-------------|-------------|
| `testContentView_empty` | Empty state, no tasks | `testContentView_empty.1.png` |
| `testContentView_listWithTasks` | Main list with sample tasks | `testContentView_listWithTasks.1.png` |
| `testContentView_listWithSearch` | Search/filter input active | `testContentView_listWithSearch.1.png` |
| `testContentView_detailMode` | Task detail panel open | `testContentView_detailMode.1.png` |
| `testContentView_commandPalette` | Command palette overlay | `testContentView_commandPalette.1.png` |
| `testContentView_withToast` | Toast notification visible | `testContentView_withToast.1.png` |

### Task List

| Test Name | Description | Output File |
|-----------|-------------|-------------|
| `testTaskList_empty` | Empty list state | `testTaskList_empty.1.png` |
| `testTaskList_singleTask` | Single task displayed | `testTaskList_singleTask.1.png` |
| `testTaskList_manyTasks` | Multiple tasks | `testTaskList_manyTasks.1.png` |
| `testTaskList_withSelectedTask` | Row selection highlight | `testTaskList_withSelectedTask.1.png` |

### Task Row States

| Test Name | Description | Output File |
|-----------|-------------|-------------|
| `testTaskRow_pending` | Pending status indicator | `testTaskRow_pending.1.png` |
| `testTaskRow_active` | Active/in-progress status | `testTaskRow_active.1.png` |
| `testTaskRow_completed` | Completed status | `testTaskRow_completed.1.png` |
| `testTaskRow_withTags` | Row with tag chips | `testTaskRow_withTags.1.png` |
| `testTaskRow_withDueDate` | Row showing due date | `testTaskRow_withDueDate.1.png` |
| `testTaskRow_selected` | Selected row highlight | `testTaskRow_selected.1.png` |
| `testTaskRow_expanded` | Expanded row with details | `testTaskRow_expanded.1.png` |

### Task Detail

| Test Name | Description | Output File |
|-----------|-------------|-------------|
| `testTaskDetail_basic` | Basic detail view | `testTaskDetail_basic.1.png` |
| `testTaskDetail_withAnnotations` | With annotations/history | `testTaskDetail_withAnnotations.1.png` |
| `testTaskDetail_withExternalLinks` | With GitLab links | `testTaskDetail_withExternalLinks.1.png` |
| `testTaskDetail_loading` | Loading state | `testTaskDetail_loading.1.png` |
| `testTaskDetail_projectEditing` | Project editing with autocomplete | `testTaskDetail_projectEditing.1.png` |

### Command Palette

| Test Name | Description | Output File |
|-----------|-------------|-------------|
| `testCommandPalette_default` | Default state | `testCommandPalette_default.1.png` |
| `testCommandPalette_withSearch` | With search query | `testCommandPalette_withSearch.1.png` |

### Components

| Test Name | Description | Output File |
|-----------|-------------|-------------|
| `testComponent_tokenInput_empty` | Empty search input | `testComponent_tokenInput_empty.1.png` |
| `testComponent_tokenInput_withTokens` | Syntax-highlighted input | `testComponent_tokenInput_withTokens.1.png` |
| `testComponent_criteriaStrip` | Filter/property chips | `testComponent_criteriaStrip.1.png` |
| `testComponent_completionMenu` | Autocomplete dropdown | `testComponent_completionMenu.1.png` |
| `testComponent_reportMenuButton` | Report selector button | `testComponent_reportMenuButton.1.png` |
| `testComponent_attachmentRow_default` | Attachment row default state | `testComponent_attachmentRow_default.1.png` |
| `testComponent_attachmentRow_focused` | Attachment row focused/hover state | `testComponent_attachmentRow_focused.1.png` |
| `testComponent_emailLinkRow_default` | Email link row default state | `testComponent_emailLinkRow_default.1.png` |

---

## Workflow for UI Review

1. **Identify what to review** - Pick screenshots relevant to your review scope
2. **Generate screenshots** - Run the test commands above
3. **Read the PNG files** - Use Read tool on the output files
4. **Analyze** - Apply your review methodology
5. **Document findings** - Note specific issues with file references

## Common Review Sets

### Full App Review
```bash
RECORD_SNAPSHOTS=1 swift test --filter "ScreenshotCatalog/testContentView"
```

### Task Row States (for status indicator review)
```bash
RECORD_SNAPSHOTS=1 swift test --filter "ScreenshotCatalog/testTaskRow"
```

### Component-Level Review
```bash
RECORD_SNAPSHOTS=1 swift test --filter "ScreenshotCatalog/testComponent"
```
