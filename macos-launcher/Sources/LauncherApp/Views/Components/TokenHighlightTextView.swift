import AppKit
import SwiftUI

struct TokenHighlightTextView: NSViewRepresentable {
    @Binding var text: String
    let tokens: [TokenSpan]
    let actionName: String
    let isFocused: Bool
    let onSubmit: () -> Void
    let onEscape: () -> Void
    let onMoveSelection: (Int) -> Void

    /// Create the underlying AppKit view.
    func makeNSView(context: Context) -> NSScrollView {
        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
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

        let selectedRange = textView.selectedRange()
        context.coordinator.isUpdating = true
        let attributed = highlightedText(text: text, tokens: tokens, actionName: actionName)
        textView.textStorage?.setAttributedString(attributed)
        textView.setSelectedRange(selectedRange)
        context.coordinator.isUpdating = false

        if isFocused, let window = textView.window, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }
    }

    /// Build the coordinator for text updates.
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var isUpdating = false

        init(text: Binding<String>) {
            _text = text
        }

        /// Propagate text changes back to SwiftUI.
        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

final class KeyHandlingTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?
    var onMoveSelection: ((Int) -> Void)?

    /// Handle key presses for navigation and submit.
    override func keyDown(with event: NSEvent) {
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

        if let delta = selectionDelta(for: event) {
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
        case 126:
            return -1
        case 125:
            return 1
        default:
            return nil
        }
    }

    /// Return true when the event should submit the current input.
    private func isSubmitEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 36, 76:
            return true
        default:
            return false
        }
    }

    /// Return true when the event should close the detail view.
    private func isEscapeEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:
            return true
        default:
            return false
        }
    }
}
