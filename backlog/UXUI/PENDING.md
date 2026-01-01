# UI/UX Improvement Backlog

> Generated: 2026-01-01
> Reviewer: UI/UX Designer Agent
> Target: macos-launcher

---

## UXUI-028: Add annotation creation functionality

**Category:** Feature
**Priority:** High
**Effort:** Medium (4-8 hours)
**Component:** `TaskDetailView`, `LauncherViewModel+TaskDetail`, `ApiClient`

### Current State
Users can view annotations but have no visible way to add new annotations to tasks from the detail view.

### Problem
The annotation workflow is unclear. Users expect to be able to add annotations directly from the detail view.

### Desired State
Allow users to add annotations to tasks from the detail view, either via button or keyboard shortcut.

### Acceptance Criteria
- [ ] "Add" button visible in Annotations section header
- [ ] `a` shortcut opens inline annotation input
- [ ] Enter submits, Escape cancels
- [ ] Toast confirms annotation added
- [ ] Annotation list refreshes after add

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift` (add input UI)
- `Sources/LauncherApp/ViewModels/LauncherViewModel+TaskDetail.swift` (add annotation action)
- `Sources/LauncherApp/Services/ApiClient.swift` (add annotation endpoint call)

---

## UXUI-031: Improve section header visual hierarchy

**Category:** Visual Polish
**Priority:** Medium
**Effort:** Low (1-2 hours)
**Component:** `TaskDetailView`

### Current State
Section headers have low contrast and blend with content.

### Problem
Section headers are not visually distinct enough for quick scanning.

### Desired State
Increase contrast and add accent to section headers for better scannability.

### Acceptance Criteria
- [ ] Section headers use higher contrast color
- [ ] Optional: Left accent bar in subtle color
- [ ] Passes WCAG AA contrast (4.5:1)

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift` (DetailSection)

---

## UXUI-032: Show copy icons persistently

**Category:** Discoverability
**Priority:** Medium
**Effort:** Low (1-2 hours)
**Component:** `GitLabLinkRowContent`, `DetailRow`

### Current State
Copy icons only appear on hover, making them undiscoverable.

### Problem
Users don't know copy functionality exists until they happen to hover.

### Desired State
Display copy icons at reduced opacity always, brighten on hover, to improve discoverability.

### Acceptance Criteria
- [ ] Copy icons visible at 40% opacity by default
- [ ] Icons brighten to 100% on hover
- [ ] Tooltip shows keyboard shortcut when available

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/GitLabLinkRowContent.swift`
- `Sources/LauncherApp/Views/Components/DetailRow.swift`

---

## UXUI-033: Add semantic status badge colors

**Category:** Visual Polish
**Priority:** Medium
**Effort:** Low (1-2 hours)
**Component:** `TaskDetailView`

### Current State
Status badges in detail view header are not color-coded.

### Problem
Status is not conveyed at a glance; users must read the text.

### Desired State
Color-code status badges to convey meaning visually.

### Acceptance Criteria
- [ ] "active" = green tint
- [ ] "pending" = yellow tint
- [ ] "completed" = gray tint
- [ ] Colors match TaskRow status indicators

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift` (header section)

---

## UXUI-034: Improve empty state messaging

**Category:** UX Copy
**Priority:** Low
**Effort:** Low (1-2 hours)
**Component:** `TaskDetailView`

### Current State
Empty sections show em-dash "---" placeholders.

### Problem
Em-dashes don't communicate what's missing or what the section would contain.

### Desired State
Replace em-dash empty states with descriptive text.

### Acceptance Criteria
- [ ] "No annotations" instead of "---"
- [ ] "No history" instead of "---"
- [ ] "No GitLab links" instead of "---"

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift`

---

## UXUI-035: Collapse empty external link providers

**Category:** Visual Polish
**Priority:** Low
**Effort:** Low (1-2 hours)
**Component:** `TaskDetailView`

### Current State
Empty provider sections (GitLab, Jira) are shown even when they have no links.

### Problem
Empty sections add visual noise and suggest missing data.

### Desired State
Hide provider sections when they have no links and loading is complete.

### Acceptance Criteria
- [ ] Empty provider sections hidden after load completes
- [ ] At least one provider always visible (or show "No external links")
- [ ] Loading state still shows all providers

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift` (ExternalLinksProviderSection)

