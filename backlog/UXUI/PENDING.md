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

## UXUI-016: Monochromatic Gray Soup - Low Surface Differentiation

**Priority:** High
**Effort:** Medium (4-6 hours)
**Component:** App-wide theme colors

### Current State
The entire interface uses a narrow luminosity band (~12-30% HSL lightness):
- Background: `#1e1e2e` (base)
- Task rows: same `#1e1e2e` (base)
- Hover: `#313244` (surface0)
- Selected: `#45475a` (surface1)

Contrast ratios between surface levels:
- Base to surface0: 1.3:1
- Base to surface1: 1.6:1
- Base to surface2: 1.9:1

A noticeable difference typically requires at least 2:1.

### Problem
Everything exists in a narrow luminosity range creating "gray soup" where nothing pops. Users cannot quickly distinguish interactive states from static content. This is the primary contributor to the "cheap" appearance.

### Desired State
1. Increase contrast between surface levels to minimum 2:1
2. Consider accent color tinting for selection states (blue at 8-15% opacity)
3. Add subtle shadows to lift interactive elements
4. Skip surface0 for interactive states - jump to surface1 for hover

### Acceptance Criteria
- [ ] Surface color contrast ratios improved to 2:1 minimum
- [ ] Selected rows are immediately distinguishable at a glance
- [ ] Hover states clearly indicate interactivity
- [ ] Theme colors documented with contrast ratios

### Files Likely Affected
- `Sources/LauncherApp/Utilities/Design/Theme.swift`
- `Sources/LauncherApp/Views/TaskRow.swift`
- Multiple component files

---

## UXUI-017: Text Hierarchy Lacks Weight Differentiation

**Priority:** High
**Effort:** Medium (4-6 hours)
**Component:** Typography across views

