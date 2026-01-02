import AppKit
import SwiftUI

/// A reusable text field with fuzzy-matched autocompletion.
///
/// Features:
/// - Fuzzy finding with highlighted matches
/// - Keyboard navigation (arrows, Ctrl+N/P)
/// - Escape to cancel
/// - Click outside to dismiss
/// - Current value shown greyed at top (non-selectable)
/// - Always positioned at topmost z-layer
struct CompletionField<Item: CompletableItem>: View {
    // MARK: - Inputs

    /// The text being edited.
    @Binding var text: String

    /// Placeholder text for the text field.
    let placeholder: String

    /// All available items for completion.
    let items: [Item]

    /// The current value (if editing an existing value).
    /// Will be shown greyed out at the top of the list.
    let currentValue: Item?

    // MARK: - Callbacks

    /// Called when the user presses Enter to submit.
    let onSubmit: () -> Void

    /// Called when the user cancels (Escape or click outside).
    let onCancel: () -> Void

    /// Called when the user selects an item from the completion menu.
    let onSelect: (Item) -> Void

    // MARK: - Styling

    /// The theme to use for the completion menu.
    let theme: CompletionTheme

    /// Minimum width for the completion menu.
    let minWidth: CGFloat

    /// Minimum height for the completion menu.
    let minHeight: CGFloat

    /// Maximum height for the completion menu.
    let maxHeight: CGFloat

    // MARK: - Internal State

    /// Currently selected index in the fuzzy matches.
    @State private var selectedIndex: Int = 0

    /// Fuzzy-matched and scored items.
    @State private var fuzzyMatches: [FuzzyMatchedItem<Item>] = []

    /// Whether the text field has focus.
    @FocusState private var isFocused: Bool

    /// Text field height (calculated dynamically).
    @State private var textFieldHeight: CGFloat = 32

    /// Mouse click monitor for outside-click detection.
    @State private var clickMonitor: Any?

    /// Keyboard monitor for Ctrl+N/P navigation.
    @State private var keyboardMonitor: Any?

    /// Bounds of the text field (for click detection).
    @State private var fieldBounds: CGRect = .zero

