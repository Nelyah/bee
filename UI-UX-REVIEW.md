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
