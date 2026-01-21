# DetailEditingState Enum Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace 8 individual editing state boolean flags with a single `DetailEditingState` enum that automatically resigns text field focus and enforces mutual exclusivity.

**Architecture:** Single enum with `didSet` observer calls `resignTextFieldFocus()` when transitioning to `.none`. All views use exhaustive `switch` statements (no `default` cases) to ensure compile-time safety when adding new cases.

**Tech Stack:** Swift, SwiftUI, Combine

---

## Task 1: Add DetailEditingState Enum

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel.swift:1-10`

**Step 1: Add enum definition after imports**

```swift
/// Represents the single active editing state in the detail view.
/// Only one editing state can be active at a time, enforcing mutual exclusivity.
enum DetailEditingState: Equatable {
    case none
    case addingAnnotation
    case editingAnnotation(id: String)
    case editingTaskName
    case editingProject
    case addingTag
    case editingDueDate
    case editingPlannedDate
    case addingImportantLink

    var isEditing: Bool { self != .none }
}
```

**Step 2: Build to verify syntax**

Run: `cd /Users/chloe/builds/bee/macos-launcher && swift build 2>&1 | head -20`
Expected: Build succeeds (enum not used yet)

**Step 3: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel.swift
git commit -m "feat(macos): add DetailEditingState enum definition"
```

---

## Task 2: Add detailEditingState Property with didSet

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel.swift:90-95`

**Step 1: Add the new property after line 89 (before existing editing state section)**

```swift
// MARK: - Detail Editing State

/// The single source of truth for which editing state is active.
/// Uses didSet to resign text field focus when transitioning to .none.
@Published var detailEditingState: DetailEditingState = .none {
    didSet {
        if oldValue != .none && detailEditingState == .none {
            resignTextFieldFocus()
        }
    }
}
```

**Step 2: Build to verify**

Run: `cd /Users/chloe/builds/bee/macos-launcher && swift build 2>&1 | head -20`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel.swift
git commit -m "feat(macos): add detailEditingState with auto focus resignation"
```

---

## Task 3: Update LauncherViewModel+TaskDetail - Annotation Methods

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+TaskDetail.swift`

**Step 1: Update startAddingAnnotation() (~line 136)**

```swift
/// Begin adding an annotation.
func startAddingAnnotation() {
    guard selectedTask != nil else { return }
    annotationInput = ""
    detailEditingState = .addingAnnotation
}
```

**Step 2: Update cancelAddingAnnotation() (~line 143)**

```swift
/// Cancel adding an annotation (hides the input field).
func cancelAddingAnnotation() {
    annotationInput = ""
    detailEditingState = .none
}
```

**Step 3: Update submitAnnotation() success path (~line 183-185)**

Replace:
```swift
isAddingAnnotation = false
annotationInput = ""
```
With:
```swift
annotationInput = ""
detailEditingState = .none
```

**Step 4: Build to check for errors**

Run: `cd /Users/chloe/builds/bee/macos-launcher && swift build 2>&1 | head -40`
Expected: Errors about `isAddingAnnotation` being used elsewhere (this is expected, we'll fix views later)

**Step 5: Commit work in progress**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+TaskDetail.swift
git commit -m "wip(macos): update annotation methods to use detailEditingState"
```

---

## Task 4: Update LauncherViewModel+TaskDetail - Task Name Methods

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+TaskDetail.swift`

**Step 1: Update startEditingTaskName() (~line 199)**

```swift
/// Begin editing the task name.
func startEditingTaskName() {
    guard let task = selectedTask else { return }
    taskNameEditInput = task.summary
    detailEditingState = .editingTaskName
}
```

**Step 2: Update cancelEditingTaskName() (~line 205)**

```swift
/// Cancel editing the task name.
func cancelEditingTaskName() {
    taskNameEditInput = ""
    detailEditingState = .none
}
```

**Step 3: Update submitTaskNameEdit() success path (~line 244-245)**

Replace:
```swift
isEditingTaskName = false
taskNameEditInput = ""
```
With:
```swift
taskNameEditInput = ""
detailEditingState = .none
```

**Step 4: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+TaskDetail.swift
git commit -m "wip(macos): update task name methods to use detailEditingState"
```

---