    /// Bounds of the completion menu (for click detection).
    @State private var menuBounds: CGRect = .zero

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: DesignTokens.TypeScale.body, weight: .regular, design: .monospaced))
                .foregroundColor(ThemeManager.current.text)
                .padding(.horizontal, DesignTokens.Spacing.small)
                .padding(.vertical, DesignTokens.Spacing.extraSmall)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: TextFieldHeightPreferenceKey.self, value: geometry.size.height)
                            .preference(key: TextFieldBoundsPreferenceKey.self, value: geometry.frame(in: .global))
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(ThemeManager.current.surface1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .stroke(ThemeManager.current.blue, lineWidth: 2)
                )
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                    selectAllText()
                    updateFuzzyMatches(query: text)
                    installKeyboardMonitor()
                }
                .onChange(of: text) { _, newValue in
                    updateFuzzyMatches(query: newValue)
                }
                .onPreferenceChange(TextFieldHeightPreferenceKey.self) { height in
                    textFieldHeight = max(height, 24)
                }
                .onPreferenceChange(TextFieldBoundsPreferenceKey.self) { bounds in
                    fieldBounds = bounds
                    installClickOutsideMonitor()
                }
                .onDisappear {
                    removeClickOutsideMonitor()
                    removeKeyboardMonitor()
                }
                .onSubmit {
                    onSubmit()
                }
                // Keyboard shortcuts
                .onKeyPress(.escape) {
                    onCancel()
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    selectPrevious()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    selectNext()
                    return .handled
                }
                .onKeyPress(.return) {
                    handleReturnKey()
                    return .handled
                }
        }
        .frame(height: textFieldHeight)
        // Completion menu overlay (does not affect parent layout)
        .overlay(alignment: .topLeading) {
            GeometryReader { proxy in
                if !fuzzyMatches.isEmpty {
                    CompletionMenuView(
                        matches: fuzzyMatches,
                        selectedIndex: selectedIndex,
                        currentValue: currentValue,
                        theme: theme,
                        onSelect: handleSelect
                    )
                    .frame(minWidth: minWidth, minHeight: minHeight, maxHeight: maxHeight)
                    .offset(y: proxy.size.height + DesignTokens.Spacing.extraSmall)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: MenuBoundsPreferenceKey.self,
                                value: geometry.frame(in: .global)
                            )
                        }
                    )
                    .onPreferenceChange(MenuBoundsPreferenceKey.self) { bounds in
                        menuBounds = bounds
                    }
                }
            }
        }
    }

    // MARK: - Fuzzy Matching Logic

    /// Updates the fuzzy matches based on the current query.
    private func updateFuzzyMatches(query: String) {
        let query = query.trimmingCharacters(in: .whitespaces)

        // Fuzzy filter + score
        var scored: [(item: Item, match: FuzzyMatch)] = items.compactMap { item in
            guard let match = FuzzyMatcher.match(query, in: item.displayValue) else {
                return nil
            }
            return (item, match)
        }

        // Sort by score descending (best matches first)
        scored.sort { $0.match.score > $1.match.score }

        fuzzyMatches = scored.map { FuzzyMatchedItem(item: $0.item, match: $0.match) }

        // Put current value at top (if present and matches)
        if let current = currentValue,
           let index = fuzzyMatches.firstIndex(where: { $0.item.id == current.id }) {
            let currentMatch = fuzzyMatches.remove(at: index)
            fuzzyMatches.insert(currentMatch, at: 0)
        }

        // Reset selection to first selectable item
        selectedIndex = findFirstSelectableIndex() ?? 0
    }

    /// Finds the index of the first selectable (non-current-value) item.
    private func findFirstSelectableIndex() -> Int? {
        for (index, match) in fuzzyMatches.enumerated() {
            if currentValue?.id != match.item.id {
                return index
            }
        }
        return nil
    }

    // MARK: - Navigation Logic

    /// Selects the next item in the completion list.
    private func selectNext() {
        guard !fuzzyMatches.isEmpty else { return }

        // Find next selectable index (skipping current value)
        var nextIndex = selectedIndex
        let count = fuzzyMatches.count

        for _ in 0 ..< count {
            nextIndex = (nextIndex + 1) % count
            if currentValue?.id != fuzzyMatches[nextIndex].item.id {
                selectedIndex = nextIndex
                return
            }
        }
    }

    /// Selects the previous item in the completion list.
    private func selectPrevious() {
        guard !fuzzyMatches.isEmpty else { return }

        // Find previous selectable index (skipping current value)
        var prevIndex = selectedIndex
        let count = fuzzyMatches.count

        for _ in 0 ..< count {
            prevIndex = (prevIndex - 1 + count) % count
            if currentValue?.id != fuzzyMatches[prevIndex].item.id {
                selectedIndex = prevIndex
                return
            }
        }
    }

    // MARK: - Selection Logic

    /// Handles selection of an item (either via click or Return key).
    private func handleSelect(_ item: Item) {
        // Don't allow selecting the current value
        guard currentValue?.id != item.id else { return }
        onSelect(item)
    }

    /// Handles the Return key press.
    private func handleReturnKey() {
        // If a valid item is selected, select it
        guard fuzzyMatches.indices.contains(selectedIndex) else {
            onSubmit()
            return
        }

        let selectedItem = fuzzyMatches[selectedIndex].item

        // Don't allow selecting the current value
        if currentValue?.id == selectedItem.id {
            onSubmit()
        } else {
            handleSelect(selectedItem)
        }
    }

    // MARK: - Text Field Helpers

    /// Selects all text in the text field on appear.
    private func selectAllText() {
        // Use DispatchQueue to ensure text field is ready
        DispatchQueue.main.async {
            // Find the NSTextField and select all
            if let window = NSApplication.shared.keyWindow,
               let firstResponder = window.firstResponder as? NSText {
                firstResponder.selectAll(nil)
            }
        }
    }

    // MARK: - Outside Click Detection

    /// Installs a mouse click monitor to detect clicks outside the field/menu.
    private func installClickOutsideMonitor() {
        // Remove existing monitor if any
        removeClickOutsideMonitor()

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            let clickLocation = event.locationInWindow

            // Convert to screen coordinates
            guard let window = event.window else { return event }
            let screenLocation = window.convertPoint(toScreen: clickLocation)

            // Check if click is outside both field and menu
            let isOutsideField = !fieldBounds.contains(screenLocation)
            let isOutsideMenu = menuBounds.isEmpty || !menuBounds.contains(screenLocation)

            if isOutsideField, isOutsideMenu {
                onCancel()
            }

            return event
        }
    }

    /// Removes the mouse click monitor.
    private func removeClickOutsideMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Keyboard Monitoring

    /// Installs a keyboard monitor to handle Ctrl+N/P navigation.
    private func installKeyboardMonitor() {
        // Remove existing monitor if any
        removeKeyboardMonitor()

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let input = KeyInput(event: event)

            // Only handle Ctrl+N/P when menu is visible
            guard !fuzzyMatches.isEmpty else { return event }

            if input.modifierFlags.contains(.control) {
                if input.keyCode == KeyCode.keyN || input.charactersIgnoringModifiers == "n" {
                    selectNext()
                    return nil
                }
                if input.keyCode == KeyCode.keyP || input.charactersIgnoringModifiers == "p" {
                    selectPrevious()
                    return nil
                }
            }

            return event
        }
    }

    /// Removes the keyboard monitor.
    private func removeKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }
}

// MARK: - Preference Keys

/// Preference key for passing text field height up the view hierarchy.
private struct TextFieldHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Preference key for passing text field bounds up the view hierarchy.
private struct TextFieldBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// (No additional preference keys.)

/// Preference key for passing menu bounds up the view hierarchy.
private struct MenuBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// (No additional preference keys.)

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var text = "bee"

        let items = [
            CompletionItem(value: "bee", count: 10),
            CompletionItem(value: "infra", count: 5),
            CompletionItem(value: "work", count: 3),
            CompletionItem(value: "personal", count: 12),
        ]

        var body: some View {
            VStack(spacing: 20) {
                Text("Completion Field Demo")
                    .font(.headline)

                CompletionField(
                    text: $text,
                    placeholder: "Project name...",
                    items: items,
                    currentValue: items.first,
                    onSubmit: { print("Submit: \(text)") },
                    onCancel: { print("Cancel") },
                    onSelect: { item in
                        print("Selected: \(item.displayValue)")
                        text = item.displayValue
                    },
                    theme: .default,
                    minWidth: 200,
                    minHeight: 100,
                    maxHeight: 200
                )
                .frame(width: 300)

                Spacer()
            }
            .padding()
            .frame(width: 400, height: 400)
            .background(ThemeManager.current.base)
        }
    }

    return PreviewWrapper()
}
