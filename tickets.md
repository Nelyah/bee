# Bee Feature Tickets

This document contains detailed tickets for features requested in `feature-list.txt`. Each ticket includes scope, complexity assessment, affected layers, and implementation notes.

---

## Table of Contents

1. [TICKET-010: macOS Mail Integration](#ticket-010)
2. [TICKET-012: Fuzzy Match Text Highlighting](#ticket-012)
3. [TICKET-015: Project Overview View](#ticket-015)
4. [TICKET-016: Important Links Section in Task Detail](#ticket-016)
5. [TICKET-019: Multi-Select Tasks with Space](#ticket-019)
6. [TICKET-020: Visual Grouping for Report Filter Chips](#ticket-020)
7. [TICKET-021: Info Tooltips for Filters/Properties](#ticket-021)
8. [TICKET-022: Help Mode with Cmd+Shift+H](#ticket-022)

See [DONE.md](DONE.md) for completed tickets.

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

## Summary by Complexity

### Low Complexity (1-2 days)
- TICKET-016: Important Links Section
- TICKET-021: Info Tooltips

### Medium Complexity (3-5 days)
- TICKET-012: Fuzzy Match Highlighting
- TICKET-019: Multi-Select Tasks
- TICKET-020: Report Filter Visual Grouping

### High Complexity (1-2 weeks)
- TICKET-015: Project Overview View
- TICKET-022: Help Mode

### Very High Complexity (2+ weeks)
- TICKET-010: macOS Mail Integration

---

## Tickets Requiring UX Designer

1. **TICKET-012**: Fuzzy Highlighting - styling decisions
2. **TICKET-020**: Report Filter Grouping - visual design

---

## Suggested Implementation Order

### Phase 1: Command Palette & Navigation
1. TICKET-012 (fuzzy highlighting)

### Phase 2: Advanced Features
3. TICKET-019 (multi-select)
4. TICKET-015 (project overview)
5. TICKET-016 (important links - builds on TICKET-007)

### Phase 3: Polish & Extras
6. TICKET-020 (filter grouping - needs UX)
7. TICKET-021 (info tooltips)
8. TICKET-022 (help mode)

### Phase 4: Complex Integrations
9. TICKET-010 (mail integration)
