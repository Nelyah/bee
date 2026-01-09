import SwiftUI

/// Editable tags row with chips for existing tags and autocomplete for adding new ones.
///
/// Features:
/// - Displays existing tags as removable chips
/// - Keyboard navigation: h/l or arrows to select tags, x to delete
/// - "+ Add tag" button opens CompletionField for adding new tags
/// - Completions filter out already-added tags
struct EditableTagsRow: View {
    // MARK: - Inputs

    /// Current tags on the task.
    let tags: [String]

    /// Index of the currently selected tag (for local keyboard navigation with h/l).
    let selectedTagIndex: Int?

    /// Index of the tag focused via global keyboard navigation (j/k from parent).
    /// When set, shows a DetailFocusRing around the tag at this index.
    var keyboardFocusedTagIndex: Int?

    /// Whether the add button is focused via global keyboard navigation.
    var isAddButtonFocused: Bool = false

    /// Whether the CompletionField is active for adding a new tag.
    let isAddingTag: Bool

    /// Query text for the tag completion field.
    @Binding var tagAddQuery: String

    /// All available tag completion items (will be filtered by CompletionField).
    let allTagCompletions: [CompletionItem]

    /// Whether a tag operation is in progress.
    let isSubmitting: Bool

    // MARK: - Callbacks

    /// Called when user selects a tag index (for keyboard navigation).
    let onSelectTagIndex: (Int?) -> Void

    /// Called when user starts adding a tag (clicks the + button).
    let onStartAdding: () -> Void

    /// Called when user cancels adding a tag.
    let onCancelAdding: () -> Void

    /// Called when user selects a tag from the completion menu.
    let onSelectCompletion: (CompletionItem) -> Void

    /// Called when user removes a tag (clicks × or presses x with selection).
    let onRemoveTag: (String) -> Void

    /// Called when user presses Enter on a focused tag to edit it.
    var onEditTag: ((Int) -> Void)?

    // MARK: - Private

    private var theme: any Theme {
        ThemeManager.current
    }

    /// Filtered completions that exclude already-added tags.
    private var filteredCompletions: [CompletionItem] {
        let existingTags = Set(tags)
        return allTagCompletions.filter { !existingTags.contains($0.value) }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
            // Label
            Text("Tags")
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                .foregroundColor(theme.subtext0)

            // Tags + Add button (with keyboard handling for tag navigation)
            FlowLayout(spacing: DesignTokens.Spacing.small, rowSpacing: DesignTokens.Spacing.small) {
                ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
                    TagChip(
                        tag: tag,
                        isSelected: selectedTagIndex == index,
                        onRemove: { onRemoveTag(tag) }
                    )
                    .navigationRegistrable(.tag(tag, index: index))
                    .modifier(DetailFocusRing(isFocused: keyboardFocusedTagIndex == index))
                    .onTapGesture {
                        onSelectTagIndex(index)
                    }
                }

                // Add tag button (only when not adding)
                if !isAddingTag {
                    addTagButton
                        .navigationRegistrable(.addTagButton)
                        .modifier(DetailFocusRing(isFocused: isAddButtonFocused))
                }
            }
            .contentShape(Rectangle())
            .onKeyPress { key in
                handleKeyPress(key)
            }

