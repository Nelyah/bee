# Completed Tickets

Tickets moved here after implementation and review.

---

## TICKET-019: Multi-Select Tasks with Space
**Completed:** 2026-01-05

### Summary
Allow selecting multiple tasks from task list by pressing Space, applying actions only to selected tasks.

### Resolution

#### State Management
- Added `selectedTaskUUIDs: Set<String>` to `LauncherViewModel.swift`
- Added computed properties: `multiSelectCount`, `hasMultiSelection`
- Created `LauncherViewModel+MultiSelect.swift` with toggle/clear/check methods

#### Keyboard Handling
- Added `toggleMultiSelect` case to `NormalModeAction` enum
- Space key triggers `.toggleMultiSelect` (context-aware: collapse on headers, multi-select on tasks)
- `InteractionCoordinator` routes based on whether cursor is on header or task
- Toggle also moves cursor down for rapid selection
- Escape clears multi-selection (before other escape behaviors)

#### Visual Styling
- Added mauve-tinted surface colors to `ThemeManager`: `surfaceMultiSelected`, `surfaceMultiSelectedHover`, `surfaceMultiSelectedFocused`
- `TaskRow` shows mauve accent bar (3px) + mauve background tint for multi-selected tasks
- Blue focus bar (5px) still shown for cursor position

#### Selection Count Display
- Updated `BottomHintModelBuilder` to show "N selected" in left hints when multi-selection active

#### Action Filter Override
- `LauncherActionService.buildMultiSelectFilter()` creates OR filter from UUIDs
- Multi-select filter only applied when submitting (not when previewing while typing)
- Multi-selection cleared after successful non-list action

#### Bug Fixes
- Fixed: Multi-selection was clearing when typing in input box
- Fixed: Preview mode was filtering task list to selected tasks only

#### Tests Added
- `testMultiSelectPersistsDuringTyping` - regression test for typing bug
- `testMultiSelectClearsOnEscape` - escape clears selection
- `testToggleMultiSelectAtCursor` - toggle behavior
- `testToggleMultiSelectMovesCursorDown` - cursor advances after toggle
- `testToggleMultiSelectOnHeaderReturnsFalse` - no-op on group headers
- Updated `KeyHandlingDeciderTests` for new space key behavior

---

## TICKET-017: Global Dropdown Menu Trigger (Cmd+P)
**Completed:** 2026-01-04

### Summary
Add global Cmd+P binding to trigger contextual dropdown menus, plus colored status badge in task detail.

### Resolution

#### Cmd+P Global Shortcut
- Added `.commands` keyboard shortcut in `LauncherApp.swift`
- Created `handleContextualMenu()` in ViewModel that dispatches based on mode:
  - List mode → triggers report menu
  - Detail mode → triggers task state menu
- Created `MenuTriggerProvider` class for bridging SwiftUI ViewModel to AppKit NSMenu

#### Task State Menu (Clickable Status Badge)
- Created `TaskStateMenuButton` component (NSMenu + NSViewRepresentable)
- Colored badge based on task status using `statusColor()`
- Menu options: Completed, Active, Pending, Deleted
- All options are status changes (not destructive) - detail view stays open

#### Tests Added
- `CommandPTriggerTests` (9 tests): Cmd+P dispatch, multiple triggers, mode switching
- `TaskStateChangeTests` (6 tests): State change behavior, detail view persistence

---

## TICKET-018: Fix Task ID Filter Chip Float Display
**Completed:** 2026-01-02

### Summary
Filter chip for task ID shows a float with decimals (e.g., "1.0") but ID is an integer.

### Resolution
Fixed in `CriteriaChipBuilder.swift` - changed to check `numberValue` before `stringValue` and format as Int.

---

## TICKET-002: Hint Bar - Remove Enter Keybind During Edit
**Completed:** 2026-01-02

### Summary
When in edit mode (task name or annotation editing), remove the "Enter" hint from the hint bar since Enter now submits the edit.

### Resolution
Added `isEditing` parameter to `InteractionContext.detail` case. InteractionContextCoordinator now filters hints based on editing state.

---

## TICKET-003: Hint Bar - Show Cmd+Enter Saves Changes
**Completed:** 2026-01-02

### Summary
When in edit mode, show "⌘↩ Save" hint in the hint bar.

### Resolution
Implemented together with TICKET-002 - editing hints now show save/cancel instead of normal navigation hints.

---

## TICKET-004: Escape Cancels Edit with Hint Bar Update
**Completed:** 2026-01-02

### Summary
Escape key should cancel the current edit operation, and hint bar should show "Esc Cancel" during edit mode.

### Resolution
Implemented together with TICKET-002/003 - escape handling and hint bar updates bundled.

