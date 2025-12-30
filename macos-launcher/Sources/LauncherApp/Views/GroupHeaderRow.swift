import SwiftUI

struct GroupHeaderRow: View {
    let header: GroupHeader
    let isHovered: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    private var backgroundColor: Color {
        if isSelected {
            return ThemeManager.current.surface1
        } else if isHovered {
            return ThemeManager.current.surface0.opacity(0.5)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: header.isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 12)

            Text(header.displayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? ThemeManager.current.text : ThemeManager.current.subtext1)

            Spacer()

            if isHovered || isSelected {
                Text("Space to \(header.isCollapsed ? "expand" : "collapse")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(ThemeManager.current.overlay0)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

#Preview {
    VStack(spacing: 8) {
        GroupHeaderRow(
            header: GroupHeader(key: "work", displayName: "Work", isCollapsed: false),
            isHovered: false,
            isSelected: false,
            onToggle: {}
        )
        GroupHeaderRow(
            header: GroupHeader(key: "personal", displayName: "Personal", isCollapsed: true),
            isHovered: true,
            isSelected: false,
            onToggle: {}
        )
        GroupHeaderRow(
            header: GroupHeader(key: nil, displayName: "No Project", isCollapsed: false),
            isHovered: false,
            isSelected: true,
            onToggle: {}
        )
    }
    .padding()
    .background(ThemeManager.current.base)
}
