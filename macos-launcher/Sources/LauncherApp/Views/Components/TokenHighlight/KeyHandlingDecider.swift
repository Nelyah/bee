import AppKit

/// Pure logic for deciding which action to take based on key input.
///
/// This enum contains no state - it's a collection of pure functions that map
/// keyboard input to actions based on the current context (insert vs normal mode,
/// completion menu visibility).
enum KeyHandlingDecider {
    /// Determines the action for a key press in insert mode.
    static func action(for input: KeyInput, showCompletionMenu: Bool) -> KeyHandlingAction? {
        if isToggleMenu(input) { return .toggleMenu }
        if input.keyCode == KeyCode.tab { return .acceptGhost }
        if showCompletionMenu, let action = menuAction(for: input) { return action }
        if let action = wordNavAction(for: input) { return action }
        if !showCompletionMenu, let delta = selectionDelta(for: input) { return .moveSelection(delta) }
        if isSubmit(input) { return .submit }
        if isEscape(input) { return .escape }
        return nil
    }

    private static func isToggleMenu(_ input: KeyInput) -> Bool {
        if input.modifierFlags.contains(.control), input.keyCode == KeyCode.space { return true }
        if input.modifierFlags.contains(.command),
           !input.modifierFlags.contains(.control),
           !input.modifierFlags.contains(.option),
           input.charactersIgnoringModifiers?.lowercased() == "i" { return true }
        return false
    }

    private static func menuAction(for input: KeyInput) -> KeyHandlingAction? {
        if let delta = menuNavigationDelta(for: input) { return .menuNavigate(delta) }
        if isSubmit(input) { return .acceptCompletion }
        if isEscape(input) { return .escape }
        return nil
    }

    private static func menuNavigationDelta(for input: KeyInput) -> Int? {
        if input.keyCode == KeyCode.arrowUp { return -1 }
        if input.keyCode == KeyCode.arrowDown { return 1 }
        if input.modifierFlags.contains(.control) {
            if input.charactersIgnoringModifiers == "p" { return -1 }
            if input.charactersIgnoringModifiers == "n" { return 1 }
        }
        return nil
    }

    private static func wordNavAction(for input: KeyInput) -> KeyHandlingAction? {
        if input.modifierFlags.contains(.option) {
            if input.charactersIgnoringModifiers == "f" { return .moveWordForward }
            if input.charactersIgnoringModifiers == "b" { return .moveWordBackward }
        }
        if input.modifierFlags.contains(.control),
           input.charactersIgnoringModifiers == "w" { return .deleteWordBackward }
        return nil
    }

    /// Determines the action for a key press in normal mode (vim-like).
    static func normalModeAction(for input: KeyInput) -> NormalModeAction? {
        if isOpenCommandPalette(input) { return .openCommandPalette }
        if let delta = normalModeControlDelta(input) { return .moveSelection(delta) }
        return normalModeKeyAction(input)
    }

    private static func isOpenCommandPalette(_ input: KeyInput) -> Bool {
        input.modifierFlags.contains(.command) &&
            !input.modifierFlags.contains(.control) &&
            !input.modifierFlags.contains(.option) &&
            input.keyCode == KeyCode.keyK
    }

    private static func normalModeControlDelta(_ input: KeyInput) -> Int? {
        guard input.modifierFlags.contains(.control) else { return nil }
        if input.charactersIgnoringModifiers == "n" { return 1 }
        if input.charactersIgnoringModifiers == "p" { return -1 }
        return nil
    }

    private static func normalModeKeyAction(_ input: KeyInput) -> NormalModeAction? {
        switch input.keyCode {
        case KeyCode.keyI:
            .enterInsertMode
        case KeyCode.keyJ:
            .moveSelection(1)
        case KeyCode.keyK:
            .moveSelection(-1)
        case KeyCode.keyG:
            input.modifierFlags.contains(.shift) ? .selectLast : .selectFirst
        case KeyCode.returnKey, KeyCode.keypadEnter:
            .activatePrimary
        case KeyCode.space:
            .toggleMultiSelect // Context-aware: collapse on headers, multi-select on tasks
        case KeyCode.tab:
            // Tab works for both: collapse headers or expand tasks (context decides)
            .toggleWithTab
        default:
            nil
        }
    }

    private static func selectionDelta(for input: KeyInput) -> Int? {
        if input.modifierFlags.contains(.control) {
            if input.charactersIgnoringModifiers == "p" {
                return -1
            }
            if input.charactersIgnoringModifiers == "n" {
                return 1
            }
        }

        switch input.keyCode {
        case KeyCode.arrowUp:
            return -1
        case KeyCode.arrowDown:
            return 1
        default:
            return nil
        }
    }

    private static func isSubmit(_ input: KeyInput) -> Bool {
        switch input.keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            true
        default:
            false
        }
    }

    private static func isEscape(_ input: KeyInput) -> Bool {
        input.keyCode == KeyCode.escape
    }

    // MARK: - Detail Mode

    /// Returns the detail mode action for the given input, if any.
    /// Used for vim-style navigation in the task detail view.
    static func detailModeAction(for input: KeyInput) -> DetailModeAction? {
        // Check for Ctrl+N/P first (vim muscle memory)
        if input.modifierFlags.contains(.control) {
            switch input.charactersIgnoringModifiers {
            case "n": return .navigate(.down)
            case "p": return .navigate(.up)
            default: break
            }
        }

        // Only allow shift modifier (for G), reject cmd/ctrl/option
        let hasDisallowedModifier = input.modifierFlags.contains(.command) ||
            input.modifierFlags.contains(.control) ||
            input.modifierFlags.contains(.option)

        guard !hasDisallowedModifier else { return nil }

        return detailModeKeyAction(input)
    }

    private static func detailModeKeyAction(_ input: KeyInput) -> DetailModeAction? {
        switch input.keyCode {
        case KeyCode.keyH:
            .navigate(.left)
        case KeyCode.keyJ:
            .navigate(.down)
        case KeyCode.keyK:
            .navigate(.up)
        case KeyCode.keyL:
            .navigate(.right) // NOTE: No longer opens links! Use 'o' or Enter to open.
        case KeyCode.keyO:
            .openFocused
        case KeyCode.returnKey, KeyCode.keypadEnter:
            .openFocused
        case KeyCode.keyY:
            .copyFocused
        case KeyCode.keyX:
            .deleteFocused
        case KeyCode.keyG:
            input.modifierFlags.contains(.shift) ? .selectLast : .selectFirst
        case KeyCode.keyA:
            .addAnnotation
        case KeyCode.keyT:
            .addTag
        case KeyCode.space:
            .quickLookFocused
        case KeyCode.keyN:
            .cancelDelete
        default:
            nil
        }
    }
}
