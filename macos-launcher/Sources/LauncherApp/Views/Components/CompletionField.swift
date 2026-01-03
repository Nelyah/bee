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

    /// When true, enables freeform text entry mode:
    /// - Menu stays open even with no matches (shows empty state)
    /// - No item is auto-selected (selectedIndex starts at -1)
    /// - Navigation allows reaching -1 (no selection) state
    /// Default is false (existing behavior for projects).
    let allowsFreeformEntry: Bool

    // MARK: - Internal State

    /// Local copy of text for immediate filtering without triggering @Published during view updates.
    /// This decouples the TextField from the binding to avoid "Publishing changes from within view updates".
    @State private var localText: String = ""

    /// Currently selected index in the fuzzy matches.
    @State private var selectedIndex: Int = 0

    /// Fuzzy-matched and scored items.
    @State private var fuzzyMatches: [FuzzyMatchedItem<Item>] = []

    /// Whether the text field has focus.
    @FocusState private var isFocused: Bool

    /// Text field height (calculated dynamically).
    @State private var textFieldHeight: CGFloat = 32

    /// Whether the completion menu is visible.
    /// Separate from text/fuzzyMatches state to allow empty text while still showing menu.
    @State private var showMenu: Bool = true

    /// Keyboard monitor for Ctrl+N/P navigation.
    @State private var keyboardMonitor: Any?

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextField(placeholder, text: $localText)
                .textFieldStyle(.plain)
                .font(.system(size: DesignTokens.TypeScale.body, weight: .regular, design: .monospaced))
                .foregroundColor(ThemeManager.current.text)
                .padding(.horizontal, DesignTokens.Spacing.small)
                .padding(.vertical, DesignTokens.Spacing.extraSmall)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: TextFieldHeightPreferenceKey.self, value: geometry.size.height)
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
                    // Initialize local state from binding
                    localText = text
                    isFocused = true
                    showMenu = true
                    selectAllText()
                    updateFuzzyMatches(query: localText)
                    installKeyboardMonitor()
                }
                .onChange(of: localText) { _, newValue in
                    // Filter immediately using local state
                    updateFuzzyMatches(query: newValue)
                    // Defer binding update to avoid "Publishing changes from within view updates"
                    DispatchQueue.main.async {
                        text = newValue
                    }
                }
                .onChange(of: fuzzyMatches.isEmpty) { wasEmpty, isEmpty in
                    // When popover appears (fuzzyMatches becomes non-empty), ensure TextField keeps focus
                    // Popovers create a separate window that can steal focus from the main window
                    if wasEmpty, !isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isFocused = true
                        }
                    }
                }
                .onPreferenceChange(TextFieldHeightPreferenceKey.self) { height in
                    textFieldHeight = max(height, 24)
                }
                .onDisappear {
                    removeKeyboardMonitor()
                }
                .onSubmit {
                    onSubmit()
                }
                // Keyboard shortcuts
                .onKeyPress(.escape) {
                    showMenu = false
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
                // Vim-style navigation
                .onKeyPress(KeyEquivalent("j")) {
                    selectNext()
                    return .handled
                }
                .onKeyPress(KeyEquivalent("l")) {
                    selectNext()
                    return .handled
                }
                .onKeyPress(KeyEquivalent("k")) {
                    selectPrevious()
                    return .handled
                }
                .onKeyPress(KeyEquivalent("h")) {
                    selectPrevious()
                    return .handled
                }
                .onKeyPress(.return) {
                    handleReturnKey()
                    return .handled
                }
        }
        .frame(height: textFieldHeight)
        // Completion menu as popover - always floats above all content (window-level overlay)
        // Menu stays open until explicitly closed (escape, selection, or click outside)
        .popover(
            isPresented: Binding(
                get: { showMenu },
                set: { newValue in
                    // When SwiftUI dismisses the popover (click outside), it sets to false
                    // We need to call onCancel() to notify the parent
                    if !newValue {
                        onCancel()
                    }
                }
            ),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom // Arrow at bottom of anchor → popover appears BELOW the text field
        ) {
            if fuzzyMatches.isEmpty {
                // Empty state when no matches
                if allowsFreeformEntry {
                    FreeformEntryPrompt(
                        query: localText.trimmingCharacters(in: .whitespaces),
                        theme: theme
                    )
                    .frame(minWidth: minWidth)
                } else {
                    NoMatchesPrompt(theme: theme)
                        .frame(minWidth: minWidth)
                }
            } else {
                CompletionMenuView(
                    matches: fuzzyMatches,
                    selectedIndex: selectedIndex,
                    currentValue: currentValue,
                    theme: theme,
                    onSelect: handleSelect
                )
                // Force re-render when fuzzyMatches changes
                .id(fuzzyMatches.map { "\($0.item.id)" }.joined(separator: ","))
                .frame(minWidth: minWidth, minHeight: minHeight, maxHeight: maxHeight)
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

        // Reset selection based on mode
        if allowsFreeformEntry {
            // Freeform mode: no auto-selection, user must navigate to select
            selectedIndex = -1
        } else {
            // Normal mode: auto-select first selectable item
            // Use -1 when no valid selection exists (empty list or only currentValue matches).
            // This prevents selectedIndex from being 0 for an empty array (invalid index).
            selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
                items: fuzzyMatches.map(\.item),
                currentValueId: currentValue?.id
            ) ?? -1
        }
    }

    // MARK: - Navigation Logic

    /// Selects the next item in the completion list.
    private func selectNext() {
        // From no-selection, go to first selectable item
        if selectedIndex == -1 {
            selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
                items: fuzzyMatches.map(\.item),
                currentValueId: currentValue?.id
            ) ?? -1
            return
        }

        // Otherwise, normal behavior (wraps around)
        guard let nextIndex = CompletionIndexCalculator.selectNextIndex(
            from: selectedIndex,
            items: fuzzyMatches.map(\.item),
            currentValueId: currentValue?.id
        ) else { return }

        selectedIndex = nextIndex
    }

    /// Selects the previous item in the completion list.
    private func selectPrevious() {
        if allowsFreeformEntry {
            // In freeform mode, allow going to "no selection" state
            guard let prevIndex = CompletionIndexCalculator.selectPreviousIndexAllowingUnselect(
                from: selectedIndex,
                items: fuzzyMatches.map(\.item),
                currentValueId: currentValue?.id
            ) else { return }
            selectedIndex = prevIndex
        } else {
            // Normal mode: wrap around
            guard let prevIndex = CompletionIndexCalculator.selectPreviousIndex(
                from: selectedIndex,
                items: fuzzyMatches.map(\.item),
                currentValueId: currentValue?.id
            ) else { return }
            selectedIndex = prevIndex
        }
    }

    // MARK: - Selection Logic

    /// Handles selection of an item (either via click or Return key).
    private func handleSelect(_ item: Item) {
        // Don't allow selecting the current value
        guard currentValue?.id != item.id else { return }
        showMenu = false
        onSelect(item)
    }

    /// Handles the Return key press.
    private func handleReturnKey() {
        // If a valid item is selected, select it
        guard fuzzyMatches.indices.contains(selectedIndex) else {
            showMenu = false
            onSubmit()
            return
        }

        let selectedItem = fuzzyMatches[selectedIndex].item

        // Don't allow selecting the current value
        if currentValue?.id == selectedItem.id {
            showMenu = false
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

// MARK: - Empty State Views

/// Empty state shown when freeform entry is enabled but no matches exist.
/// Prompts user to press Enter to create a new item with the typed text.
private struct FreeformEntryPrompt: View {
    let query: String
    let theme: CompletionTheme

    var body: some View {
        HStack(spacing: 4) {
            Text("Press Enter to create")
                .foregroundColor(theme.metadataText)
            Text("'\(query)'")
                .foregroundColor(theme.normalText)
                .fontWeight(.medium)
        }
        .font(.system(size: DesignTokens.TypeScale.body, design: .monospaced))
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.border.opacity(theme.borderOpacity), lineWidth: 1)
        )
    }
}

/// Empty state shown when no matches exist and freeform entry is disabled.
/// Indicates that the typed text doesn't match any available options.
private struct NoMatchesPrompt: View {
    let theme: CompletionTheme

    var body: some View {
        Text("No matches")
            .font(.system(size: DesignTokens.TypeScale.body, design: .monospaced))
            .foregroundColor(theme.metadataText)
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.border.opacity(theme.borderOpacity), lineWidth: 1)
            )
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
                    maxHeight: 200,
                    allowsFreeformEntry: false
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