## Task 5: Update LauncherViewModel+TaskDetail - Project Methods

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+TaskDetail.swift`

**Step 1: Update startEditingProject() (~line 275)**

```swift
/// Begin editing the project field.
func startEditingProject() {
    guard let task = selectedTask else { return }
    projectEditInput = task.project ?? ""
    detailEditingState = .editingProject
}
```

**Step 2: Update cancelEditingProject() (~line 281)**

```swift
/// Cancel editing the project.
func cancelEditingProject() {
    projectEditInput = ""
    detailEditingState = .none
}
```

**Step 3: Update submitProjectEdit() success path (~line 342-343)**

Replace `isEditingProject = false` and clear input with:
```swift
projectEditInput = ""
detailEditingState = .none
```

**Step 4: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+TaskDetail.swift
git commit -m "wip(macos): update project methods to use detailEditingState"
```

---

## Task 6: Update LauncherViewModel+TaskDetail - Annotation Edit Methods

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+TaskDetail.swift`

**Step 1: Update startEditingAnnotation() (~line 395)**

```swift
/// Begin editing an existing annotation by its ID.
func startEditingAnnotation(withId id: String) {
    guard let detail = taskDetailState.detail,
          let annotation = detail.annotations.first(where: { $0.id == id })
    else { return }

    annotationEditInput = annotation.value
    detailEditingState = .editingAnnotation(id: id)
}
```

**Step 2: Update cancelEditingAnnotation() (~line 399)**

```swift
/// Cancel editing an annotation.
func cancelEditingAnnotation() {
    annotationEditInput = ""
    detailEditingState = .none
}
```

**Step 3: Update submitAnnotationEdit() success path (~line 467-468)**

Replace `editingAnnotationId = nil` with `detailEditingState = .none`

**Step 4: Update deleteAnnotation() (~line 487) if it clears editingAnnotationId**

Replace any `editingAnnotationId = nil` with `detailEditingState = .none`

**Step 5: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+TaskDetail.swift
git commit -m "wip(macos): update annotation edit methods to use detailEditingState"
```

---

## Task 7: Update LauncherViewModel+Tags

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+Tags.swift`

**Step 1: Update startEditingTag() (~line 28)**

```swift
/// Edit a tag at the given index.
func startEditingTag(at index: Int) {
    guard let task = selectedTask, index < task.tags.count else { return }
    let oldTag = task.tags[index]
    removeTag(oldTag)
    tagAddQuery = oldTag
    selectedTagIndex = nil
    detailEditingState = .addingTag
}
```

**Step 2: Update startAddingTag() (~line 38)**

```swift
/// Begin adding a new tag (shows the CompletionField).
func startAddingTag() {
    tagAddQuery = ""
    selectedTagIndex = nil
    detailEditingState = .addingTag
}
```

**Step 3: Update cancelAddingTag() (~line 46)**

```swift
/// Cancel adding a tag (hides the CompletionField).
func cancelAddingTag() {
    tagAddQuery = ""
    detailEditingState = .none
}
```

**Step 4: Update addTag() success path (~line 90-91)**

Replace:
```swift
isAddingTag = false
tagAddQuery = ""
```
With:
```swift
tagAddQuery = ""
detailEditingState = .none
```

**Step 5: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+Tags.swift
git commit -m "wip(macos): update tag methods to use detailEditingState"
```

---

## Task 8: Update LauncherViewModel+DueDate

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+DueDate.swift`

**Step 1: Update startEditingDueDate() (~line 11)**

Replace `isEditingDueDate = true` with `detailEditingState = .editingDueDate`

**Step 2: Update cancelEditingDueDate() (~line 33)**

```swift
/// Cancel editing the due date.
func cancelEditingDueDate() {
    detailEditingState = .none
}
```

**Step 3: Update submitDueDateEdit() success path (~line 70)**

Replace `isEditingDueDate = false` with `detailEditingState = .none`

**Step 4: Update clearDueDate() success path (~line 114)**

Replace `isEditingDueDate = false` with `detailEditingState = .none`

**Step 5: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+DueDate.swift
git commit -m "wip(macos): update due date methods to use detailEditingState"
```

---

## Task 9: Update LauncherViewModel+PlannedDate

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+PlannedDate.swift`

**Step 1: Update startEditingPlannedDate() (~line 11)**

Replace `isEditingPlannedDate = true` with `detailEditingState = .editingPlannedDate`

**Step 2: Update cancelEditingPlannedDate() (~line 33)**

```swift
/// Cancel editing the planned date.
func cancelEditingPlannedDate() {
    detailEditingState = .none
}
```

**Step 3: Update submitPlannedDateEdit() success path (~line 69)**

Replace `isEditingPlannedDate = false` with `detailEditingState = .none`

**Step 4: Update clearPlannedDate() success path (~line 113)**

Replace `isEditingPlannedDate = false` with `detailEditingState = .none`

**Step 5: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+PlannedDate.swift
git commit -m "wip(macos): update planned date methods to use detailEditingState"
```

