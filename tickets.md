# Bee Feature Tickets

This document contains detailed tickets for features requested in `feature-list.txt`. Each ticket includes scope, complexity assessment, affected layers, and implementation notes.

---

## Table of Contents

1. [TICKET-005: Due Date in Task Detail](#ticket-005)
2. [TICKET-007: Task Linking via Command Palette](#ticket-007)
4. [TICKET-009: File Attachments for Tasks](#ticket-009)
5. [TICKET-010: macOS Mail Integration](#ticket-010)
6. [TICKET-012: Fuzzy Match Text Highlighting](#ticket-012)
7. [TICKET-015: Project Overview View](#ticket-015)
8. [TICKET-016: Important Links Section in Task Detail](#ticket-016)
9. [TICKET-017: Global Dropdown Menu Trigger (Cmd+P)](#ticket-017)
10. [TICKET-019: Multi-Select Tasks with Space](#ticket-019)
11. [TICKET-020: Visual Grouping for Report Filter Chips](#ticket-020)
12. [TICKET-021: Info Tooltips for Filters/Properties](#ticket-021)
13. [TICKET-022: Help Mode with Cmd+Shift+H](#ticket-022)
14. [TICKET-023: Clickable Hint Bar Items](#ticket-023)

See [DONE.md](DONE.md) for completed tickets.

---

<a name="ticket-005"></a>
## TICKET-005: Due Date in Task Detail

### Summary
Add ability to view and edit due date in task detail with both keyboard and mouse support, including a calendar picker with time selection.

### Priority
High

### Complexity
High ⚠️

### Affected Layers
- **Rust API**: `bee-api/src/api.rs` (endpoint for updating due date)
- **Rust Core**: Already has `date_due` field on Task
- **macOS**: `TaskDetailView.swift`, new `DateTimePickerView.swift` component, `ApiClientProtocol.swift`

### Current State
- `Task.date_due` exists in Rust model
- `ApiTaskDetail.dateDue` exists in Swift model
- No UI for editing due date currently

### Implementation Notes

#### Phase 1: Display Due Date
1. Add due date row in `metadataColumn` of TaskDetailView
2. Show formatted date or "No due date" placeholder
3. Make row tappable/focusable for editing

#### Phase 2: Date/Time Picker Component
1. Create `DateTimePickerView` component with:
   - Calendar grid for date selection
   - Time picker (hour/minute selectors)
   - "Clear" button to remove due date
   - "Today", "Tomorrow", "+1 Week" quick actions
2. Use native `DatePicker` as foundation, customize styling

#### Phase 3: Keyboard Navigation
1. Add `.dueDate` to `TaskDetailFocusableItem`
2. Enter on focused due date opens picker popover
3. Arrow keys navigate calendar, Enter selects

#### Phase 4: API Integration
1. Add `PATCH /tasks/{uuid}/due` endpoint or extend existing modify endpoint
2. Update `ApiClientProtocol` with `updateTaskDueDate(uuid:date:)`

### UX Designer Involvement Required
- Calendar picker layout and interaction design
- Quick action buttons placement
- Time picker format (12h vs 24h, increments)
- Mobile-friendly date input consideration

### Acceptance Criteria
- [ ] Due date displayed in task detail metadata
- [ ] Click/tap opens date picker popover
- [ ] Calendar allows month navigation
- [ ] Time can be selected
- [ ] Keyboard navigation works (hjkl to focus, Enter to open, arrows in calendar)
- [ ] Quick actions (Today, Tomorrow, etc.) work
- [ ] Clear button removes due date
- [ ] Changes persist to backend

### Dependencies
- Requires UX review before implementation

---

<a name="ticket-007"></a>
## TICKET-007: Task Linking via Command Palette

### Summary
Add ability to link tasks together through the command palette, with task selection UI and link type selection.

### Priority
High

### Complexity
Very High ⚠️⚠️

### Affected Layers
- **Rust Core**: `Link`, `LinkType` already exist in `task_model.rs`
- **Rust API**: Endpoints for creating/reading links
- **macOS**: New `TaskLinkSectionContributor.swift`, `TaskSelectorView.swift`, `TaskDetailView.swift` (linked tasks display)

### Current State
- Backend: `Link` struct exists with `from`, `to`, `link_type` fields
- Backend: `LinkType` enum defines relationship types
- Frontend: No UI for task linking yet

### Implementation Notes

#### Phase 1: API Layer
1. Verify/create endpoints:
   - `POST /tasks/{uuid}/links` - create link
   - `GET /tasks/{uuid}/links` - get linked tasks
   - `DELETE /tasks/{uuid}/links/{linkId}` - remove link
2. Update `ApiClientProtocol` with link methods

#### Phase 2: Task Selector Component
1. Create `TaskSelectorView` - reusable task list for selection only:
   - Uses existing `TaskListView` rendering
   - Filters out current task
   - Search/filter capability
   - Single-select mode (no detail navigation)
   - Returns selected task UUID
2. Style as modal/sheet

#### Phase 3: Command Palette Integration
1. Create `TaskLinkSectionContributor`:
   - Shows "Link to Task..." action when task selected
   - Opens task selector as submenu/modal
2. After task selected, show link type submenu:
   - "Blocks" (current task blocks selected)
   - "Blocked by" (current task blocked by selected)
   - "Related to"
   - "Duplicates"
   - "Parent of" / "Child of"

#### Phase 4: Display Linked Tasks
1. Add "Linked Tasks" section in TaskDetailView
2. Group by link type
3. Show task summary and status
4. Allow clicking to navigate to linked task
5. Allow removing links

### UX Designer Involvement Required
- Task selector modal design
- Link type selection UX flow
- Linked tasks display in detail view
- How to show bidirectional relationships
- Confirmation flows

### Acceptance Criteria
- [ ] Command palette shows "Link to Task..." when task selected
- [ ] Task selector allows filtering/searching tasks
- [ ] Task selector prevents selecting current task
- [ ] Link type selection presented after task selection
- [ ] Link created and persisted to backend
- [ ] Linked tasks displayed in task detail
- [ ] Can navigate to linked tasks
- [ ] Can remove links from detail view

### Dependencies
- Requires significant UX design input
- Backend link endpoints must be verified/implemented

---
<a name="ticket-009"></a>
## TICKET-009: File Attachments for Tasks

### Summary
Allow attaching files of any standard MIME type to tasks.

### Priority
Medium

### Complexity
Very High ⚠️⚠️

### Affected Layers
- **Rust Core**: New `Attachment` model, storage handling
- **Rust API**: File upload/download endpoints
- **Database**: New `attachments` table (migration)
- **macOS**: Attachment UI components, file picker, drag-drop handling

### Implementation Notes

#### Phase 1: Backend Model & Storage
1. Create `Attachment` struct:
   ```rust
   pub struct Attachment {
       pub id: i32,
       pub task_uuid: Uuid,
       pub filename: String,
       pub mime_type: String,
       pub size_bytes: i64,
       pub storage_path: String,
       pub created_at: DateTime<Local>,
   }
   ```
2. Migration for `attachments` table
3. File storage strategy (local filesystem with configurable path)

#### Phase 2: API Endpoints
1. `POST /tasks/{uuid}/attachments` - multipart upload
2. `GET /tasks/{uuid}/attachments` - list attachments
3. `GET /attachments/{id}` - download file
4. `DELETE /attachments/{id}` - remove attachment

#### Phase 3: macOS UI
1. Add "Attachments" section in TaskDetailView
2. "Add Attachment" button with file picker
3. Drag-and-drop zone
4. Attachment list with:
   - Filename and icon based on MIME type
   - File size
   - Click to open/preview
   - Delete button

### Acceptance Criteria
- [ ] Can add attachments via file picker
- [ ] Can add attachments via drag-and-drop
- [ ] Attachments listed in task detail
- [ ] Can download/open attachments
- [ ] Can delete attachments
- [ ] File size limits enforced
- [ ] MIME type validation

### Dependencies
- Significant backend work required
- Storage strategy decision needed

---

<a name="ticket-010"></a>
## TICKET-010: macOS Mail Integration

### Summary
Allow linking emails to tasks by dragging from Apple Mail into the task.

### Priority
Low

### Complexity
Very High ⚠️⚠️

### Affected Layers
- **macOS**: Drag-drop handling, `NSItemProvider` processing, Mail URL scheme handling

### Implementation Notes
1. Research Apple Mail drag-and-drop data format
2. Register for `NSItemProvider` types that Mail provides
3. Extract email metadata (subject, sender, date, message ID)
4. Create link using `message://` URL scheme
5. Store as special link type or attachment

### Acceptance Criteria
- [ ] Can drag email from Mail.app to task detail
- [ ] Email metadata captured (subject, sender)
- [ ] Clicking link opens email in Mail.app
- [ ] Works with multiple emails

### Dependencies
- TICKET-009 (attachments) or TICKET-007 (links) as storage mechanism
- macOS-specific, not portable

---
<a name="ticket-012"></a>
## TICKET-012: Fuzzy Match Text Highlighting

### Summary
In command palette, highlight the matched characters in fuzzy search results by making them bold and underlined.

### Priority
Medium

### Complexity
Medium

### Affected Layers
- **macOS**: `CommandPaletteFuzzyScorer.swift`, `CommandPaletteView.swift`

### Current State
- `CommandPaletteFuzzyScorer` has `fuzzyMatches(_:in:)` method that returns match info
- Currently only used for scoring, not highlighting

### Implementation Notes

1. Extend `fuzzyMatches` to return matched character indices:
   ```swift
   struct FuzzyMatchResult {
       let score: Int
       let matchedIndices: [String.Index]
   }
   ```

2. Create `HighlightedText` view component:
   ```swift
   struct HighlightedText: View {
       let text: String
       let highlightedIndices: [String.Index]

       var body: some View {
           // Build attributed string with bold+underline at indices
       }
   }
   ```

3. Update `CommandPaletteItemRow` to use `HighlightedText`

### UX Designer Involvement Required
- Exact styling for highlighted text (bold only? underline only? both? color?)
- Handling of long text with highlights

### Acceptance Criteria
- [ ] Matched characters shown in bold
- [ ] Matched characters shown with underline
- [ ] Highlighting updates as query changes
- [ ] Performance acceptable with many results

### Dependencies
- Requires UX input on styling

---

<a name="ticket-015"></a>
## TICKET-015: Project Overview View

### Summary
Add a new view that lists all projects with details and statistics.

### Priority
Medium

### Complexity
High

### Affected Layers
- **Rust API**: New endpoint for project stats
- **macOS**: New `ProjectOverviewView.swift`, navigation integration

### Implementation Notes

#### Backend
1. Create `GET /projects` endpoint returning:
   ```json
   {
     "projects": [
       {
         "name": "backend",
         "taskCount": 45,
         "pendingCount": 12,
         "activeCount": 3,
         "completedCount": 30,
         "overdueCount": 2
       }
     ]
   }
   ```

#### Frontend
1. Create `ProjectOverviewView`:
   - List of projects with stats
   - Click project to filter task list
   - Search/filter projects

2. Navigation integration:
   - Add to sidebar or mode switcher
   - Keyboard shortcut to access

### Acceptance Criteria
- [ ] Project overview accessible from main navigation
- [ ] Shows all projects with task counts
- [ ] Shows breakdown by status
- [ ] Can click project to see its tasks
- [ ] Can search/filter projects

### Dependencies
- Backend endpoint required

---

<a name="ticket-016"></a>
## TICKET-016: Important Links Section in Task Detail

### Summary
Add "Important Links" section in task detail (above "External Links") that only shows when links exist.

### Priority
Low

### Complexity
Low

### Affected Layers
- **macOS**: `TaskDetailView.swift`

### Implementation Notes
1. Define what constitutes "important" links (task dependencies? specific link types?)
2. Add conditional section before `externalLinksSection`:
   ```swift
   if !importantLinks.isEmpty {
       DetailSection(title: "Important Links") {
           // Link list
       }
   }
   ```
3. Style distinctly from external links

### Acceptance Criteria
- [ ] Section only shown when important links exist
- [ ] Links displayed with appropriate icons
- [ ] Can click to navigate to linked item
- [ ] Positioned above External Links

### Dependencies
- TICKET-007 (task linking) - defines what links exist

---

<a name="ticket-017"></a>
## TICKET-017: Global Dropdown Menu Trigger (Cmd+P)

### Summary
Add global Cmd+P binding to trigger the contextual dropdown menu in any view (Report menu in task list, Task state in task detail).

### Priority
Medium

### Complexity
Medium

### Affected Layers
- **macOS**: `LauncherApp.swift` (global shortcut), `ContentView.swift`, view-specific menu handling

### Current State
- Report menu exists in task list (upper right)
- Task state menu planned for task detail (TICKET-006)

### Implementation Notes

1. Define protocol for views with contextual menus:
   ```swift
   protocol ContextualMenuProvider {
       var hasContextualMenu: Bool { get }
       func showContextualMenu()
   }
   ```

2. Add global keyboard handler for Cmd+P:
   - Check current view/mode
   - Call appropriate menu display method

3. View implementations:
   - TaskListView: Opens report menu
   - TaskDetailView: Opens state menu (after TICKET-006)

### Acceptance Criteria
- [ ] Cmd+P in task list opens report menu
- [ ] Cmd+P in task detail opens task state menu
- [ ] Menu positioned appropriately
- [ ] Works regardless of focus state

### Dependencies
None (task detail menu now implemented via TICKET-006)

---
<a name="ticket-019"></a>
## TICKET-019: Multi-Select Tasks with Space

### Summary
Allow selecting multiple tasks from task list by pressing space on focused task.

### Priority
Medium

### Complexity
Medium

### Affected Layers
- **macOS**: `LauncherViewModel.swift`, `TaskListView.swift`, `TaskRow.swift`

### Current State
- Single task selection exists via `selectedTaskUUID`
- Keyboard navigation exists

### Implementation Notes

1. Add multi-selection state:
   ```swift
   @Published var selectedTaskUUIDs: Set<String> = []
   ```

2. Space key behavior:
   - If task not in set: add to selection
   - If task in set: remove from selection
   - Visual indication of selected state (checkbox? highlight?)

3. Actions on multi-selection:
   - Bulk status change
   - Bulk delete
   - Bulk tag add/remove

4. UI considerations:
   - Show selection count
   - Clear selection button
   - Different visual state for multi-selected tasks

### Acceptance Criteria
- [ ] Space toggles task selection
- [ ] Multiple tasks can be selected
- [ ] Selected tasks visually distinct
- [ ] Selection count shown
- [ ] Can clear selection
- [ ] Bulk actions available for selection

### Dependencies
None

---

<a name="ticket-020"></a>
## TICKET-020: Visual Grouping for Report Filter Chips

### Summary
Filter chips that come from the current report should be visually grouped/distinguished from manually added filters.

### Priority
Medium

### Complexity
Medium

### Affected Layers
- **macOS**: `CriteriaStripView.swift`, filter tracking

### Current State
- Filter chips displayed in criteria strip
- No distinction between report filters and manual filters

### Implementation Notes

1. Track filter source:
   ```swift
   struct FilterChip {
       let criteria: FilterCriteria
       let source: FilterSource  // .report | .manual
   }
   ```

2. Visual differentiation options (need UX input):
   - Different background color
   - Group separator
   - "From Report" label
   - Different border style

3. Behavior consideration:
   - Can manual filters override report filters?
   - Should report filters be removable?

### UX Designer Involvement Required
- Visual design for grouped chips
- Interaction design for filter removal

### Acceptance Criteria
- [ ] Report filters visually distinct from manual filters
- [ ] Clear indication of filter source
- [ ] Intuitive grouping

### Dependencies
- Requires UX design input

---

<a name="ticket-021"></a>
## TICKET-021: Info Tooltips for Filters/Properties

### Summary
Add circled "i" information icon to "Filters" and "Properties" labels that shows explanatory tooltip on hover.

### Priority
Low

### Complexity
Low

### Affected Layers
- **macOS**: Relevant section headers, tooltip component

### Implementation Notes

1. Create reusable info tooltip component:
   ```swift
   struct InfoTooltip: View {
       let text: String
       @State private var isShowing = false

       var body: some View {
           Image(systemName: "info.circle")
               .onHover { isShowing = $0 }
               .popover(isPresented: $isShowing) {
                   Text(text).padding()
               }
       }
   }
   ```

2. Add to section headers with appropriate explanatory text

### Acceptance Criteria
- [ ] Info icon shown next to "Filters" label
- [ ] Info icon shown next to "Properties" label
- [ ] Hover shows tooltip with explanation
- [ ] Tooltip dismisses when mouse leaves

### Dependencies
None

---

<a name="ticket-022"></a>
## TICKET-022: Help Mode with Cmd+Shift+H

### Summary
Cmd+Shift+H in text input expands the hint bar to show comprehensive help with available actions, filters, and properties.

### Priority
Medium

### Complexity
High

### Affected Layers
- **macOS**: `BottomHintBar.swift`, `LauncherViewModel.swift`, new `HelpModeView.swift`

### Implementation Notes

1. Add help mode state:
   ```swift
   @Published var isHelpModeExpanded: Bool = false
   ```

2. Animate hint bar expansion:
   - From default height to ~40% of window
   - Smooth animation

3. Help content structure:
   - Tab or section for Actions
   - Tab or section for Filters
   - Tab or section for Properties
   - Search/filter capability

4. Exit help mode:
   - Press Cmd+Shift+H again
   - Press Escape
   - Press any action key

### NOTE

You need to make sure that the source of truth for the list of
actions and filters and properties is coming from the backend

### Acceptance Criteria
- [ ] Cmd+Shift+H toggles help mode
- [ ] Hint bar animates to expanded size
- [ ] Actions list shown with descriptions
- [ ] Filters list shown with syntax examples
- [ ] Properties list shown with descriptions
- [ ] Can dismiss with key binding
- [ ] Help mode doesn't interfere with typing

### Dependencies
None

---

<a name="ticket-023"></a>
## TICKET-023: Clickable Hint Bar Items

### Summary
Hints shown in the hint bar should be clickable to trigger their associated action.

### Priority
Low

### Complexity
Medium

### Affected Layers
- **macOS**: `BottomHintBar.swift`, `HintChip.swift`, `InteractionContextCoordinator.swift`

### Current State
- `HintChip` displays key + label
- No tap handling

### Implementation Notes

1. Extend hint model to include action:
   ```swift
   struct HintItem {
       let key: String
       let label: String
       let action: (() -> Void)?
   }
   ```

2. Make `HintChip` tappable:
   ```swift
   HintChip(hint: hint)
       .onTapGesture {
           hint.action?()
       }
       .cursor(hint.action != nil ? .pointingHand : .arrow)
   ```

3. Wire up actions in `InteractionContextCoordinator`

### Acceptance Criteria
- [ ] Hint chips with actions show pointer cursor on hover
- [ ] Clicking hint triggers associated action
- [ ] Non-actionable hints remain non-clickable
- [ ] Visual feedback on click

### Dependencies
None

---

## Summary by Complexity

### Low Complexity (1-2 days)
- TICKET-016: Important Links Section
- TICKET-021: Info Tooltips

### Medium Complexity (3-5 days)
- TICKET-012: Fuzzy Match Highlighting
- TICKET-017: Global Dropdown Menu
- TICKET-019: Multi-Select Tasks
- TICKET-020: Report Filter Visual Grouping
- TICKET-023: Clickable Hint Bar Items

### High Complexity (1-2 weeks)
- TICKET-005: Due Date with Calendar Picker
- TICKET-015: Project Overview View
- TICKET-022: Help Mode

### Very High Complexity (2+ weeks)
- TICKET-007: Task Linking System
- TICKET-009: File Attachments
- TICKET-010: macOS Mail Integration

---

## Tickets Requiring UX Designer

1. **TICKET-005**: Due Date Picker - calendar layout, time picker design
2. **TICKET-007**: Task Linking - task selector modal, link type UX, display in detail
3. **TICKET-012**: Fuzzy Highlighting - styling decisions
4. **TICKET-020**: Report Filter Grouping - visual design

---

## Suggested Implementation Order

### Phase 1: Task Detail Enhancements
1. TICKET-005 (due date - after UX review)

### Phase 2: Command Palette & Navigation
2. TICKET-017 (global Cmd+P)
3. TICKET-012 (fuzzy highlighting)

### Phase 3: Advanced Features
5. TICKET-007 (task linking - needs UX)
6. TICKET-019 (multi-select)
7. TICKET-015 (project overview)

### Phase 4: Polish & Extras
8. TICKET-020 (filter grouping - needs UX)
9. TICKET-021 (info tooltips)
10. TICKET-022 (help mode)
11. TICKET-023 (clickable hints)
12. TICKET-016 (important links - after TICKET-007)

### Phase 5: Complex Integrations
13. TICKET-009 (file attachments)
14. TICKET-010 (mail integration)
