import Foundation

/// Represents the single active editing state in the detail view.
///
/// Only one editing state can be active at a time, enforcing mutual exclusivity
/// at the type level. This replaces the previous approach of 8 individual boolean
/// flags which could theoretically be in conflicting states.
///
/// ## State Transitions
///
/// - All `start*` methods (e.g., `startEditingTaskName()`) transition from `.none`
///   to the appropriate editing state
/// - All `cancel*` and `submit*` methods transition back to `.none`
/// - The `didSet` observer on `detailEditingState` automatically calls
///   `resignTextFieldFocus()` when transitioning to `.none`, restoring vim-style
///   keyboard navigation
///
/// ## Usage in Views
///
/// Views receive this enum and use pattern matching for conditionals:
/// ```swift
/// if editingState == .editingTaskName { ... }
/// if case let .editingAnnotation(id) = editingState, id == annotation.id { ... }
/// ```
///
/// Child components receive derived booleans for simplicity:
/// ```swift
/// isAddingTag: editingState == .addingTag
/// ```
enum DetailEditingState: Equatable {
    /// No editing state is active; vim-style keyboard navigation is enabled
    case none
    /// User is adding a new annotation via the input field
    case addingAnnotation
    /// User is editing an existing annotation identified by its ID
    case editingAnnotation(id: String)
    /// User is editing the task name/summary
    case editingTaskName
    /// User is editing the project assignment
    case editingProject
    /// User is adding a new tag via the completion field
    case addingTag
    /// User is editing the due date via the date picker
    case editingDueDate
    /// User is editing the planned date via the date picker
    case editingPlannedDate
    /// User is adding a new important link via the URL/title form
    case addingImportantLink

    /// Returns `true` if any editing state is active.
    /// Used by the Combine publisher to derive `isEditing` for the interaction context.
    var isEditing: Bool { self != .none }
}