---

## Task 10: Update LauncherViewModel+ImportantLinks

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+ImportantLinks.swift`

**Step 1: Update startAddingImportantLink() (~line 7)**

```swift
/// Start adding an important link (shows the form).
func startAddingImportantLink() {
    importantLinkUrlInput = ""
    importantLinkTitleInput = ""
    detailEditingState = .addingImportantLink
}
```

**Step 2: Update cancelAddingImportantLink() (~line 13)**

```swift
/// Cancel adding an important link (hides the form).
func cancelAddingImportantLink() {
    importantLinkUrlInput = ""
    importantLinkTitleInput = ""
    detailEditingState = .none
}
```

**Step 3: Update submitImportantLink() success path (~line 59-61)**

Replace:
```swift
isAddingImportantLink = false
importantLinkUrlInput = ""
importantLinkTitleInput = ""
```
With:
```swift
importantLinkUrlInput = ""
importantLinkTitleInput = ""
detailEditingState = .none
```

**Step 4: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+ImportantLinks.swift
git commit -m "wip(macos): update important links methods to use detailEditingState"
```

---

## Task 11: Update LauncherViewModel+KeyboardHandling - Escape Handler

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+KeyboardHandling.swift:50-79`

**Step 1: Replace handleEscapeForEditingStates() with exhaustive switch**

```swift
/// Handle escape for various editing states in detail view.
/// Returns true if an editing state was active and cancelled.
private func handleEscapeForEditingStates() -> Bool {
    if showingSaveReportSheet {
        showingSaveReportSheet = false
        return true
    }

    switch detailEditingState {
    case .none:
        return false
    case .addingAnnotation:
        annotationInput = ""
        detailEditingState = .none
        return true
    case .editingAnnotation:
        annotationEditInput = ""
        detailEditingState = .none
        return true
    case .editingTaskName:
        taskNameEditInput = ""
        detailEditingState = .none
        return true
    case .editingProject:
        projectEditInput = ""
        detailEditingState = .none
        return true
    case .addingTag:
        tagAddQuery = ""
        detailEditingState = .none
        return true
    case .editingDueDate:
        detailEditingState = .none
        return true
    case .editingPlannedDate:
        detailEditingState = .none
        return true
    case .addingImportantLink:
        importantLinkUrlInput = ""
        importantLinkTitleInput = ""
        detailEditingState = .none
        return true
    }
}
```

**Step 2: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+KeyboardHandling.swift
git commit -m "wip(macos): update escape handler to use exhaustive switch on detailEditingState"
```

---

## Task 12: Remove Old Flag Declarations from LauncherViewModel

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel.swift:90-161`

**Step 1: Remove these @Published property declarations**

Delete (keep the input field vars, only remove the state flags):
- `@Published var isAddingAnnotation: Bool = false`
- `@Published var isEditingTaskName: Bool = false`
- `@Published var editingAnnotationId: String?`
- `@Published var isEditingProject: Bool = false`
- `@Published var isEditingDueDate: Bool = false`
- `@Published var isEditingPlannedDate: Bool = false`
- `@Published var isAddingTag: Bool = false`
- `@Published var isAddingImportantLink: Bool = false`

**Step 2: Build to see all remaining usages**

Run: `cd /Users/chloe/builds/bee/macos-launcher && swift build 2>&1`
Expected: Errors showing all view usages that need updating

**Step 3: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel.swift
git commit -m "wip(macos): remove old editing state flag declarations"
```

---

## Task 13: Simplify CombineLatest Publisher

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel.swift:330-339`

**Step 1: Find the CombineLatest4 publisher for isEditing**

Search for `CombineLatest4` or `isEditingPublisher`

**Step 2: Replace with simple map on detailEditingState**

```swift
let isEditingPublisher = $detailEditingState.map { $0.isEditing }
```

**Step 3: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel.swift
git commit -m "wip(macos): simplify isEditingPublisher to use single enum"
```

---

## Task 14: Update TaskDetailView Properties