---

## TICKET-008: Collapse History Pane by Default
**Completed:** 2026-01-02

### Summary
The history section in TaskDetailView should be collapsed by default and expandable on demand.

### Resolution
Added `@State private var isHistoryExpanded: Bool = false` with chevron toggle button. Styled to match DetailSection pattern (uppercased title, same fonts/colors).

---

## TICKET-011: UUID Hover Highlight
**Completed:** 2026-01-02

### Summary
UUID in task detail should become highlighted on hover to indicate it's clickable anywhere.

### Resolution
Updated `CopyableDetailRow` to show underline and copy icon on hover. Added `CopyableDetailRowButtonStyle` for hover+focus states.

---

## BUG-001: Annotation Editing Shows Wrong Content
**Completed:** 2026-01-02

### Summary
Clicking on the 2nd annotation to edit shows the 1st annotation's content instead.

### Root Cause
View displayed annotations sorted by time (descending) but passed sorted array index to ViewModel, which accessed unsorted `detail.annotations[index]`.

### Resolution
Changed from index-based to ID-based annotation identification:
- `editingAnnotationIndex: Int?` → `editingAnnotationId: String?`
- `startEditingAnnotation(at:)` → `startEditingAnnotation(withId:)`

---

## BUG-002: Detail Mode Keybinds Active During Annotation Edit
**Completed:** 2026-01-02

### Summary
Pressing 'a' while editing an annotation would trigger "add annotation" instead of typing the letter.

### Resolution
Added `viewModel.editingAnnotationId == nil` and `!viewModel.isEditingTaskName` guards to detail mode key monitor.

---

## TICKET-001: Task Name Keyboard Navigation in Detail View
**Completed:** 2026-01-03

### Summary
Enable keyboard navigation to select and edit the task name in TaskDetailView using hjkl navigation, with Enter to start editing.

### Resolution
- Extended `DetailFocusableItem` enum to include `.taskName`, `.project`, `.tag`, `.addTagButton` cases
- Added hjkl navigation logic in `KeyHandlingDecider.detailModeAction()`
- Focus ring shows on all focusable items via `DetailFocusRing` modifier
- Enter on focused task name calls `startEditingTaskName()`
- Hint bar shows navigation and action hints

---

## TICKET-013: Inline Project Editing in Task Detail
**Completed:** 2026-01-03

### Summary
Allow selecting and modifying the project in task detail with both mouse and keyboard, with autocomplete.

### Resolution
- Created `EditableProjectRow` component with display/edit modes
- Reused `CompletionField` for fuzzy autocomplete
- Project row is focusable via hjkl navigation
- Enter to start editing, Escape to cancel
- Autocomplete dropdown with fuzzy matching
- Changes persist via API

---

## TICKET-014: Inline Tags Editing in Task Detail
**Completed:** 2026-01-03

### Summary
Allow selecting and modifying tags in task detail with both mouse and keyboard, with autocomplete.

### Resolution
- Created `EditableTagsRow` component with tag chips and add button
- Created `TagChip` component with remove button
- h/l navigation between tags when focused on a tag
- "+" add button is keyboard-focusable
- "t" keybinding to start adding a tag from anywhere in detail view
- Hint bar shows "t Add tag" hint
- Freeform entry mode allows creating new tags
- CompletionField stays open with empty state when no matches
- Tags rebuild in navigation list after add/remove

---

## TICKET-006: Command Palette Task State Actions
**Completed:** 2026-01-04

### Summary
Add command palette options to change task state: delete, completed, active, pending.

### Resolution
- Created `TaskStateSectionContributor` that shows "Mark task as..." section when a task is selected
- Four actions: Completed, Active, Pending, Deleted
- Created `LauncherViewModel+TaskState.swift` with `TaskStateAction` enum and handlers
- Local state updates after API calls (no full refresh needed)
- Toast notifications confirm actions
- No confirmation dialog for delete (undo support planned for future)

---

## TICKET-023: Clickable Hint Bar Items
**Completed:** 2026-01-04

### Summary
Hints shown in the hint bar should be clickable to trigger their associated action.

### Resolution
- Created `Keybinding.swift` with `Keybinding` struct and `KeybindingRegistry` as single source of truth
- Auto-generated display strings (e.g., "⌘K", "Enter", "Tab") from keyCode + modifiers
- Added `HintAction` enum for type-safe click handling
- Updated `BottomHint` model with keybinding initializer for auto-derived display keys
- Made `HintChip` clickable with pointing hand cursor and hover background effect
- Created `LauncherViewModel+HintActions.swift` to route actions to existing methods
- Non-actionable hints (e.g., "hjkl Navigate") remain non-clickable

