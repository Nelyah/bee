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
        textView.textColor = CatppuccinTheme.textNS
        textView.insertionPointColor = CatppuccinTheme.textNS
        textView.textContainerInset = NSSize(width: 0, height: 2)
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
        .foregroundColor: CatppuccinTheme.overlay0NS
    ]
}

final class KeyHandlingTextView: NSTextView {
    private enum KeyCode {
        static let space: UInt16 = 49
        static let tab: UInt16 = 48
        static let arrowUp: UInt16 = 126
        static let arrowDown: UInt16 = 125
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
    }

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

    /// Handle key presses for navigation and submit.
    override func keyDown(with event: NSEvent) {
        // Ctrl-Space: Toggle completion menu
        if event.modifierFlags.contains(.control),
           event.keyCode == KeyCode.space {
            onToggleMenu?()
            return
        }

        // Cmd-I: Alternate toggle for completion menu
        if event.modifierFlags.contains(.command),
           !event.modifierFlags.contains(.control),
           !event.modifierFlags.contains(.option),
           event.charactersIgnoringModifiers?.lowercased() == "i" {
            onToggleMenu?()
            return
        }

        // Tab: Accept ghost text or open menu
        if event.keyCode == KeyCode.tab {
            onAcceptGhost?()
            return
        }

        // When completion menu is open, handle navigation differently
        if showCompletionMenu {
            // Arrow keys navigate menu
            if event.keyCode == KeyCode.arrowUp {
                onMenuNavigation?(-1)
                return
            }
            if event.keyCode == KeyCode.arrowDown {
                onMenuNavigation?(1)
                return
            }
            // Ctrl-P/N also navigate menu
            if event.modifierFlags.contains(.control) {
                if event.charactersIgnoringModifiers == "p" {
                    onMenuNavigation?(-1)
                    return
                }
                if event.charactersIgnoringModifiers == "n" {
                    onMenuNavigation?(1)
                    return
                }
            }
            // Enter accepts completion when menu is open
            if isSubmitEvent(event) {
                onAcceptCompletion?()
                return
            }
            // Escape closes menu
            if isEscapeEvent(event) {
                onEscape?()
                return
            }
        }

        // Readline-style word navigation: Alt-F (forward), Alt-B (backward)
        if event.modifierFlags.contains(.option) {
            if event.charactersIgnoringModifiers == "f" {
                moveWordForward()
                return
            }
            if event.charactersIgnoringModifiers == "b" {
                moveWordBackward()
                return
            }
        }

        // Ctrl-W: Delete previous word (readline binding)
        if event.modifierFlags.contains(.control),
           event.charactersIgnoringModifiers == "w" {
            deleteWordBackward(nil)
            return
        }

        // Normal task list navigation (when menu is closed)
        if !showCompletionMenu, let delta = selectionDelta(for: event) {
            onMoveSelection?(delta)
            return
        }

        if isSubmitEvent(event) {
            onSubmit?()
            return
        }

        if isEscapeEvent(event) {
            onEscape?()
            return
        }

        super.keyDown(with: event)
    }

    /// Draw ghost text after the current input without mutating the backing string.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ghost = ghostText, !ghost.isEmpty else { return }
        guard let layoutManager = layoutManager, let textContainer = textContainer else { return }

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

    /// Return selection delta for keyboard navigation shortcuts.
    private func selectionDelta(for event: NSEvent) -> Int? {
        if event.modifierFlags.contains(.control) {
            if event.charactersIgnoringModifiers == "p" {
                return -1
            }
            if event.charactersIgnoringModifiers == "n" {
                return 1
            }
        }

        switch event.keyCode {
        case KeyCode.arrowUp:
            return -1
        case KeyCode.arrowDown:
            return 1
        default:
            return nil
        }
    }

    /// Return true when the event should submit the current input.
    private func isSubmitEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            return true
        default:
            return false
        }
    }

    /// Return true when the event should close the detail view.
    private func isEscapeEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case KeyCode.escape:
            return true
        default:
            return false
        }
    }
}
