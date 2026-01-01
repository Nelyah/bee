# UI/UX Improvement Backlog

> Generated: 2026-01-01
> Reviewer: UI/UX Designer Agent
> Target: macos-launcher

---

## UXUI-026: Save Report Sheet Doesn't Respond to Escape Key

**Category:** Bugfix
**Priority:** Medium
**Effort:** Low (1-2 hours)
**Component:** `SaveReportSheet`

### Current State
When the Save Report sheet is displayed:
- Cancel button closes the sheet
- Pressing Escape key does not close the window

### Problem
Users expect the standard macOS behavior where pressing Escape dismisses modal sheets. This is a standard convention across most macOS applications and is part of the system HIG (Human Interface Guidelines).

### Desired State
Pressing the Escape key should dismiss the Save Report sheet completely, matching the behavior of the Cancel button.

### Acceptance Criteria
- [ ] Escape key closes the Save Report sheet
- [ ] Escape key behavior matches Cancel button behavior
- [ ] No other keyboard shortcuts are affected
- [ ] Snapshot tests pass

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/SaveReportSheet.swift`

---

## UXUI-027: Implement keyboard navigation in detail view

**Category:** Accessibility
**Priority:** Critical
**Effort:** High (8+ hours)
**Component:** `TaskDetailView`, `ContentView`, `LauncherViewModel`

### Current State
The detail view is essentially mouse-only with no keyboard navigation support.

### Problem
Users cannot navigate interactive elements (links, copy buttons) in the detail view using the keyboard. This is a critical accessibility gap that prevents keyboard-first users from efficiently using the application.

### Desired State
Add vim-style navigation (j/k) to detail view allowing users to focus interactive elements and trigger them with Enter or dedicated shortcuts (o=open, y=copy).

### Acceptance Criteria
- [ ] j/k moves focus between interactive elements in detail view
- [ ] o opens focused link in browser
- [ ] y copies focused item (branch/URL/UUID)
- [ ] Focus ring visible on focused element
- [ ] BottomHintBar shows detail-mode shortcuts

### Files Likely Affected
- `Sources/LauncherApp/Views/TaskDetailView.swift`
- `Sources/LauncherApp/Views/ContentView.swift` (install detail-mode key monitor)
- `Sources/LauncherApp/ViewModels/LauncherViewModel.swift` (add detail focus state)

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

## UXUI-029: Fix CopyableDetailRow accessibility

**Category:** Accessibility
**Priority:** High
**Effort:** Low (1-2 hours)
**Component:** `DetailRow`

### Current State
CopyableDetailRow uses `onTapGesture` which is not accessible via keyboard or VoiceOver.

### Problem
Using tap gestures instead of proper Buttons breaks keyboard navigation and screen reader support.

### Desired State
Replace `onTapGesture` with proper Button for keyboard and VoiceOver accessibility.

### Acceptance Criteria
- [ ] UUID row focusable via Tab
- [ ] Enter/Space triggers copy
- [ ] VoiceOver announces "Copy UUID" with hint
- [ ] Focus ring visible when focused

### Files Likely Affected
- `Sources/LauncherApp/Views/Components/DetailRow.swift`

---

## UXUI-030: Add detail-mode hints to BottomHintBar

**Category:** Discoverability
**Priority:** High
**Effort:** Low (1-2 hours)
**Component:** `BottomHintModelBuilder`, `InteractionContextCoordinator`

### Current State
BottomHintBar does not show relevant shortcuts when in detail mode.

### Problem
Users don't discover available keyboard shortcuts for detail view actions.

### Desired State
Update hint model to show relevant shortcuts when in detail mode.

### Acceptance Criteria
- [ ] Detail mode shows: Esc=Back, o=Open, y=Copy, j/k=Navigate
- [ ] Hints update when focus changes

### Files Likely Affected
- `Sources/LauncherApp/Utilities/BottomHintModelBuilder.swift`
- `Sources/LauncherApp/Utilities/InteractionContextCoordinator.swift`

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

# Ticket Index

| ID | Title | Priority | Effort | Status |
|----|-------|----------|--------|--------|
| UXUI-026 | Save Report Sheet Doesn't Respond to Escape Key | Medium | Low | Pending |
| UXUI-027 | Keyboard navigation in detail view | Critical | High | Pending |
| UXUI-028 | Add annotation creation functionality | High | Medium | Pending |
| UXUI-029 | Fix CopyableDetailRow accessibility | High | Low | Pending |
| UXUI-030 | Detail-mode hints in BottomHintBar | High | Low | Pending |
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
