import Foundation

/// Actions triggered by clicking hint bar items.
/// Use `.none` for informational hints (e.g., "hjkl Navigate").
enum HintAction: Equatable {
    // Navigation
    case escape
    case enterInsertMode

    // List mode
    case toggleFold
    case openTask

    // Detail mode
    case openFocusedItem
    case addAnnotation
    case addTag
    case linkTask
    case copyFocused
    case deleteTag
    case saveEdit

    // Global
    case openCommandPalette

    // Completion
    case acceptSuggestion

    // Non-clickable (informational only)
    case none
}

struct BottomHint: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let label: String
    let action: HintAction

    /// Create from keybinding (auto-generates display key)
    init(keybinding: Keybinding, label: String) {
        key = keybinding.displayKey
        self.label = label
        action = keybinding.action
    }

    /// Manual init for special cases (e.g., "hjkl Navigate")
    init(key: String, label: String, action: HintAction = .none) {
        self.key = key
        self.label = label
        self.action = action
    }

    /// Whether this hint should respond to clicks.
    var isClickable: Bool { action != .none }
}
