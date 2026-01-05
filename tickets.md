# Bee Feature Tickets

This document contains detailed tickets for features requested in `feature-list.txt`. Each ticket includes scope, complexity assessment, affected layers, and implementation notes.

---

## Table of Contents

1. [TICKET-016: Important Links Section in Task Detail](#ticket-016)
2. [TICKET-021: Info Tooltips for Filters/Properties](#ticket-021)
3. [TICKET-022: Help Mode with Cmd+Shift+H](#ticket-022)

See [DONE.md](DONE.md) for completed tickets.

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

### High Complexity (1-2 weeks)
- TICKET-022: Help Mode

---

## Suggested Implementation Order

### Phase 1: Advanced Features
1. TICKET-016 (important links - builds on TICKET-007)

### Phase 2: Polish & Extras
2. TICKET-021 (info tooltips)
3. TICKET-022 (help mode)
