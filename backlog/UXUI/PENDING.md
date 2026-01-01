# UI/UX Improvement Backlog

> Generated: 2026-01-01
> Reviewer: UI/UX Designer Agent
> Target: macos-launcher

---

## UXUI-001: Empty State Lacks Guidance

**Priority:** High
**Effort:** Low (2-4 hours)
**Component:** `TaskListView`

### Current State
When the task list is empty, the view displays:
- Column headers (ID, SUMMARY, TAGS, STATUS, URGENCY)
- "No filters" and "No properties" text
- Completely blank content area

Screenshot reference: `testEmptyState.1.png`

### Problem
Users see an empty table with no guidance on:
- Why there are no tasks (no matches? no tasks created?)
- How to create their first task
- How to modify filters if filtering caused empty results

This creates a confusing first-run experience and provides no recovery path when filters return no results.

### Desired State
1. Display an illustrated or iconographic empty state centered in the content area
2. Show contextual message based on state:
   - If filters active: "No tasks match your filters" + "Try removing some filters" action
   - If no filters: "No tasks yet" + "Press `i` to create your first task" hint
3. Include visual icon (e.g., empty checkbox, magnifying glass with X)
4. Optionally show quick action button for common operations

### Acceptance Criteria
- [ ] Empty state component exists with icon and message
- [ ] Message changes based on whether filters are active
- [ ] Keyboard hint is shown for task creation
- [ ] Visual design matches existing dark theme
- [ ] Snapshot test added for empty state variations

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskListView.swift`
- New: `Sources/LauncherApp/Views/Components/EmptyStateView.swift`

---

## UXUI-002: Text Truncation Without Context

**Priority:** High
**Effort:** Medium (4-8 hours)
**Component:** `TaskRow`, `TaskDetailView`

### Current State
Multiple text fields truncate awkwardly:
- Tags column: `code, re...` (truncates tag names)
- Status column: `complet...` (mid-word truncation)
- UUID in detail view: `uuid-123...` (unhelpful partial UUID)
- Task summary in narrow widths

Screenshot references: `testListModeWithTasks.1.png`, `testTaskDetailWithTask.1.png`

### Problem
1. Users cannot see full content without navigating to detail view
2. Mid-word truncation looks unprofessional (`complet...`)
3. Truncated UUIDs provide no value—neither readable nor copyable
4. No indication that more content exists beyond ellipsis

### Desired State
1. **Tags:** Show tooltip on hover with full tag list; consider "+N more" badge
2. **Status:** Ensure column width fits "completed" or use icons/abbreviations (✓ ⏳ ○)
3. **UUID:** Either hide entirely, show last 8 chars, or make copyable on click
4. **Summary:** Truncate with ellipsis + tooltip showing full text
5. All truncated text should show full content on hover (NSPopover or tooltip)

### Acceptance Criteria
- [ ] Status column never truncates mid-word
- [ ] Tags show "+N" overflow indicator when truncated
- [ ] Hover tooltip shows full content for any truncated field
- [ ] UUID is either hidden or shows useful portion (last 8 chars)
- [ ] Minimum column widths prevent critical truncation

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/TaskRow.swift`
- `Sources/LauncherApp/Views/TaskDetailView.swift`
- May need tooltip/popover utility component

---

## UXUI-003: Indistinguishable Row Selection States

**Priority:** Medium
**Effort:** Low (2-3 hours)
**Component:** `TaskRow`

### Current State
Task row appears nearly identical in:
- Default state
- Hovered state
- Selected state

All three use similar dark background with minimal differentiation.

Screenshot references: `testTaskRowDefault.1.png`, `testTaskRowHovered.1.png`, `testTaskRowSelected.1.png`

### Problem
Users cannot easily distinguish:
- Which row they're hovering over (preview)
- Which row is currently selected (will receive keyboard actions)
- This is especially problematic for keyboard-driven navigation