---

## TICKET-005: Due Date in Task Detail
**Completed:** 2026-01-04

### Summary
Add ability to view and edit due date in task detail with both keyboard and mouse support, including a calendar picker with time selection and quick action buttons.

### Resolution
- Created `QuickDueDateAction.swift` enum with date calculation logic for Today, Tomorrow, Next \<weekday\>, Next Week (Monday), +1 Week
- Created `EditableDueDateRow.swift` component following the two-state display/edit pattern
- Extended `DetailFocusableItem` with `.dueDate(String?)` case for keyboard navigation
- Added state properties in `LauncherViewModel.swift` for due date editing
- Added editing methods in `LauncherViewModel+TaskDetail.swift` (start/cancel/submit/clear/applyQuickAction)
- Native SwiftUI DatePicker with `.graphical` style and time selection
- Popover UI with quick action buttons, DatePicker, and Clear/Cancel/Save controls
- Uses existing `runAction` API with "modify" action - no new backend endpoints needed
- 14 unit tests for date calculations in `QuickDueDateActionTests.swift`

---

## TICKET-007: Task Linking via Command Palette
**Completed:** 2026-01-04

### Summary
Add ability to link tasks together through the command palette, with task selection UI, link type selection, and enhanced linked tasks display.

### Resolution

#### Backend (Rust)
- Added 6 link types to `LinkType` enum: blocking, dependsOn, parentOf, childOf, relatedTo, duplicates
- Added `link:` syntax for creating task links via CLI (e.g., `link:blocking:uuid`)
- Added migration for `link_type` column in task_links table
- Updated task detail API to return links with type information

#### macOS Launcher
- Created `TaskLinkSectionContributor` for command palette integration
- Created `LinkedTasksSection` component with status badges + task titles (not just UUIDs)
- Created `DetailSection` reusable component for collapsible sections
- Added `ActionHandler.buildLinkTypeMenu()` and `buildTaskSelectorMenu()` for nested menu flow
- Extended `DetailFocusableItem` with `.linkedTask(TaskLinkDto)` for keyboard navigation
- Added `navigateToTask(uuid:)` for clicking/pressing Enter on linked tasks
- Added `Cmd+L` global shortcut to open link palette directly
- Added "⌘L Link task" to hint bar in detail mode
- Stored `paletteActionHandler` on ViewModel to fix closure lifecycle bug

#### Tests
- Added `ActionHandlerLinkTests` (12 tests for menu building)
- Added `TaskLinkSectionContributorTests`
- Added `LinkedTasksSectionUITests` (17 tests)
- Added `DetailSectionUITests`
- Updated snapshots for new hint bar and status badges

---

## TICKET-012: Fuzzy Match Text Highlighting
**Completed:** 2026-01-04

### Summary
In command palette, highlight the matched characters in fuzzy search results with bold and colored text.

### Resolution

#### Architecture
- Replaced `CommandPaletteFuzzyScorer` (score-only) with `FuzzyMatcher` (score + indices) to reuse the same algorithm as `CompletionField`
- Created `FuzzyMatchedPaletteItem` wrapper to hold items with title/subtitle match info
- Extended `CommandPaletteSection` with `sectionTitleMatch` for highlighting section headers

#### Combined Match Handling
- When query spans both section title and item title (e.g., "groua" matching "Group by" + "Due Date"), extracts indices from combined match and splits them:
  - Indices < sectionTitle.count → section highlighting
  - Indices > sectionTitle.count → item highlighting

#### View Layer
- Updated `CommandPaletteView` to render with `FuzzyMatcher.highlightedText()`
- Added `sectionHeader(title:match:)` for highlighted section headers
- Title and subtitle highlighting with blue color for matched characters

#### Files Modified
- `CommandPaletteModels.swift` - Added `FuzzyMatchedPaletteItem`, updated `CommandPaletteSection`
- `DataSource.swift` - Switched to `FuzzyMatcher`, added combined match index extraction
- `CommandPaletteCoordinator.swift` - Added `selectableMatchedItems` computed property
- `CommandPaletteView.swift` - Render with highlighting
- Deleted `FuzzyScorer.swift` (replaced by `FuzzyMatcher`)

#### Tests Added
- `testCombinedMatchHighlightsBothSectionAndItem` - Verifies combined match highlighting
- `testDirectMatchTakesPrecedenceOverCombinedMatch` - Direct match priority
- `testNoHighlightingForUnmatchedParts` - Section not highlighted when only item matches

---

## TICKET-010: macOS Mail Integration
**Completed:** 2026-01-05

### Summary
Allow linking emails to tasks by dragging from Apple Mail into the task.

### Resolution

