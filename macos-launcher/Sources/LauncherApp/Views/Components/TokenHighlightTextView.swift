import AppKit
import SwiftUI

struct TokenHighlightTextView: NSViewRepresentable {
    @Binding var text: String
    let tokens: [TokenSpan]
    let actionName: String
    let isFocused: Bool
    let ghostText: String?
    let cursorPosition: Int
    let showCompletionMenu: Bool
    let onSubmit: () -> Void
    let onEscape: () -> Void
    let onMoveSelection: (Int) -> Void
    let onCursorChange: (Int) -> Void
    let onToggleMenu: () -> Void
    let onAcceptGhost: () -> Void
    let onMenuNavigation: (Int) -> Void
    let onAcceptCompletion: () -> Void
    /// Returns whether the text view should take focus when clicked.
    let onRequestFocus: () -> Bool

    /// Create the underlying AppKit view.
    func makeNSView(context: Context) -> NSScrollView {
        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesAdaptiveColorMappingForDarkAppearance = false
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        textView.textColor = ThemeManager.current.textNS
        textView.insertionPointColor = ThemeManager.current.textNS
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.onSubmit = onSubmit
        textView.onEscape = onEscape
        textView.onMoveSelection = onMoveSelection
        textView.onCursorChange = onCursorChange
        textView.onToggleMenu = onToggleMenu
        textView.onAcceptGhost = onAcceptGhost
        textView.onMenuNavigation = onMenuNavigation
        textView.onAcceptCompletion = onAcceptCompletion
        textView.onRequestFocus = onRequestFocus

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        return scrollView
    }

    /// Update the AppKit view when state changes.
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? KeyHandlingTextView else { return }
        if context.coordinator.isUpdating {
            return
        }

        textView.showCompletionMenu = showCompletionMenu
        textView.ghostText = ghostText

        let selection = NSRange(location: min(cursorPosition, text.count), length: 0)
        context.coordinator.isUpdating = true
        let attributed = highlightedText(text: text, tokens: tokens, actionName: actionName)
        textView.textStorage?.setAttributedString(attributed)
        textView.setSelectedRange(selection)
        context.coordinator.isUpdating = false
        textView.needsDisplay = true

        if isFocused, let window = textView.window, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        } else if !isFocused, let window = textView.window, window.firstResponder === textView {
            // Resign first responder in normal mode
            window.makeFirstResponder(nil)
        }
    }

    /// Build the coordinator for text updates.
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCursorChange: onCursorChange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var isUpdating = false
        let onCursorChange: (Int) -> Void

        init(text: Binding<String>, onCursorChange: @escaping (Int) -> Void) {
            _text = text
            self.onCursorChange = onCursorChange
        }

        /// Propagate text changes back to SwiftUI.
        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }
            text = textView.string
            onCursorChange(textView.selectedRange().location)
        }

        /// Track cursor position changes.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }
            onCursorChange(textView.selectedRange().location)
        }
    }
}

/// Return styling attributes used for rendering ghost text.
func ghostTextAttributes(font: NSFont?) -> [NSAttributedString.Key: Any] {
    [
        .font: font ?? NSFont.systemFont(ofSize: 18, weight: .medium),
        .foregroundColor: ThemeManager.current.overlay0NS,
    ]
}

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

enum NormalModeAction: Equatable {
    case enterInsertMode
    case moveSelection(Int)
    case selectFirst
    case selectLast
    case activatePrimary
    case toggleGroupCollapse
    case toggleWithTab // Context-aware: collapse header or expand task
    case openCommandPalette
}

enum KeyHandlingDecider {
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
            return .enterInsertMode
        case KeyCode.keyJ:
            return .moveSelection(1)
        case KeyCode.keyK:
            return .moveSelection(-1)
        case KeyCode.keyG:
            return input.modifierFlags.contains(.shift) ? .selectLast : .selectFirst
        case KeyCode.returnKey, KeyCode.keypadEnter:
            return .activatePrimary
        case KeyCode.space:
            return .toggleGroupCollapse
        case KeyCode.tab:
            // Tab works for both: collapse headers or expand tasks (context decides)
            return .toggleWithTab
        default:
            return nil
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
}

final class KeyHandlingTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?
    var onMoveSelection: ((Int) -> Void)?
    var onCursorChange: ((Int) -> Void)?
    var onToggleMenu: (() -> Void)?
    var onAcceptGhost: (() -> Void)?
    var onMenuNavigation: ((Int) -> Void)?
    var onAcceptCompletion: (() -> Void)?
    var showCompletionMenu: Bool = false
    var ghostText: String?
    var onRequestFocus: (() -> Bool)?

    /// Handle key presses for navigation and submit.
    override func keyDown(with event: NSEvent) {
        if let action = KeyHandlingDecider.action(
            for: KeyInput(event: event),
            showCompletionMenu: showCompletionMenu
        ) {
            handleAction(action)
            return
        }

        super.keyDown(with: event)
    }

    /// Enter insert mode when the user clicks into the text view.
    override func mouseDown(with event: NSEvent) {
        let shouldFocus = onRequestFocus?() ?? true
        super.mouseDown(with: event)
        guard shouldFocus, let window else { return }
        if !NSApplication.shared.isActive {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        if !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
        }
        if window.firstResponder !== self {
            window.makeFirstResponder(self)
        }
    }

    /// Draw ghost text after the current input without mutating the backing string.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ghost = ghostText, !ghost.isEmpty else { return }
        guard let layoutManager, let textContainer else { return }

        let origin = NSPoint(x: textContainerInset.width, y: textContainerInset.height)
        let length = textStorage?.length ?? 0
        let drawPoint: NSPoint

        if length == 0 || layoutManager.numberOfGlyphs == 0 {
            drawPoint = origin
        } else {
            let lastGlyphIndex = max(layoutManager.numberOfGlyphs - 1, 0)
            let glyphRect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: lastGlyphIndex, length: 1),
                in: textContainer
            )
            let lineRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: lastGlyphIndex,
                effectiveRange: nil
            )
            drawPoint = NSPoint(x: origin.x + glyphRect.maxX, y: origin.y + lineRect.minY)
        }

        (ghost as NSString).draw(at: drawPoint, withAttributes: ghostTextAttributes(font: font))
    }

    /// Move cursor forward one word using NSTextView's built-in method.
    private func moveWordForward() {
        moveWordForward(nil)
    }

    /// Move cursor backward one word using NSTextView's built-in method.
    private func moveWordBackward() {
        moveWordBackward(nil)
    }

    private func handleAction(_ action: KeyHandlingAction) {
        switch action {
        case .toggleMenu:
            onToggleMenu?()
        case .acceptGhost:
            onAcceptGhost?()
        case let .menuNavigate(delta):
            onMenuNavigation?(delta)
        case .acceptCompletion:
            onAcceptCompletion?()
        case .escape:
            onEscape?()
        case .moveWordForward:
            moveWordForward()
        case .moveWordBackward:
            moveWordBackward()
        case .deleteWordBackward:
            deleteWordBackward(nil)
        case let .moveSelection(delta):
            onMoveSelection?(delta)
        case .submit:
            onSubmit?()
        }
    }
}