### Desired State
1. **Default:** Current dark background (#1e1e1e or similar)
2. **Hovered:** Subtle lighter background (#2a2a2a) - preview only
3. **Selected:** Distinct highlight with:
   - Brighter background (#3a3a3a)
   - Left accent border (2-3px, accent color like blue)
   - Subtle glow or shadow

### Acceptance Criteria
- [ ] Three visually distinct states exist
- [ ] Selected state is clearly identifiable even without hover
- [ ] Keyboard navigation shows selection moving between rows
- [ ] States work correctly when combined (selected + hovered)
- [ ] Snapshot tests capture all three states

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/TaskRow.swift`
- Possibly theme/color constants file

---

## UXUI-004: Detail View Unbalanced Layout

**Priority:** Medium
**Effort:** Medium (4-6 hours)
**Component:** `TaskDetailView`

### Current State
In the task detail view:
- All content is left-aligned
- Right ~40-50% of the view is empty space
- Status badge floats alone in top-right corner
- Cards stack vertically with no width constraint

Screenshot reference: `testTaskDetailFullContent.1.png`, `testDetailModeWithTask.1.png`

### Problem
1. Wastes screen real estate on wider windows
2. Eyes must travel far right to see status badge
3. Single-column layout doesn't scale well
4. Feels unfinished/sparse

### Desired State
Option A (simpler):
- Add `maxWidth` constraint (e.g., 600px) to content
- Center the constrained content in the view
- Move status badge closer to title

Option B (richer):
- Two-column layout on wide views:
  - Left: Main content (Overview, Dates, Links)
  - Right: Secondary content (Annotations, History, Quick Actions)
- Single column on narrow views (responsive)

### Acceptance Criteria
- [ ] Content doesn't stretch to full width on wide windows
- [ ] Status badge is visually connected to task title
- [ ] Layout looks balanced at various window sizes
- [ ] Responsive behavior if two-column approach used

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift`
- `Sources/LauncherApp/Views/Components/TaskDetailSections/`

---

## UXUI-005: Error States Lack Visual Prominence

**Priority:** High
**Effort:** Low (2-3 hours)
**Component:** `TaskDetailView`, error handling

### Current State
When an error occurs (e.g., "Failed to load task details"):
- Error is shown as plain red text
- No icon or visual container
- Easy to overlook among other content
- No recovery action offered

Screenshot reference: `testTaskDetailWithError.1.png`

### Problem
1. Errors can be missed by users scanning quickly
2. No clear call-to-action for recovery
3. Doesn't match severity of the issue
4. Plain text feels unintentional/debug-like

### Desired State
1. Error banner/card with:
   - Warning/error icon (⚠️ or ❌)
   - Contrasting background (dark red/orange tint)
   - Clear message text
   - Rounded corners matching other cards
2. Include "Retry" or "Dismiss" action button
3. Optionally: expandable details for debugging

### Acceptance Criteria
- [ ] Error component exists with icon + background
- [ ] Retry action triggers data reload
- [ ] Error is visually prominent and unmissable
- [ ] Matches dark theme aesthetic
- [ ] Snapshot test for error state

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift`
- New: `Sources/LauncherApp/Views/Components/ErrorBanner.swift`

---

## UXUI-006: Save Report Sheet Missing Features

**Status:** COMPLETED
**Priority:** Medium
**Effort:** Low (2-4 hours)
**Component:** `SaveReportSheet`

### Resolution
All features were already implemented in `SaveReportSheet.swift`. The backlog item was
created based on outdated snapshot images that lacked a proper background color, causing
UI elements to render invisibly against a transparent background.

Fixed by adding `.background(Color(NSColor.windowBackgroundColor))` to the view and
regenerating all snapshot reference images.

### Acceptance Criteria (All Met)
- [x] Cancel button exists and closes sheet
- [x] Validation messages appear inline (empty name, built-in report collision, user report overwrite)
- [x] Save button disabled when invalid (empty name)
- [x] Preview shows filters and columns (read-only)
- [x] Keyboard: Esc cancels, Enter saves (when valid)

### Files Modified
- `Sources/LauncherApp/Views/Components/SaveReportSheet.swift` - Added background color
- Regenerated 10 snapshot reference images in `__Snapshots__/SaveReportSheetSnapshotTests/`

---

## UXUI-007: "Stale" Warning Unclear

**Priority:** Low
**Effort:** Low (1-2 hours)
**Component:** `ExternalLinkRow`

### Current State
GitLab MR links show warning badge: `⚠️ Stale 1y ago`

Screenshot reference: `testGitLabMROpen.1.png`

### Problem
1. "Stale" is jargon—unclear what it means
2. "1y ago" what? Last synced? Last updated?
3. Users may not understand the warning's significance
4. No obvious action to resolve it

### Desired State
1. Change label to clearer text:
   - "Last synced 1y ago" or
   - "Sync outdated (1y)" or
   - "⚠️ Outdated"
2. Add tooltip explaining: "Link metadata was last fetched 1 year ago. Click Refresh to update."
3. Ensure "Refresh" button is visible/accessible

### Acceptance Criteria
- [ ] Label text is self-explanatory
- [ ] Tooltip provides full context
- [ ] Refresh action is easily accessible
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/ExternalLinkRow.swift`

---

## UXUI-008: Group Headers Need Visual Distinction

**Priority:** Low
**Effort:** Low (1-2 hours)
**Component:** `GroupHeaderRow`

### Current State
Project group headers ("bee", "infra") appear as:
- Plain text with collapse chevron
- Same font weight as task summaries
- No icon or badge

Screenshot reference: `testWithGroupedTasks.1.png`, `testGroupHeaderRowExpanded.1.png`

### Problem
1. Headers visually blend with task rows
2. No quick way to see task count per group
3. Looks like just another row rather than a section header

### Desired State
1. Add folder icon (📁) before project name
2. Use slightly bolder font weight (semibold)
3. Add task count badge: "bee (2)"
4. Subtle background tint or top border to separate sections

### Acceptance Criteria
- [ ] Folder icon appears before project name
- [ ] Font weight is heavier than task rows
- [ ] Task count badge shows number of tasks in group
- [ ] Visual separator between groups

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/GroupHeaderRow.swift`

---

## UXUI-009: Completion Menu Overlay Issues

**Priority:** Medium
**Effort:** Medium (3-5 hours)
**Component:** `CompletionMenu`

### Current State
When completion menu appears:
- Drops down from search field
- Covers underlying task rows
- No shadow or depth indication
- Can cover significant portion of list

Screenshot reference: `testWithCompletionMenu.1.png`

### Problem
1. Obscures task list content below
2. No visual depth cue (shadow/blur) indicating overlay
3. Can be disorienting as content disappears
4. Menu may extend beyond visible area

### Desired State
1. Add drop shadow to menu for depth perception
2. Consider maximum height with scroll (e.g., max 5-6 items visible)
3. Add subtle background blur behind menu (NSVisualEffectView)
4. Position to avoid covering the input field itself

### Acceptance Criteria
- [ ] Menu has drop shadow for depth
- [ ] Menu has max height with scrolling
- [ ] Background blur/dim effect applied
- [ ] Menu never covers the search input

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/CompletionMenu.swift`

---

## UXUI-011: "No filters" / "No properties" Placeholder Value

**Priority:** Low
**Effort:** Low (1-2 hours)
**Component:** `CriteriaStrip`

### Current State
When no filters or properties are active:
- Shows "No filters" and "No properties" text
- Takes up horizontal space
- Provides no actionable information

Screenshot reference: `testEmptyState.1.png`, `testFiltersWithEmptyProperties.1.png`

### Problem
1. Negative phrasing ("No...") isn't helpful
2. Takes space without adding value
3. Doesn't guide user to add filters/properties

### Desired State
Option A: Hide labels entirely when empty
Option B: Show subtle "+" button to add filter/property
Option C: Show only on hover/focus of that area

### Acceptance Criteria
- [ ] Empty state doesn't show "No X" text
- [ ] (If B) Add button provides way to add filter/property
- [ ] Space is either hidden or used productively

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/CriteriaStrip.swift`

---

## UXUI-012: Negative Phrasing Throughout Detail View

**Priority:** Low
**Effort:** Low (1-2 hours)
**Component:** `TaskDetailView`

### Current State
Detail view uses negative phrasing:
- "Not completed"
- "Not set"
- "No links yet"
- "No annotations"

Screenshot reference: `testTaskDetailWithError.1.png`

### Problem
1. Feels negative/pessimistic
2. "No links yet" implies user should add links even if not needed
3. Inconsistent with modern UI patterns that prefer neutral/positive language

### Desired State
1. Replace negative with neutral:
   - "Not completed" → "—" or "Pending"
   - "Not set" → "—"
   - "No links yet" → hide section or show "Add link" action
   - "No annotations" → hide section or "Add note"
2. Empty sections could collapse by default

### Acceptance Criteria
- [ ] No "Not X" or "No X" text visible
- [ ] Empty values show dash or are hidden
- [ ] Optional: empty sections collapsed by default

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift`
- `Sources/LauncherApp/Views/Components/DetailRow.swift`


---

## UXUI-014: Visual Consistency Audit

**Priority:** Medium
**Effort:** Medium (4-6 hours)
**Component:** App-wide

### Current State
Minor inconsistencies observed:
- Border radius varies between components
- Padding/margins not uniform
- Some icons appear slightly different sizes
- Column header alignment with cell content

### Problem
1. Subtle inconsistencies reduce perceived quality
2. Makes the app feel less polished
3. Can be distracting to detail-oriented users

### Desired State
1. Audit and standardize:
   - Border radius: define 2-3 standard values (small: 4px, medium: 8px, large: 12px)
   - Spacing: use consistent padding (8px, 12px, 16px increments)
   - Icon sizes: standardize (16px, 20px, 24px)
   - Typography: ensure consistent font weights and sizes
2. Create/update design tokens or constants file

### Acceptance Criteria
- [ ] Design tokens documented (radii, spacing, icon sizes)
- [ ] Components updated to use tokens
- [ ] Visual audit confirms consistency
- [ ] No mixed border-radius values

### Files Likely Affected
- `Sources/LauncherApp/Utilities/Theme.swift` or similar
- Multiple component files

---

## UXUI-015: Report Dropdown Discoverability

**Priority:** Low
**Effort:** Low (1-2 hours)
**Component:** `ReportMenuButton`

### Current State
Shows "Report: default ▾" in top-right corner of task list.

Screenshot reference: `testWithReportBadge.1.png`, `testDefaultState.1.png` (ReportMenuButton)

### Problem
1. "Report" terminology may be unfamiliar to new users
2. No tooltip or hint explaining what reports are
3. Looks like a label rather than interactive dropdown

### Desired State
1. Add tooltip on hover: "Switch between saved task views"
2. Consider clearer label: "View: default" or icon (📋) + name
3. Make dropdown affordance more obvious (bigger chevron, hover state)
4. First-time hint: subtle animation or badge for new users

### Acceptance Criteria
- [ ] Tooltip explains reports concept
- [ ] Hover state clearly indicates interactivity
- [ ] Label is understandable to new users

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/ReportMenuButton.swift`

---

# Ticket Index

| ID | Title | Priority | Effort | Status |
|----|-------|----------|--------|--------|
| UXUI-001 | Empty State Lacks Guidance | High | Low | Pending |
| UXUI-002 | Text Truncation Without Context | High | Medium | Pending |
| UXUI-003 | Indistinguishable Row Selection States | Medium | Low | Pending |
| UXUI-004 | Detail View Unbalanced Layout | Medium | Medium | Pending |
| UXUI-005 | Error States Lack Visual Prominence | High | Low | Pending |
| UXUI-006 | Save Report Sheet Missing Features | Medium | Low | Pending |
| UXUI-007 | "Stale" Warning Unclear | Low | Low | Pending |
| UXUI-008 | Group Headers Need Visual Distinction | Low | Low | Pending |
| UXUI-009 | Completion Menu Overlay Issues | Medium | Medium | Pending |
| UXUI-011 | "No filters" Placeholder Value | Low | Low | Pending |
| UXUI-012 | Negative Phrasing in Detail View | Low | Low | Pending |
| UXUI-014 | Visual Consistency Audit | Medium | Medium | Pending |
| UXUI-015 | Report Dropdown Discoverability | Low | Low | Pending |

---

## Effort Estimation Key

- **Low:** 1-4 hours (single component, straightforward change)
- **Medium:** 4-8 hours (multiple components or complex logic)
- **High:** 8+ hours (app-wide changes, significant refactoring)

## Priority Key

- **High:** Impacts usability, accessibility, or first impressions significantly
- **Medium:** Noticeable polish issue, improves experience
- **Low:** Nice-to-have refinement, minor improvement