**Files:**
- Modify: `Sources/LauncherApp/Views/TaskDetailView.swift:19-180`

**Step 1: Remove individual flag properties**

Delete these property declarations:
```swift
var isAddingAnnotation: Bool
var isEditingTaskName: Bool
var editingAnnotationId: String?
var isEditingProject: Bool
var isEditingDueDate: Bool
var isEditingPlannedDate: Bool
var isAddingTag: Bool
var isAddingImportantLink: Bool
```

**Step 2: Add single editingState property**

```swift
var editingState: DetailEditingState
```

**Step 3: Commit**

```bash
git add Sources/LauncherApp/Views/TaskDetailView.swift
git commit -m "wip(macos): replace individual flags with editingState in TaskDetailView"
```

---

## Task 15: Update TaskDetailView Conditionals with Switch

**Files:**
- Modify: `Sources/LauncherApp/Views/TaskDetailView.swift`

**Step 1: Update task name section (~line 279)**

Replace `if isEditingTaskName {` with:
```swift
switch editingState {
case .editingTaskName:
    ExpandingTextEditor(text: $taskNameEditInput, ...)
case .none, .addingAnnotation, .editingAnnotation, .editingProject,
     .addingTag, .editingDueDate, .editingPlannedDate, .addingImportantLink:
    Text(task.summary)
        .onTapGesture { onStartEditingTaskName() }
}
```

**Step 2: Update annotation input section (~line 465)**

Replace `if isAddingAnnotation {` with:
```swift
switch editingState {
case .addingAnnotation:
    ExpandingTextEditor(text: $annotationInput, ...)
case .none, .editingTaskName, .editingAnnotation, .editingProject,
     .addingTag, .editingDueDate, .editingPlannedDate, .addingImportantLink:
    EmptyView()
}
```

**Step 3: Update empty annotation placeholder (~line 477)**

Replace `if annotations.isEmpty, !isAddingAnnotation {` with:
```swift
switch editingState {
case .addingAnnotation:
    EmptyView()  // Input field is showing
case .none, .editingTaskName, .editingAnnotation, .editingProject,
     .addingTag, .editingDueDate, .editingPlannedDate, .addingImportantLink:
    if annotations.isEmpty {
        Text("—")
    }
}
```

**Step 4: Update annotation row editing (~line 483)**

Replace `if editingAnnotationId == annotation.id {` with:
```swift
switch editingState {
case .editingAnnotation(let id) where id == annotation.id:
    ExpandingTextEditor(text: $annotationEditInput, ...)
case .editingAnnotation, .none, .addingAnnotation, .editingTaskName,
     .editingProject, .addingTag, .editingDueDate, .editingPlannedDate,
     .addingImportantLink:
    EditableTimelineRow(...)
}
```

**Step 5: Commit**

```bash
git add Sources/LauncherApp/Views/TaskDetailView.swift
git commit -m "wip(macos): update TaskDetailView conditionals to use exhaustive switch"
```

---

## Task 16: Update TaskDetailView Child Component Calls

**Files:**
- Modify: `Sources/LauncherApp/Views/TaskDetailView.swift`

**Step 1: Update EditableTagsRow call (~line 377)**

Change from passing `isAddingTag: isAddingTag` to `editingState: editingState`

**Step 2: Update EditableDueDateRow call for due date (~line 402)**

Pass `editingState: editingState, editingCase: .editingDueDate`

**Step 3: Update EditableDueDateRow call for planned date (~line 417)**

Pass `editingState: editingState, editingCase: .editingPlannedDate`

**Step 4: Update ImportantLinksSection call (~line 538)**

Change from passing `isAdding: isAddingImportantLink` to `editingState: editingState`

**Step 5: Update EditableProjectRow call (~line 645)**

Change from passing `isEditing: isEditingProject` to `editingState: editingState`

**Step 6: Commit**

```bash
git add Sources/LauncherApp/Views/TaskDetailView.swift
git commit -m "wip(macos): update child component calls to pass editingState"
```

---

## Task 17: Update ContentView Bindings

**Files:**
- Modify: `Sources/LauncherApp/Views/ContentView.swift:49-212`

**Step 1: Replace all individual flag bindings with single editingState**

In the TaskDetailView instantiation, replace:
```swift
isAddingAnnotation: viewModel.isAddingAnnotation,
isEditingTaskName: viewModel.isEditingTaskName,
editingAnnotationId: viewModel.editingAnnotationId,
// ... etc
```
With:
```swift
editingState: viewModel.detailEditingState,
```

