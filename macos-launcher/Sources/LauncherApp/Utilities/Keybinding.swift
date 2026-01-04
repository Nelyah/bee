import AppKit

/// A keybinding definition with key code, modifiers, and auto-generated display string.
/// Use this to define keybindings once and derive both matching logic and display hints.
struct Keybinding: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let action: HintAction

    /// Auto-generated display string (e.g., "⌘K", "⌃P", "Tab").
    var displayKey: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keySymbol)
        return parts.joined()
    }

    /// Human-readable key symbol.
    private var keySymbol: String {
        switch keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            // Use "↩" only with modifiers (e.g., "⌘↩"), otherwise "Enter"
            return modifiers.isEmpty ? "Enter" : "↩"
        case KeyCode.tab:
            return "Tab"
        case KeyCode.escape:
            return "Esc"
        case KeyCode.space:
            return "Space"
        case KeyCode.arrowUp:
            return "↑"
        case KeyCode.arrowDown:
            return "↓"
        default:
            // Convert key code to character
            // Use uppercase with modifiers (e.g., "⌘K"), lowercase without (e.g., "i" for insert)
            guard let char = KeyCode.character(for: keyCode) else { return "?" }
            return modifiers.isEmpty ? char : char.uppercased()
        }
    }

    /// Check if this keybinding matches the given input.
    func matches(_ input: KeyInput) -> Bool {
        // Compare key codes
        guard input.keyCode == keyCode else { return false }

        // Compare modifiers (ignoring caps lock and function keys)
        let relevantFlags: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        let inputMods = input.modifierFlags.intersection(relevantFlags)
        let expectedMods = modifiers.intersection(relevantFlags)
        return inputMods == expectedMods
    }
}

// MARK: - KeyCode Character Mapping

extension KeyCode {
    /// Convert a key code to its character representation.
    static func character(for keyCode: UInt16) -> String? {
        switch keyCode {
        case keyA: "a"
        case keyG: "g"
        case keyH: "h"
        case keyI: "i"
        case keyJ: "j"
        case keyK: "k"
        case keyL: "l"
        case keyN: "n"
        case keyO: "o"
        case keyP: "p"
        case keyT: "t"
        case keyX: "x"
        case keyY: "y"
        default: nil
        }
    }
}

// MARK: - Keybinding Registry

/// Central registry of all keybindings in the app.
/// This is the single source of truth for keyboard shortcuts.
enum KeybindingRegistry {
    // MARK: - Global Actions

    static let escape = Keybinding(
        keyCode: KeyCode.escape,
        modifiers: [],
        action: .escape
    )

    static let commandPalette = Keybinding(
        keyCode: KeyCode.keyK,
        modifiers: .command,
        action: .openCommandPalette
    )

    // MARK: - List Mode

    static let enterInsertMode = Keybinding(
        keyCode: KeyCode.keyI,
        modifiers: [],
        action: .enterInsertMode
    )

    static let openTask = Keybinding(
        keyCode: KeyCode.returnKey,
        modifiers: [],
        action: .openTask
    )

    static let toggleFold = Keybinding(
        keyCode: KeyCode.tab,
        modifiers: [],
        action: .toggleFold
    )

    // MARK: - Detail Mode

    static let addAnnotation = Keybinding(
        keyCode: KeyCode.keyA,
        modifiers: [],
        action: .addAnnotation
    )

    static let addTag = Keybinding(
        keyCode: KeyCode.keyT,
        modifiers: [],
        action: .addTag
    )

    static let linkTask = Keybinding(
        keyCode: KeyCode.keyL,
        modifiers: .command,
        action: .linkTask
    )

    static let copyFocused = Keybinding(
        keyCode: KeyCode.keyY,
        modifiers: [],
        action: .copyFocused
    )

    static let deleteTag = Keybinding(
        keyCode: KeyCode.keyX,
        modifiers: [],
        action: .deleteTag
    )

    static let saveEdit = Keybinding(
        keyCode: KeyCode.returnKey,
        modifiers: .command,
        action: .saveEdit
    )

    static let openFocusedItem = Keybinding(
        keyCode: KeyCode.returnKey,
        modifiers: [],
        action: .openFocusedItem
    )
}
