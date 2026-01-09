import AppKit

/// Input event data for key handling decisions.
struct KeyInput {
    let keyCode: UInt16
    let charactersIgnoringModifiers: String?
    let modifierFlags: NSEvent.ModifierFlags

    init(event: NSEvent) {
        keyCode = event.keyCode
        charactersIgnoringModifiers = event.charactersIgnoringModifiers
        modifierFlags = event.modifierFlags
    }

    init(keyCode: UInt16, charactersIgnoringModifiers: String?, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.modifierFlags = modifierFlags
    }
}

/// Actions that can be triggered in insert mode (text editing).
enum KeyHandlingAction: Equatable {
    case toggleMenu
    case acceptGhost
    case menuNavigate(Int)
    case acceptCompletion
    case escape
    case moveWordForward
    case moveWordBackward
    case deleteWordBackward
    case moveSelection(Int)
    case submit
}

/// Actions that can be triggered in normal mode (vim-like navigation).
enum NormalModeAction: Equatable {
    case enterInsertMode
    case moveSelection(Int)
    case selectFirst
    case selectLast
    case activatePrimary
    case toggleGroupCollapse
    case toggleWithTab // Context-aware: collapse header or expand task
    case toggleMultiSelect // Space on task row toggles multi-selection
    case openCommandPalette
}

/// Actions that can be triggered in detail mode (keyboard navigation).
enum DetailModeAction: Equatable {
    case navigate(NavigationDirection) // hjkl - coordinate-based navigation
    case openFocused // o/Enter - open in browser or edit
    case copyFocused // y - copy to clipboard (or confirm delete if attachment is confirming)
    case deleteFocused // x - delete focused item (tags, attachments)
    case selectFirst // g - jump to first
    case selectLast // G - jump to last
    case addAnnotation // a - add annotation
    case addTag // t - add new tag
    case quickLookFocused // Space - Quick Look preview (attachments)
    case cancelDelete // n - cancel pending delete (attachments only)
}