**Step 2: Update click-away logic (~line 230)**

Replace:
```swift
if viewModel.isAddingImportantLink,
   viewModel.importantLinkUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    viewModel.cancelAddingImportantLink()
}
```
With:
```swift
switch viewModel.detailEditingState {
case .addingImportantLink:
    if viewModel.importantLinkUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        viewModel.detailEditingState = .none
    }
case .none, .addingAnnotation, .editingAnnotation, .editingTaskName,
     .editingProject, .addingTag, .editingDueDate, .editingPlannedDate:
    break
}
```

**Step 3: Commit**

```bash
git add Sources/LauncherApp/Views/ContentView.swift
git commit -m "wip(macos): update ContentView to pass single editingState"
```

---

## Task 18: Update EditableProjectRow Component

**Files:**
- Modify: `Sources/LauncherApp/Views/Components/EditableProjectRow.swift`

**Step 1: Change property from Bool to enum**

Replace:
```swift
var isEditing: Bool
```
With:
```swift
var editingState: DetailEditingState
```

**Step 2: Update conditional with exhaustive switch**

Replace `if isEditing {` with:
```swift
switch editingState {
case .editingProject:
    // CompletionField for editing
case .none, .addingAnnotation, .editingAnnotation, .editingTaskName,
     .addingTag, .editingDueDate, .editingPlannedDate, .addingImportantLink:
    // Display view
}
```

**Step 3: Update preview providers**

**Step 4: Commit**

```bash
git add Sources/LauncherApp/Views/Components/EditableProjectRow.swift
git commit -m "wip(macos): update EditableProjectRow to use exhaustive switch"
```

---

## Task 19: Update EditableDueDateRow Component

**Files:**
- Modify: `Sources/LauncherApp/Views/Components/EditableDueDateRow.swift`

**Step 1: Change properties**

Replace:
```swift
var isEditing: Bool
```
With:
```swift
var editingState: DetailEditingState
var editingCase: DetailEditingState  // .editingDueDate or .editingPlannedDate
```

**Step 2: Update conditional with tuple switch**

Replace `if isEditing {` with:
```swift
switch (editingState, editingCase) {
case (.editingDueDate, .editingDueDate),
     (.editingPlannedDate, .editingPlannedDate):
    editingView
case (.none, _), (.addingAnnotation, _), (.editingAnnotation, _),
     (.editingTaskName, _), (.editingProject, _), (.addingTag, _),
     (.editingDueDate, _), (.editingPlannedDate, _), (.addingImportantLink, _):
    displayView
}
```

**Step 3: Update preview providers**

**Step 4: Commit**

```bash
git add Sources/LauncherApp/Views/Components/EditableDueDateRow.swift
git commit -m "wip(macos): update EditableDueDateRow to use exhaustive switch"
```

---

## Task 20: Update EditableTagsRow Component

**Files:**
- Modify: `Sources/LauncherApp/Views/Components/EditableTagsRow.swift`

**Step 1: Change property**

Replace:
```swift
var isAddingTag: Bool
```
With:
```swift
var editingState: DetailEditingState
```

**Step 2: Update add tag button conditional (~line 95)**

```swift
switch editingState {
case .addingTag:
    EmptyView()  // Hide button when adding
case .none, .addingAnnotation, .editingAnnotation, .editingTaskName,
     .editingProject, .editingDueDate, .editingPlannedDate, .addingImportantLink:
    addTagButton
}
```

**Step 3: Update CompletionField conditional (~line 108)**

```swift
switch editingState {
case .addingTag:
    CompletionField(text: $tagAddQuery, ...)
case .none, .addingAnnotation, .editingAnnotation, .editingTaskName,
     .editingProject, .editingDueDate, .editingPlannedDate, .addingImportantLink:
    EmptyView()
}
```

**Step 4: Update keyboard handler guard (~line 169)**

```swift
switch editingState {
case .addingTag:
    return .ignored  // Let CompletionField handle it
case .none, .addingAnnotation, .editingAnnotation, .editingTaskName,
     .editingProject, .editingDueDate, .editingPlannedDate, .addingImportantLink:
    // Handle tag navigation keys...
}
```

**Step 5: Update preview providers (~lines 251, 281)**

**Step 6: Commit**

