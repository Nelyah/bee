import AppKit

/// Return styling attributes used for rendering ghost text.
func ghostTextAttributes(font: NSFont?) -> [NSAttributedString.Key: Any] {
    [
        .font: font ?? NSFont.systemFont(ofSize: 18, weight: .medium),
        .foregroundColor: ThemeManager.current.overlay0NS,
    ]
}

/// Custom NSTextView subclass that intercepts key events for custom handling.
///
/// Handles:
/// - Navigation keys (arrow keys, vim-style j/k)
/// - Word movement (Option+f/b, Ctrl+w)
/// - Completion menu navigation
/// - Ghost text rendering (inline autocomplete preview)
/// - Submit (Enter) and escape
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
