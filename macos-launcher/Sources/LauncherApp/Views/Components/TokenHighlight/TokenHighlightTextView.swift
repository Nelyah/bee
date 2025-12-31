import AppKit
import SwiftUI

/// SwiftUI wrapper for an NSTextView that displays syntax-highlighted tokens.
///
/// This view bridges AppKit's NSTextView with SwiftUI, providing:
/// - Token-based syntax highlighting
/// - Ghost text (inline autocomplete preview)
/// - Custom keyboard handling (vim-style navigation, completion menu)
/// - Focus management between insert and normal modes
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
            // Resign first responder when not focused (normal mode or command palette open)
            window.makeFirstResponder(nil)
        }
    }

    /// Build the coordinator for text updates.
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCursorChange: onCursorChange)
    }

    /// Coordinator that bridges NSTextViewDelegate callbacks to SwiftUI bindings.
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
