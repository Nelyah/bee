import AppKit
import SwiftUI

// MARK: - Protocols

/// Protocol for items that can be used in completion menus.
protocol CompletableItem: Identifiable {
    /// The text to display and search against.
    var displayValue: String { get }

    /// Optional metadata to display (e.g., count, description).
    var metadata: String? { get }
}

/// A fuzzy-matched item with its match score and highlighted indices.
struct FuzzyMatchedItem<Item: CompletableItem> {
    let item: Item
    let match: FuzzyMatch
}

// MARK: - CompletionItem Extension

extension CompletionItem: CompletableItem {
    var displayValue: String { value }
    var metadata: String? { count.map(String.init) }
}

// MARK: - CompletionMenuView

/// Dropdown menu for displaying completion suggestions with fuzzy matching.
struct CompletionMenuView<Item: CompletableItem>: View {
    let matches: [FuzzyMatchedItem<Item>]
    let selectedIndex: Int
    let currentValue: Item?
    let theme: CompletionTheme
    let onSelect: (Item) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.element.item.id) { index, matchedItem in
                        let isCurrentValue = currentValue?.id == matchedItem.item.id
                        CompletionRow(
                            matchedItem: matchedItem,
                            isSelected: index == selectedIndex,
                            isCurrentValue: isCurrentValue,
                            theme: theme
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isCurrentValue else { return }
                            onSelect(matchedItem.item)
                        }
                        .id(index)
                    }
                }
            }
            .onChange(of: selectedIndex) { _, newValue in
                guard matches.indices.contains(newValue) else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(maxHeight: 6 * 30) // Max 6 items visible, then scroll
        .padding(theme.menuPadding)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.border.opacity(theme.borderOpacity), lineWidth: 1)
        )
        .shadow(color: theme.shadow.color, radius: theme.shadow.radius, x: theme.shadow.x, y: theme.shadow.y)
    }
}

// MARK: - Legacy Wrapper (for backward compatibility)

/// Legacy CompletionMenuView that works with CompletionItem directly (no fuzzy matching).
/// Use the generic CompletionMenuView<Item> with FuzzyMatchedItem for new code.
extension CompletionMenuView where Item == CompletionItem {
    init(
        items: [CompletionItem],
        selectedIndex: Int,
        currentValue: String?,
        onSelect: @escaping (CompletionItem) -> Void
    ) {
        // Convert items to FuzzyMatchedItem with perfect scores (no fuzzy matching)
        let matches = items.map { item in
            FuzzyMatchedItem(
                item: item,
                match: FuzzyMatch(score: 1.0, matchedIndices: [])
            )
        }

        // Find current value item
        let currentItem = currentValue.flatMap { val in
            items.first { $0.value == val }
        }

        self.init(
            matches: matches,
            selectedIndex: selectedIndex,
            currentValue: currentItem,
            theme: .default,
            onSelect: onSelect
        )
    }
}

/// A single row in the completion menu with fuzzy match highlighting.
struct CompletionRow<Item: CompletableItem>: View {
    let matchedItem: FuzzyMatchedItem<Item>
    let isSelected: Bool
    let isCurrentValue: Bool
    let theme: CompletionTheme
    @State private var isHovering: Bool = false

    var body: some View {
        HStack {
            // Highlighted text with fuzzy matches
            if matchedItem.match.matchedIndices.isEmpty {
                // No fuzzy highlighting (perfect match or no query)
                Text(matchedItem.item.displayValue)
                    .font(.system(size: DesignTokens.TypeScale.body, weight: .medium, design: .monospaced))
                    .foregroundColor(textColor)
            } else {
                // Fuzzy highlighted text
                FuzzyMatcher.highlightedText(
                    matchedItem.item.displayValue,
                    matchedIndices: matchedItem.match.matchedIndices,
                    baseFont: .system(size: DesignTokens.TypeScale.body, weight: .medium, design: .monospaced),
                    baseColor: textColor,
                    matchColor: theme.matchHighlightColor,
                    matchWeight: theme.matchFontWeight
                )
            }

            Spacer()

            if let metadata = matchedItem.item.metadata {
                Text(metadata)
                    .font(.system(size: DesignTokens.TypeScale.label, weight: .regular))
                    .foregroundColor(metadataColor)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(backgroundColor)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var textColor: Color {
        if isSelected {
            return theme.selectedText
        }
        if isCurrentValue {
            return theme.currentValueText
        }
        return theme.normalText
    }

    private var metadataColor: Color {
        if isSelected {
            return theme.metadataSelectedText
        }
        return theme.metadataText
    }

    private var backgroundColor: Color {
        if isSelected {
            return theme.selectedBackground
        }
        if isHovering, !isCurrentValue {
            return theme.hoverBackground
        }
        return Color.clear
    }
}

// MARK: - Visual Effect Blur

/// A SwiftUI wrapper for NSVisualEffectView to provide native macOS blur effects.
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    CompletionMenuView(
        items: [
            CompletionItem(value: "bee", count: 10),
            CompletionItem(value: "infra", count: 5),
            CompletionItem(value: "work", count: 3),
        ],
        selectedIndex: 1,
        currentValue: nil,
        onSelect: { _ in }
    )
    .frame(width: 200)
    .padding()
    .background(ThemeManager.current.base)
}
