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
        .frame(maxHeight: 8 * 30)
        .padding(.vertical, 4)
        .background(ThemeManager.current.surface0)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ThemeManager.current.surface1, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

/// A single row in the completion menu.
struct CompletionRow: View {
    let item: CompletionItem
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(item.value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? ThemeManager.current.base : ThemeManager.current.text)

            Spacer()

            if let count = item.count {
                Text("\(count)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(isSelected ? ThemeManager.current.surface0 : ThemeManager.current.overlay0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? ThemeManager.current.blue : Color.clear)
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
