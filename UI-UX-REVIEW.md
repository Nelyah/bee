# UI/UX Review — 2025-12-31

## Assumptions
- Platform: macOS app (dark theme). (Based on window style and controls.)
- Primary goal: search/filter tasks and quickly understand which filters and task-property edits are active.
- This is a production screenshot (not a Figma comp). (Not explicitly stated.)

## Wireframe spec (implementation-ready)

### Layout (below search bar)
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [ Search field (existing) ]                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│ Report: default                     Active criteria                          │
│ ┌──────────────────────────────┐  ┌──────────────────────────────┐          │
│ │ Filters                       │  │ Properties                  │          │
│ │ [icon] Project: None   [x]    │  │ [icon] Due: +3d      [x]     │          │
│ │ [icon] Date: Yesterday [x]    │  │ [icon] Tags: +home  [x]      │          │
│ │ +2 more…                      │  │                              │          │
│ └──────────────────────────────┘  └──────────────────────────────┘          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Table header (ID | DATE | SUMMARY | DUE | TAGS | URGENCY)                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Sizing + spacing
- Criteria strip height: 56–72 px (one row) with allowance to grow to 2 rows.
- Column gutters: 16 px between Filters and Properties.
- Chip height: 24–28 px; internal padding 6 px vertical / 10–12 px horizontal.
- Align left edges of both columns to table header left edge.

### Components
- **Section labels**: “Filters” and “Properties”; 12–13 px, medium weight, 60–70% text opacity.
- **Chips**:
  - Structure: `[icon] Label` + optional value + remove affordance `[x]` on hover/focus.
  - Icon size: 12–14 px; consistent stroke weight.
  - Background: subtle pill (10–14% white) with 1 px border at 20% white.
  - Text: 12–13 px; ensure AA contrast on dark background.
- **Overflow**:
  - When >2 rows, replace additional chips with “+N more…” chip.
  - “+N more…” opens a popover list of all chips (grouped by column).

### Color + icon semantics
- Filters: one hue (e.g., blue/teal), applied to icon + 1 px left accent.
- Properties: different hue (e.g., amber/green), applied similarly.
- Avoid full-color fills; keep chip backgrounds neutral to prevent visual overload.

### Interaction
- Hover: chip background +4% brightness; show `[x]`.
- Focus: 2 px focus ring around chip; `[x]` always visible on focus.
- Remove: click `[x]`, or keyboard Delete/Backspace when focused.
- Popover: `Esc` closes; focus trapped within popover list.

### Empty states
- If no active items: show “No filters” / “No properties” in muted text.
- Keep strip height reserved to prevent layout jump when items appear.

## Top issues
- There is no visible place to show “active filters” or “task properties” under the search bar; as a result, users can’t confirm what will affect the list or the next action. (Only “Report: default” appears below the search.)
- The search bar is visually dominant (large height + strong outline), but the next most important context (filters/properties) is missing, creating an abrupt jump from search to table headers.
- The center-aligned “Report: default” label is low contrast and visually detached from the list header, so it’s easy to miss and unclear how it relates to the results.
- The table header row is low contrast and small relative to the search bar, so scanning column context (ID/DATE/SUMMARY/DUE/TAGS/URGENCY) is slower than it should be.
- Row content is sparse and uses placeholder dashes in several columns; without secondary structure or iconography, the row doesn’t clearly communicate what kind of item it is at a glance.

## Prioritised TODO list

- **ID**: UX-001  
  **Priority**: P1  
  **Effort**: M  
  **Evidence**: Main task list view; area directly below the search bar (currently only “Report: default” centered).  
  **Problem (rough)**: The UI provides no dedicated space to show active filters or pending TaskProperties changes, so users can’t verify scope or expected effects.  
  **Fix (rough)**:
  - Add a two-column “Active Criteria” strip directly below the search bar.
  - Left column label: “Filters”; right column label: “Properties” (or “Edits” if that’s the concept).
  - Render each active item as a chip with icon + label; align the two columns to the table width.
  - When empty, show a short empty-state hint (e.g., “No filters” / “No properties”).
  - Keep the strip height compact so the list remains visible.
  **Success criteria**: When a filter or TaskProperty is applied, a chip appears in the correct column within 1 frame; users can read all active criteria without opening a separate panel.

- **ID**: UX-002  
  **Priority**: P1  
  **Effort**: S  
  **Evidence**: Planned chip area below search; current UI has only the search icon as a semantic indicator.  
  **Problem (rough)**: Without a clear color/icon system, chips will be visually similar and harder to parse (filters vs properties and different kinds of criteria).  
  **Fix (rough)**:
  - Define a small semantic color palette: one hue for Filters, another for Properties; use neutral background with colored icon or left stripe to avoid over-saturation.
  - Map each chip type to a simple icon (e.g., calendar/date, tag, urgency, project) with consistent stroke weight.
  - Ensure text and icon contrast meets WCAG AA on the dark background.
  - Keep chip height consistent with table header height for visual rhythm.
  **Success criteria**: Users can differentiate Filters vs Properties and scan chip types within 1–2 seconds; no chip has contrast below AA for normal text.

