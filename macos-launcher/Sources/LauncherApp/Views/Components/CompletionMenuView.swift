import AppKit
import SwiftUI

/// Dropdown menu for displaying completion suggestions.
struct CompletionMenuView: View {
    let items: [CompletionItem]
    let selectedIndex: Int
    let onSelect: (CompletionItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        CompletionRow(item: item, isSelected: index == selectedIndex)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(item) }
                            .id(index)
                    }
                }
            }
            .onChange(of: selectedIndex) { _, newValue in
                guard items.indices.contains(newValue) else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(maxHeight: 6 * 30) // Max 6 items visible, then scroll
        .padding(.vertical, DesignTokens.Spacing.extraSmall)
        .background(
            // Use vibrancy effect for modern macOS feel
            ZStack {
                // Base dark layer for readability
                ThemeManager.current.surface0.opacity(0.85)
                // Subtle blur effect
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .stroke(ThemeManager.current.surface1.opacity(DesignTokens.Border.containerOpacity), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

/// A single row in the completion menu.
struct CompletionRow: View {
    let item: CompletionItem
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(item.value)
                .font(.system(size: DesignTokens.TypeScale.body, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? ThemeManager.current.text : ThemeManager.current.text)

            Spacer()

            if let count = item.count {
                Text("\(count)")
                    .font(.system(size: DesignTokens.TypeScale.label, weight: .regular))
                    .foregroundColor(isSelected ? ThemeManager.current.text : ThemeManager.current.overlay0)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(isSelected ? ThemeManager.current.blue : Color.clear)
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
        onSelect: { _ in }
    )
    .frame(width: 200)
    .padding()
    .background(ThemeManager.current.base)
}