```bash
git add Sources/LauncherApp/Views/Components/EditableTagsRow.swift
git commit -m "wip(macos): update EditableTagsRow to use exhaustive switch"
```

---

## Task 21: Update ImportantLinksSection Component

**Files:**
- Modify: `Sources/LauncherApp/Views/Components/ImportantLinksSection.swift`

**Step 1: Change property**

Replace:
```swift
var isAdding: Bool
```
With:
```swift
var editingState: DetailEditingState
```

**Step 2: Update conditional (~line 57)**

```swift
switch editingState {
case .addingImportantLink:
    addLinkForm
case .none, .addingAnnotation, .editingAnnotation, .editingTaskName,
     .editingProject, .addingTag, .editingDueDate, .editingPlannedDate:
    addLinkButton
}
```

**Step 3: Update preview providers**

**Step 4: Commit**

```bash
git add Sources/LauncherApp/Views/Components/ImportantLinksSection.swift
git commit -m "wip(macos): update ImportantLinksSection to use exhaustive switch"
```

---

## Task 22: Update LauncherViewModel+DetailFocus

**Files:**
- Modify: `Sources/LauncherApp/ViewModels/LauncherViewModel+DetailFocus.swift:30,56`

**Step 1: Update buildDetailFocusableItems() conditionals**

Replace `if !isAddingTag {` (~line 30) with:
```swift
switch detailEditingState {
case .addingTag:
    break  // Don't include add tag button when adding
case .none, .addingAnnotation, .editingAnnotation, .editingTaskName,
     .editingProject, .editingDueDate, .editingPlannedDate, .addingImportantLink:
    items.append(.addTagButton)
}
```

Replace `if !isAddingImportantLink {` (~line 56) with:
```swift
switch detailEditingState {
case .addingImportantLink:
    break  // Don't include add link button when adding
case .none, .addingAnnotation, .editingAnnotation, .editingTaskName,
     .editingProject, .addingTag, .editingDueDate, .editingPlannedDate:
    items.append(.addImportantLinkButton)
}
```

**Step 2: Commit**

```bash
git add Sources/LauncherApp/ViewModels/LauncherViewModel+DetailFocus.swift
git commit -m "wip(macos): update DetailFocus to use exhaustive switch"
```

---

## Task 23: Final Build and Fix Any Remaining Errors

**Files:**
- Various as needed

**Step 1: Build and collect errors**

Run: `cd /Users/chloe/builds/bee/macos-launcher && swift build 2>&1`

**Step 2: Fix any remaining usages of old flags**

Search for any remaining references to:
- `isAddingAnnotation`
- `isEditingTaskName`
- `editingAnnotationId`
- `isEditingProject`
- `isEditingDueDate`
- `isEditingPlannedDate`
- `isAddingTag`
- `isAddingImportantLink`

**Step 3: Ensure all switches are exhaustive (no default cases)**

**Step 4: Build succeeds**

Run: `cd /Users/chloe/builds/bee/macos-launcher && swift build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(macos): complete migration to DetailEditingState enum"
```

---

## Task 24: Squash WIP Commits

**Step 1: Interactive rebase to squash WIP commits**

```bash
git rebase -i HEAD~23
```

Mark all `wip:` commits as `squash` or `fixup` except the first one.

**Step 2: Final commit message**

```
feat(macos): replace editing state flags with DetailEditingState enum

- Add DetailEditingState enum with all 8 editing cases
- Use didSet to automatically resign text field focus on cancel
- Enforce mutual exclusivity (only one editing state at a time)
- Use exhaustive switch statements (no default) for compile-time safety
- Simplify CombineLatest4 publisher to single map
- Fix bugs: escape now handles planned date and important links

BREAKING CHANGE: Views now receive editingState enum instead of individual booleans
```

---

## Verification

1. **Build:** `swift build` succeeds
2. **Manual testing for all 8 editing states:**
   - `a` → add annotation → Escape → vim nav works
   - Click task name → Escape → vim nav works
   - Click annotation → Escape → vim nav works
   - Click project → Escape → vim nav works
   - `t` → add tag → Escape → vim nav works
   - Click due date → Escape → vim nav works
   - Click planned date → Escape → vim nav works (**was broken**)
   - Add important link → Escape → vim nav works (**was broken**)
3. **Mutual exclusivity:** Starting one edit cancels any other active edit
4. **Compile-time safety:** Try adding a dummy case to enum → verify compiler errors appear
