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

## Prioritised TODO list
- **ID**: UX-001  
  **Priority**: P1  
  **Effort**: M  
  **Evidence**: Task Detail screen: large empty center area; cards clustered left.  
  **Problem (rough)**: Layout feels unbalanced; focal point is unclear, wasting space and reducing scan efficiency.  
  **Fix (rough)**:
  - Reflow into a two-column layout: left column for metadata cards, right column for External Links list.
  - Constrain cards to consistent widths and align their left edges.
  - Consider reducing vertical gaps between metadata cards.  
  **Success criteria**: User’s eye naturally moves from title → metadata → links without a large empty gap; list reads as the primary content block.

- **ID**: UX-002  
  **Priority**: P1  
  **Effort**: S  
  **Evidence**: External Links > GitLab rows; mixed icon/badge sizes across the row.  
  **Problem (rough)**: The large status badge on the right and large MR icon on the left compete, making the row feel busy.  
  **Fix (rough)**:
  - Reduce the right sync badge size or move it to the metadata line.
  - Align MR icon and title baseline; keep icons consistent size across rows.
  - Make the title line the single strongest typographic element.  
  **Success criteria**: At a glance, the title line is clearly primary, with metadata as secondary.

- **ID**: UX-003  
  **Priority**: P1  
  **Effort**: S  
  **Evidence**: External Links > GitLab rows; “Open • chat • url” line.  
  **Problem (rough)**: Secondary metadata line has low contrast, making state + link harder to read.  
  **Fix (rough)**:
  - Increase text contrast slightly for the metadata line (e.g., subtext0 → subtext1).
  - Consider truncating URL earlier or styling it as a subdued link pill.  
  **Success criteria**: Secondary line is readable at a glance without straining; URL remains discoverable.

- **ID**: UX-004  
  **Priority**: P2  
  **Effort**: S  
  **Evidence**: External Links rows; branch pill line.  
  **Problem (rough)**: Branch pill is visually similar to metadata line; it doesn’t clearly read as a code/branch token.  
  **Fix (rough)**:
  - Increase contrast or use a slightly brighter pill background.
  - Add a small branch icon and keep monospaced text for code affordance.  
  **Success criteria**: Branch line feels like a code token and is distinct from the status line.

## Nice-to-haves
- Add per-provider empty states that explain how to add links (e.g., “Use ⌘K to add a GitLab MR”).
- Add hover affordance on rows to make them feel clickable (subtle highlight on hover).

## Open questions
- Should External Links be the primary focus in detail view? If yes, I would prioritize it in the layout (right column or top section).
