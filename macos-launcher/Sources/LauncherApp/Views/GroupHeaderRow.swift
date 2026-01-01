import SwiftUI

struct GroupHeaderRow: View {
    let header: GroupHeader
    let isHovered: Bool
    let isSelected: Bool

    private var backgroundColor: Color {
        if isSelected {
            ThemeManager.current.surfaceSelected
        } else if isHovered {
            ThemeManager.current.surfaceHover
        } else {
            // Subtle background tint for visual distinction
            ThemeManager.current.surface0.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: header.isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .bold))
                .foregroundColor(ThemeManager.current.subtext1)
                .frame(width: 12)

            // Folder icon for visual distinction
            Image(systemName: "folder.fill")
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                .foregroundColor(ThemeManager.current.subtext0)

            Text(header.displayName)
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .bold, design: .rounded))
                .foregroundColor(isSelected || isHovered ? ThemeManager.current.text : ThemeManager.current.subtext1)

            // Task count badge
            Text("(\(header.taskCount))")
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext1)

            Spacer()

            if isHovered || isSelected {
                Text("Tab to \(header.isCollapsed ? "expand" : "collapse")")
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext1)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.small)
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 8) {
        GroupHeaderRow(
            header: GroupHeader(key: "work", displayName: "Work", taskCount: 5, isCollapsed: false),
            isHovered: false,
            isSelected: false
        )
        GroupHeaderRow(
            header: GroupHeader(key: "personal", displayName: "Personal", taskCount: 3, isCollapsed: true),
            isHovered: true,
            isSelected: false
        )
        GroupHeaderRow(
            header: GroupHeader(key: nil, displayName: "No Project", taskCount: 12, isCollapsed: false),
            isHovered: false,
            isSelected: true
        )
    }
    .padding()
    .background(ThemeManager.current.base)
}