### Current State
Text hierarchy relies on subtle color shifts:
- Task ID: `subtext0` (#a6adc8) - 12px medium
- Summary: `text` (#cdd6f4) - 15px semibold
- Status/Tags: `subtext1` (#bac2de) - 12px medium

The color progression from overlay0 → subtext0 → subtext1 → text has only ~20% luminosity difference between levels.

### Problem
1. Summary doesn't dominate - it visually competes with metadata
2. ID and secondary info blend together
3. Scanning a list is difficult because nothing anchors the eye
4. Font weight differences (medium vs semibold) are too subtle

### Desired State
More aggressive weight/color differentiation:
- Summary: 15px **bold** (not semibold), full `text` color
- Secondary (Status, Tags): 12px medium, `subtext0` (push back from subtext1)
- Tertiary (ID, Urgency): 11px regular, `overlay0` (most muted)

### Acceptance Criteria
- [ ] Task summary is the clear visual anchor in each row
- [ ] Three distinct hierarchy levels are immediately apparent
- [ ] Typography weights documented in DesignTokens
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskRow.swift`
- `Sources/LauncherApp/Utilities/Design/DesignTokens.swift`
- Multiple component files

---

## UXUI-018: Selection State Still Too Subtle

**Priority:** High
**Effort:** Low (2-4 hours)
**Component:** `TaskRow`

### Current State
Selection is indicated by:
- 5px blue accent bar on left edge
- Background change from base (#1e1e2e) to surface1 (#45475a) - only 1.6:1 contrast

### Problem
1. The accent bar is 5px on a ~700px wide row - easy to miss
2. Selected background has insufficient contrast with unselected
3. Native macOS apps use ~3:1 contrast for selection with vibrant color fills

### Desired State
Options to consider:
1. Add subtle blue glow/shadow to accent bar to extend its visual presence
2. Tint selection background with accent color (blue at 8-15% opacity)
3. Add subtle outline stroke on selected rows
4. Increase background contrast to surface2 for selection

### Acceptance Criteria
- [ ] Selection state is unmistakable at a glance
- [ ] Works well with keyboard navigation
- [ ] Maintains visual harmony with overall theme
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskRow.swift`

---

## UXUI-019: Status Indicators Lack Visual Impact

**Priority:** Medium
**Effort:** Low (2-4 hours)
**Component:** Task rows - status visualization

### Current State
Status shown as:
- 8px colored circle (green/yellow/blue)
- Text label ("active", "pending", "completed") in subtext1 color

### Problem
1. 8px dots don't provide enough visual weight for quick scanning
2. Pastel Catppuccin accent colors lack punch against dark background
3. Status text and dot are redundant - showing same info twice
4. Completed tasks look identical to active except for color

### Desired State
Options:
1. Larger status dots (10px) with subtle glow/shadow
2. Replace text with status badges/pills (colored background capsule)
3. Dim completed tasks (60-70% opacity) to visually separate done from active
4. Remove redundant status text, let the dot speak

### Acceptance Criteria
- [ ] Status is scannable at a glance across many rows
- [ ] Completed tasks are visually distinct from active
- [ ] Status indicators have sufficient visual weight
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskRow.swift`
- `Sources/LauncherApp/Utilities/Design/StatusColor.swift`

---

## UXUI-020: Column Headers Nearly Invisible

**Priority:** Medium
**Effort:** Low (2-3 hours)
**Component:** Task list headers

### Current State
Headers ("ID", "SUMMARY", "TAGS", "STATUS", "URGENCY") use:
- Very muted gray color
- Same or similar treatment as content below
- No visual separation (divider, background, spacing)

### Problem
1. Headers blend into content - hard to distinguish structure
2. All-caps at small size is hard to read
3. No clear visual break between header and content area

### Desired State
Options:
1. Increase header font weight to bold, add letter-spacing for all-caps
2. Add subtle divider below headers
3. Use slightly brighter text color (subtext0 minimum)
4. OR: Remove headers entirely for cleaner Spotlight-like feel

### Acceptance Criteria
- [ ] Headers are clearly distinguished from content (or removed)
- [ ] If kept, headers provide clear column identification
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskListView.swift`
- `Sources/LauncherApp/Views/Components/HeaderRow.swift` (if exists)

---

## UXUI-021: Inconsistent Border/Separator System

**Priority:** Medium
**Effort:** Medium (4-6 hours)
**Component:** App-wide borders

### Current State
Borders are used inconsistently:
- Window border: `surface1.opacity(0.5)` - 1px
- Bottom hint bar: `surface1.opacity(0.5)` - 1px
- Detail view cards: `surface1` full opacity
- Group headers: No border
- Task rows: No border

The opacity(0.5) borders are nearly invisible.

### Problem
Inconsistent borders make some elements feel "designed" while others feel like placeholders. Creates visual noise without clear purpose.

### Desired State
Establish a border system:
1. Container borders: Full opacity `surface1`
2. Focus states: Accent color (blue)
3. Separators: `surface0.opacity(0.8)`

Either commit to visible borders or remove them and use spacing/shadow.

### Acceptance Criteria
- [ ] Border system documented in DesignTokens
- [ ] All components use consistent border treatment
- [ ] Borders serve clear visual purpose
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Utilities/Design/DesignTokens.swift`
- Multiple view files

---

## UXUI-022: Command Palette Lacks Depth

**Priority:** Medium
**Effort:** Low (2-4 hours)
**Component:** `CommandPaletteView`

### Current State
- Dark overlay background
- Rounded panel with surface0/surface1 fills
- No shadow or blur behind the palette
- Selected item uses subtle background shift

### Problem
1. Palette doesn't "float" - feels flat on the interface
2. No visual depth cues (shadow, blur) to indicate overlay
3. Selected item too subtle
4. Icons same muted color as text - don't aid scanning

### Desired State
1. Add drop shadow to palette container
2. Consider background blur (.ultraThinMaterial)
3. Make selected item more prominent (blue tint at 15-20% opacity)
4. Tint icons with semantic colors

### Acceptance Criteria
- [ ] Command palette clearly floats above content
- [ ] Selected item is immediately obvious
- [ ] Icons are scannable
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Views/CommandPaletteView.swift`

---

## UXUI-023: Detail View Card Hierarchy Flat

**Priority:** Medium
**Effort:** Medium (4-6 hours)
**Component:** `TaskDetailView`

### Current State
All cards (Overview, External Links, Dates, Annotations, History) have:
- Similar visual treatment
- Equal visual weight
- Same border/background style

### Problem
1. Everything competes for attention - no clear focal point
2. Primary info (task title, status) is same size as auxiliary info
3. External links get as much visual real estate as core task data

### Desired State
Create visual hierarchy through card weights:
1. **Primary**: Task title + status prominently at top (no card wrapper)
2. **Secondary**: Overview, Dates - bordered cards
3. **Tertiary**: External Links, Annotations, History - borderless, compact

Consider two-column layout with core info dominating.

### Acceptance Criteria
- [ ] Clear visual hierarchy between card types
- [ ] Task title/status is the focal point
- [ ] Auxiliary info is clearly secondary
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift`
- `Sources/LauncherApp/Views/Components/TaskDetailSections/`

---

## UXUI-024: Bottom Hint Bar Visual Weight

**Priority:** Low
**Effort:** Low (1-2 hours)
**Component:** `BottomHintBar`

### Current State
Hint bar shows keyboard shortcuts with key chips in a floating bar:
- Ultra-thin material + surface0 fill
- Takes 34px of vertical space
- Always visible

### Problem
1. Creates visual noise at bottom of interface
2. Constant presence reduces content space
3. Competes for attention with actual content

### Desired State
Options:
1. Fade to lower opacity when not hovered (0.4 → 1.0 on hover)
2. Move hints inline to search bar placeholder
3. Remove surface0 fill, use material only

### Acceptance Criteria
- [ ] Hint bar doesn't compete with content
- [ ] Hints remain discoverable
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/BottomHintBar.swift`

---

## UXUI-025: Search Input Focus Enhancement

**Priority:** Low
**Effort:** Low (1-2 hours)
**Component:** Search input field

### Current State
- Blue ring on focus
- Muted placeholder text
- Search icon same color as inactive elements

### Problem
1. Placeholder text could have higher contrast
2. Search icon doesn't brighten on focus
3. No animation to draw eye on focus

### Desired State
1. Subtle scale animation on focus (1.01x)
2. Brighten search icon when focused
3. Slightly increase placeholder text contrast

### Acceptance Criteria
- [ ] Focus state is clearly indicated
- [ ] Smooth transition animation
- [ ] Snapshot tests updated

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/TokenHighlightTextView.swift`

---

# Ticket Index

| ID | Title | Priority | Effort | Status |
|----|-------|----------|--------|--------|
| UXUI-001 | Empty State Lacks Guidance | High | Low | ✅ Complete |
| UXUI-002 | Text Truncation Without Context | High | Medium | ✅ Complete |
| UXUI-003 | Indistinguishable Row Selection States | Medium | Low | ✅ Complete |
| UXUI-004 | Detail View Unbalanced Layout | Medium | Medium | ✅ Complete |
| UXUI-005 | Error States Lack Visual Prominence | High | Low | ✅ Complete |
| UXUI-006 | Save Report Sheet Missing Features | Medium | Low | ✅ Complete |
| UXUI-007 | "Stale" Warning Unclear | Low | Low | ✅ Complete |
| UXUI-008 | Group Headers Need Visual Distinction | Low | Low | ✅ Complete |
| UXUI-009 | Completion Menu Overlay Issues | Medium | Medium | ✅ Complete |
| UXUI-011 | "No filters" Placeholder Value | Low | Low | ✅ Complete |
| UXUI-012 | Negative Phrasing in Detail View | Low | Low | ✅ Complete |
| UXUI-014 | Visual Consistency Audit | Medium | Medium | ✅ Complete |
| UXUI-015 | Report Dropdown Discoverability | Low | Low | ✅ Complete |
| UXUI-016 | Monochromatic Gray Soup | High | Medium | Pending |
| UXUI-017 | Text Hierarchy Lacks Weight | High | Medium | Pending |
| UXUI-018 | Selection State Too Subtle | High | Low | Pending |
| UXUI-019 | Status Indicators Lack Impact | Medium | Low | Pending |
| UXUI-020 | Column Headers Invisible | Medium | Low | Pending |
| UXUI-021 | Inconsistent Border System | Medium | Medium | Pending |
| UXUI-022 | Command Palette Lacks Depth | Medium | Low | Pending |
| UXUI-023 | Detail View Card Hierarchy | Medium | Medium | Pending |
| UXUI-024 | Bottom Hint Bar Weight | Low | Low | Pending |
| UXUI-025 | Search Input Focus | Low | Low | Pending |

---

## Effort Estimation Key

- **Low:** 1-4 hours (single component, straightforward change)
- **Medium:** 4-8 hours (multiple components or complex logic)
- **High:** 8+ hours (app-wide changes, significant refactoring)

## Priority Key

- **High:** Impacts usability, accessibility, or first impressions significantly
- **Medium:** Noticeable polish issue, improves experience
- **Low:** Nice-to-have refinement, minor improvement
