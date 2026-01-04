# Completed Tickets

Tickets moved here after implementation and review.

---

## TICKET-018: Fix Task ID Filter Chip Float Display
**Completed:** 2026-01-02

### Summary
Filter chip for task ID shows a float with decimals (e.g., "1.0") but ID is an integer.

### Resolution
Fixed in `CriteriaChipBuilder.swift` - changed to check `numberValue` before `stringValue` and format as Int.

---

## TICKET-002: Hint Bar - Remove Enter Keybind During Edit
**Completed:** 2026-01-02

### Summary
When in edit mode (task name or annotation editing), remove the "Enter" hint from the hint bar since Enter now submits the edit.

### Resolution
Added `isEditing` parameter to `InteractionContext.detail` case. InteractionContextCoordinator now filters hints based on editing state.

---

## TICKET-003: Hint Bar - Show Cmd+Enter Saves Changes
**Completed:** 2026-01-02

### Summary
When in edit mode, show "⌘↩ Save" hint in the hint bar.

### Resolution
Implemented together with TICKET-002 - editing hints now show save/cancel instead of normal navigation hints.

---

## TICKET-004: Escape Cancels Edit with Hint Bar Update
**Completed:** 2026-01-02

### Summary
Escape key should cancel the current edit operation, and hint bar should show "Esc Cancel" during edit mode.

### Resolution
Implemented together with TICKET-002/003 - escape handling and hint bar updates bundled.

---

## TICKET-008: Collapse History Pane by Default
**Completed:** 2026-01-02

### Summary
The history section in TaskDetailView should be collapsed by default and expandable on demand.

### Resolution
Added `@State private var isHistoryExpanded: Bool = false` with chevron toggle button. Styled to match DetailSection pattern (uppercased title, same fonts/colors).

---

## TICKET-011: UUID Hover Highlight
**Completed:** 2026-01-02

### Summary
UUID in task detail should become highlighted on hover to indicate it's clickable anywhere.

### Resolution
Updated `CopyableDetailRow` to show underline and copy icon on hover. Added `CopyableDetailRowButtonStyle` for hover+focus states.

---

## BUG-001: Annotation Editing Shows Wrong Content
**Completed:** 2026-01-02

### Summary
Clicking on the 2nd annotation to edit shows the 1st annotation's content instead.

### Root Cause
View displayed annotations sorted by time (descending) but passed sorted array index to ViewModel, which accessed unsorted `detail.annotations[index]`.

### Resolution
Changed from index-based to ID-based annotation identification:
- `editingAnnotationIndex: Int?` → `editingAnnotationId: String?`
- `startEditingAnnotation(at:)` → `startEditingAnnotation(withId:)`

---

## BUG-002: Detail Mode Keybinds Active During Annotation Edit
**Completed:** 2026-01-02

### Summary
Pressing 'a' while editing an annotation would trigger "add annotation" instead of typing the letter.

### Resolution
Added `viewModel.editingAnnotationId == nil` and `!viewModel.isEditingTaskName` guards to detail mode key monitor.

---

## TICKET-001: Task Name Keyboard Navigation in Detail View
**Completed:** 2026-01-03

### Summary
Enable keyboard navigation to select and edit the task name in TaskDetailView using hjkl navigation, with Enter to start editing.

### Resolution
- Extended `DetailFocusableItem` enum to include `.taskName`, `.project`, `.tag`, `.addTagButton` cases
- Added hjkl navigation logic in `KeyHandlingDecider.detailModeAction()`
- Focus ring shows on all focusable items via `DetailFocusRing` modifier
- Enter on focused task name calls `startEditingTaskName()`
- Hint bar shows navigation and action hints

---

## TICKET-013: Inline Project Editing in Task Detail
**Completed:** 2026-01-03

### Summary
Allow selecting and modifying the project in task detail with both mouse and keyboard, with autocomplete.

### Resolution
- Created `EditableProjectRow` component with display/edit modes
- Reused `CompletionField` for fuzzy autocomplete
- Project row is focusable via hjkl navigation
- Enter to start editing, Escape to cancel
- Autocomplete dropdown with fuzzy matching
- Changes persist via API

---

## TICKET-014: Inline Tags Editing in Task Detail
**Completed:** 2026-01-03

### Summary
Allow selecting and modifying tags in task detail with both mouse and keyboard, with autocomplete.

### Resolution
- Created `EditableTagsRow` component with tag chips and add button
- Created `TagChip` component with remove button
- h/l navigation between tags when focused on a tag
- "+" add button is keyboard-focusable
- "t" keybinding to start adding a tag from anywhere in detail view
- Hint bar shows "t Add tag" hint
- Freeform entry mode allows creating new tags
- CompletionField stays open with empty state when no matches
- Tags rebuild in navigation list after add/remove

---

## TICKET-006: Command Palette Task State Actions
**Completed:** 2026-01-04

### Summary
Add command palette options to change task state: delete, completed, active, pending.

### Resolution
- Created `TaskStateSectionContributor` that shows "Mark task as..." section when a task is selected
- Four actions: Completed, Active, Pending, Deleted
- Created `LauncherViewModel+TaskState.swift` with `TaskStateAction` enum and handlers
- Local state updates after API calls (no full refresh needed)
- Toast notifications confirm actions
- No confirmation dialog for delete (undo support planned for future)

---

## TICKET-023: Clickable Hint Bar Items
**Completed:** 2026-01-04

### Summary
Hints shown in the hint bar should be clickable to trigger their associated action.

### Resolution
- Created `Keybinding.swift` with `Keybinding` struct and `KeybindingRegistry` as single source of truth
- Auto-generated display strings (e.g., "⌘K", "Enter", "Tab") from keyCode + modifiers
- Added `HintAction` enum for type-safe click handling
- Updated `BottomHint` model with keybinding initializer for auto-derived display keys
- Made `HintChip` clickable with pointing hand cursor and hover background effect
- Created `LauncherViewModel+HintActions.swift` to route actions to existing methods
- Non-actionable hints (e.g., "hjkl Navigate") remain non-clickable