---

## UXUI-036: Add context menu to timeline rows

**Category:** Feature
**Priority:** Low
**Effort:** Medium (4-8 hours)
**Component:** `TimelineRow`, `TaskDetailView`

### Current State
No right-click context menu on annotation/history entries.

### Problem
Users expect right-click menus for copy/delete actions on macOS.

### Desired State
Right-click on annotation/history entries to copy or (for annotations) delete.

### Acceptance Criteria
- [ ] Right-click shows context menu
- [ ] "Copy" option for all timeline rows
- [ ] "Delete" option for annotations only
- [ ] Delete triggers confirmation

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/TimelineRow.swift`
- `Sources/LauncherApp/Views/TaskDetailView.swift`

---

## UXUI-037: Fix TaskDetailView card alignment and visual consistency

**Category:** Visual Polish
**Priority:** High
**Effort:** Medium (4-8 hours)
**Component:** `TaskDetailView`, `DetailSection`, `DesignTokens`

### Current State
The TaskDetailView has inconsistent card widths and mixed visual treatments:
- Overview and Dates cards have variable widths based on content
- Overview uses `.primary` style (filled background), External Links uses `.tertiary` (no background)
- In two-column layout, columns don't align at top
- Section spacing is inconsistent (16px vs 8px vs 24px)

### Problem
Users perceive misaligned elements as "broken" or "unfinished." The mixed card treatments create false visual hierarchy where External Links appears less important than Overview/Dates when they should be peer sections.

### Desired State
All information cards should have consistent widths, padding, and visual treatment for a cohesive layout.

### Acceptance Criteria
- [ ] All cards in single-column mode have equal width
- [ ] Consistent visual treatment for all sections (either all cards or all borderless)
- [ ] Top alignment matches in two-column layout
- [ ] Consistent spacing between peer sections
- [ ] Section titles use same color regardless of style

### Specific Fixes Needed
1. **Card Width**: Set explicit widths or `maxWidth: .infinity` on single-column cards
2. **Visual Hierarchy**: Either give all sections card treatment or remove from Overview/Dates
3. **Top Alignment**: Match top padding in two-column HStack for External Links
4. **Spacing**: Use consistent `DesignTokens.Spacing.large` between all peer sections
5. **Title Color**: Use same foreground color for all section titles

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift` (lines 89-210, 302-344)
- `Sources/LauncherApp/Utilities/Design/DesignTokens.swift` (consider adding `cardWidth` token)

---

# Ticket Index

| ID | Title | Priority | Effort | Status |
|----|-------|----------|--------|--------|
| UXUI-037 | TaskDetailView card alignment | High | Medium | Pending |
| UXUI-028 | Add annotation creation functionality | High | Medium | Pending |
| UXUI-031 | Section header visual hierarchy | Medium | Low | Pending |
| UXUI-032 | Show copy icons persistently | Medium | Low | Pending |
| UXUI-033 | Semantic status badge colors | Medium | Low | Pending |
| UXUI-034 | Improve empty state messaging | Low | Low | Pending |
| UXUI-035 | Collapse empty external link providers | Low | Low | Pending |
| UXUI-036 | Context menu for timeline rows | Low | Medium | Pending |

---

## Effort Estimation Key

- **Low:** 1-4 hours (single component, straightforward change)
- **Medium:** 4-8 hours (multiple components or complex logic)
- **High:** 8+ hours (app-wide changes, significant refactoring)

## Priority Key

- **High:** Impacts usability, accessibility, or first impressions significantly
- **Medium:** Noticeable polish issue, improves experience
- **Low:** Nice-to-have refinement, minor improvement

---

> **Note:** Completed tickets have been moved to [DONE.md](DONE.md)