#### Backend (Rust)
- Created `EmailLink` struct with id, task_uuid, message_id, subject, sender, sent_date, mail_url
- Added migration for `email_links` table
- API endpoints: POST create, GET list, DELETE remove
- Returns `mail_url` formatted as `message://<encoded-message-id>` for Mail.app

#### macOS Launcher
- Created `EmailLinksSection` and `EmailLinkRow` components
- Implemented drag-and-drop from Apple Mail using file promises (`NSFilePromiseReceiver`)
- Created `FilePromiseDropView.swift` with AppKit NSView for reliable file promise handling
- Parses `.eml` files dropped from Mail to extract message-id, subject, sender
- Created `EmailDropHandler.swift` for parsing email metadata
- Click to open email in Mail.app via `message://` URL scheme
- Created `ReliableHover.swift` using AppKit `NSTrackingArea` for hover effects (workaround for Apple bug FB11988707)

#### Files Created
- `Sources/LauncherApp/Views/Components/EmailLinksSection.swift`
- `Sources/LauncherApp/Utilities/FilePromiseDropView.swift`
- `Sources/LauncherApp/Utilities/EmailDropHandler.swift`
- `Sources/LauncherApp/Utilities/ReliableHover.swift`

---

## TICKET-009: File Attachments for Tasks
**Completed:** 2026-01-04

### Summary
Allow attaching files of any standard MIME type to tasks.

### Resolution

#### Backend (Rust)
- Created `Attachment` struct with id, task_uuid, filename, mime_type, size_bytes, storage_path, created_at
- Added migration for `attachments` table
- File storage in local filesystem with configurable path
- API endpoints: POST upload, GET list, GET download, DELETE remove

#### macOS Launcher
- Created `AttachmentsSection` component with keyboard navigation
- Created `AttachmentRow` with MIME type icons, filename, size display
- Added file picker via `NSOpenPanel`
- Added drag-and-drop support via `.dropDestination`
- Added Quick Look preview with `QuickLookCoordinator` implementing `QLPreviewPanelDataSource`
- Added inline delete confirmation with y/n keys
- Added `clearDetailFocus()` for click-outside-to-deselect
- Attachments keyboard navigable via j/k after tags/due date

#### Tests
- Added `AttachmentFocusTests` (10 tests)
- Added `QuickLookCoordinatorTests` (4 tests)
- Added attachment row snapshot tests

---

## TICKET-015: Project Overview View
**Completed:** 2026-01-05

### Summary
Add a new view listing all projects with statistics, burndown charts, and nested hierarchy display.

### Resolution

#### Backend (Rust)
- Added DTOs: `ProjectStatsDto`, `ProjectNodeDto`, `ProjectsResponse`, `BurndownDataPoint`, `ProjectBurndownResponse`
- Added SQL queries in `task_read.rs` for project stats breakdown and burndown data
- Added `GET /v1/projects` endpoint returning hierarchical project tree with aggregated stats
- Added `GET /v1/projects/{name}/burndown` endpoint for burndown chart data
- Iterative bottom-up hierarchy building algorithm (fixed stack overflow from recursive approach)

#### macOS Launcher
- Created `ProjectStatsModels.swift` with Swift models matching API DTOs
- Added `LauncherMode.projectOverview` case
- Created `LauncherViewModel+ProjectOverview.swift` with state management:
  - `ProjectOverviewState` struct with loading, projects, expanded, burndown states
  - Navigation methods: `navigateToProjectOverview()`, `exitProjectOverview()`
  - Data loading: `loadProjectOverview()`, `loadBurndown(for:)`
  - Tree interaction: `toggleProjectExpansion()`, `selectProjectForFilter()`
- Created `ProjectOverviewView.swift` with header, loading/error/empty states, project list
- Created `ProjectStatsRow.swift` with expand chevron, name, stats pills, burndown button
- Created `BurndownChartView.swift` using Swift Charts (LineMark + AreaMark)
- Created `ProjectOverviewSectionContributor.swift` for command palette "Go to Projects" action
- Updated `ContentView.swift` with `.projectOverview` mode routing
- Updated `InteractionContextCoordinator.swift` with `.projectOverview` handling

#### Tests
- `ProjectOverviewSectionContributorTests` (9 tests): contributor behavior, query filtering
- `ProjectStatsModelsTests` (13 tests): model decoding, hierarchy, equatable
- `ProjectOverviewSnapshotTests` (9 tests): visual snapshots for rows, chart, header
- `test_build_project_hierarchy_nested`: hierarchy building unit test
- `test_openapi_schema_generates_without_overflow`: OpenAPI schema generation
- `test_projects_endpoint`: integration test for endpoint