            // CompletionField - outside the keyboard/click interception area
            // This prevents .contentShape and .onKeyPress from intercepting events
            if isAddingTag {
                CompletionField(
                    text: $tagAddQuery,
                    placeholder: "Tag name...",
                    items: filteredCompletions,
                    currentValue: nil,
                    onSubmit: {
                        // If query matches a completion, add it
                        let trimmed = tagAddQuery.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            onSelectCompletion(CompletionItem(value: trimmed, count: nil))
                        } else {
                            onCancelAdding()
                        }
                    },
                    onCancel: onCancelAdding,
                    onSelect: onSelectCompletion,
                    theme: .default,
                    minWidth: 200,
                    minHeight: 200,
                    maxHeight: 200,
                    allowsFreeformEntry: true
                )
                .frame(width: 150)
                .disabled(isSubmitting)
                .opacity(isSubmitting ? 0.6 : 1.0)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var addTagButton: some View {
        Button(action: onStartAdding) {
            HStack(spacing: DesignTokens.Spacing.extraSmall) {
                Image(systemName: "plus")
                    .font(.system(size: DesignTokens.IconSize.mini, weight: .semibold))
                if tags.isEmpty {
                    Text("Add tag")
                        .font(.system(size: DesignTokens.TypeScale.bodySm))
                }
            }
            .foregroundColor(theme.subtext0)
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(theme.surface0)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .stroke(theme.overlay0, lineWidth: 1)
            )
            .cornerRadius(DesignTokens.Radius.small)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    // MARK: - Keyboard Handling

    private func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
        // Don't handle keys when adding a tag (CompletionField handles them)
        guard !isAddingTag else { return .ignored }

        switch key.key {
        case .leftArrow, KeyEquivalent("h"):
            moveSelectionLeft()
            return .handled

        case .rightArrow, KeyEquivalent("l"):
            moveSelectionRight()
            return .handled

        case KeyEquivalent("x"):
            if let index = selectedTagIndex, index < tags.count {
                onRemoveTag(tags[index])
                // Adjust selection after removal
                if tags.count > 1 {
                    let newIndex = min(index, tags.count - 2)
                    onSelectTagIndex(newIndex)
                } else {
                    onSelectTagIndex(nil)
                }
                return .handled
            }
            return .ignored

        case .escape:
            onSelectTagIndex(nil)
            return .handled

        default:
            return .ignored
        }
    }

    private func moveSelectionLeft() {
        guard !tags.isEmpty else { return }

        if let current = selectedTagIndex {
            if current > 0 {
                onSelectTagIndex(current - 1)
            }
            // At index 0, don't wrap
        } else {
            // No selection, select the last tag
            onSelectTagIndex(tags.count - 1)
        }
    }

    private func moveSelectionRight() {
        guard !tags.isEmpty else { return }

        if let current = selectedTagIndex {
            if current < tags.count - 1 {
                onSelectTagIndex(current + 1)
            }
            // At last index, don't wrap
        } else {
            // No selection, select the first tag
            onSelectTagIndex(0)
        }
    }
}

// MARK: - Preview

#Preview("EditableTagsRow - With Tags") {
    struct PreviewWrapper: View {
        @State private var selectedIndex: Int? = 1
        @State private var isAdding = false
        @State private var query = ""

        let tags = ["hobby", "code", "urgent"]
        let completions = [
            CompletionItem(value: "work", count: 5),
            CompletionItem(value: "personal", count: 3),
            CompletionItem(value: "review", count: 2),
        ]

        var body: some View {
            EditableTagsRow(
                tags: tags,
                selectedTagIndex: selectedIndex,
                isAddingTag: isAdding,
                tagAddQuery: $query,
                allTagCompletions: completions,
                isSubmitting: false,
                onSelectTagIndex: { selectedIndex = $0 },
                onStartAdding: { isAdding = true },
                onCancelAdding: { isAdding = false
                    query = ""
                },
                onSelectCompletion: { print("Selected: \($0.value)") },
                onRemoveTag: { print("Remove: \($0)") }
            )
            .padding()
            .frame(width: 400)
            .background(ThemeManager.current.base)
        }
    }

    return PreviewWrapper()
}

#Preview("EditableTagsRow - Empty") {
    struct PreviewWrapper: View {
        @State private var isAdding = false
        @State private var query = ""

        var body: some View {
            EditableTagsRow(
                tags: [],
                selectedTagIndex: nil,
                isAddingTag: isAdding,
                tagAddQuery: $query,
                allTagCompletions: [
                    CompletionItem(value: "hobby", count: 10),
                    CompletionItem(value: "work", count: 5),
                ],
                isSubmitting: false,
                onSelectTagIndex: { _ in },
                onStartAdding: { isAdding = true },
                onCancelAdding: { isAdding = false
                    query = ""
                },
                onSelectCompletion: { print("Selected: \($0.value)") },
                onRemoveTag: { _ in }
            )
            .padding()
            .frame(width: 400)
            .background(ThemeManager.current.base)
        }
    }

    return PreviewWrapper()
}