- **ID**: UX-003  
  **Priority**: P1  
  **Effort**: M  
  **Evidence**: Chip area will sit between the search bar and the table header; vertical space is limited.  
  **Problem (rough)**: Multiple filters/properties could push the table down or create unpredictable layout jumps.  
  **Fix (rough)**:
  - Allow chips to wrap to a second row per column.
  - Add a max-height (e.g., 2 rows) with a “+N more” overflow chip that opens a popover list.
  - Preserve stable layout by reserving the strip height even when empty.
  **Success criteria**: Applying 6–10 criteria doesn’t obscure the table header; overflow is discoverable and accessible.

- **ID**: UX-004  
  **Priority**: P2  
  **Effort**: S  
  **Evidence**: “Report: default” label centered below search, low-contrast text.  
  **Problem (rough)**: Report context is easy to miss and visually detached from list controls.  
  **Fix (rough)**:
  - Move “Report: default” into the new criteria strip header (left-aligned) or into the search bar’s trailing area.
  - Increase contrast slightly or style as a small pill to match the new chip language.
  **Success criteria**: Report state is readable in a single glance and clearly tied to the list context.

- **ID**: UX-005  
  **Priority**: P1  
  **Effort**: S  
  **Evidence**: Planned chips below search; no visible interaction affordances in this area yet.  
  **Problem (rough)**: Without obvious affordances, users may not know how to remove or edit criteria once added.  
  **Fix (rough)**:
  - Add a subtle remove affordance on chips (x icon) that appears on hover/focus.
  - Ensure keyboard focus ring is visible and removal works via keyboard (Delete/Backspace).
  - Add hover/focus states that distinguish interactivity without increasing visual noise at rest.
  **Success criteria**: Users can remove a chip with mouse or keyboard in under 2 seconds; focus order is predictable and visible.

## Nice-to-haves
- Add a small legend or tooltip that explains the difference between Filters and Properties the first time a property chip appears.
- Consider a compact “Apply” or “Preview changes” affordance if TaskProperties are staged rather than immediate.

## Open questions
- Are TaskProperties applied immediately to the list results, or staged for the next action? (Affects chip labeling and affordances.)
- Do filters/properties need to be persisted across app launches, and if so, should the chip strip reflect saved state on open?

---

# UI/UX Review — 2025-12-30

## Assumptions
- Platform: macOS launcher (dark theme). (Based on UI style and prior context.)
- Primary goal: inspect a task’s metadata and external links quickly.
- This is a production screenshot (not a Figma comp). (Not explicitly stated.)

## Top issues
- The left side (Overview/Dates cards) reads as “small widgets,” but the center is largely empty; the screen lacks a clear focal column and feels unbalanced.
- External Links cards are readable but the hierarchy is flattened: key MR identifiers (status/state, link, branch) compete for attention and there’s no clear primary line of action or emphasis.
- Link rows have mixed visual weight (big badge at right, large MR icon at left, and dense metadata line), which makes scanning slower.
- Contrast for secondary metadata (state + url line) is borderline low against the dark card background, risking legibility on some displays.
- The “Refresh” control is appropriately quiet, but lacks hover/click feedback, so clickability isn’t obvious.

## Prioritised TODO list

## Nice-to-haves
- Add per-provider empty states that explain how to add links (e.g., “Use ⌘K to add a GitLab MR”).
- Add hover affordance on rows to make them feel clickable (subtle highlight on hover).

## Open questions
- Should External Links be the primary focus in detail view? If yes, I would prioritize it in the layout (right column or top section).

## Done
- **ID**: UX-004  
  **Status**: Done  
  **Evidence**: External Links rows; branch pill line.  
  **Summary**: Boosted the branch pill contrast with a brighter surface and subtle stroke, keeping the branch icon and monospaced label prominent.
- **ID**: UX-003  
  **Status**: Done  
  **Evidence**: External Links > GitLab rows; “Open • chat • url” line.  
  **Summary**: Added hover highlight for the URL (underline + slightly brighter text) to improve discoverability and legibility.
- **ID**: UX-002  
  **Status**: Done  
  **Evidence**: External Links > GitLab rows; mixed icon/badge sizes across the row.  
  **Summary**: Moved sync badge to the metadata line in a compact style and aligned the MR icon with the title baseline, letting the title be the primary focus.
- **ID**: UX-001  
  **Status**: Done  
  **Evidence**: Task Detail screen: large empty center area; cards clustered left.  
  **Summary**: Reflowed to a two-column layout (metadata left, links right) with a responsive single-column fallback, reducing empty space and clarifying focus.
- **ID**: UX-005  
  **Status**: Done  
  **Evidence**: External Links header; “Refresh” top-right.  
  **Summary**: Added subtle hover (underline + slight color shift) and pressed feedback to clarify clickability without increasing visual noise at rest.
