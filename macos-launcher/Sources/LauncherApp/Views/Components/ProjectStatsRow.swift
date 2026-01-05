import SwiftUI

/// A row displaying a project with its statistics and actions.
struct ProjectStatsRow: View {
    let node: ProjectNode
    let isExpanded: Bool
    let indentLevel: Int
    let onToggleExpand: () -> Void
    let onSelect: () -> Void
    let onShowBurndown: () -> Void

    @State private var isHovered = false

    private let indentWidth: CGFloat = 20

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            // Indentation
            if indentLevel > 0 {
                HStack(spacing: 0) {
                    ForEach(0 ..< indentLevel, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: indentWidth)
                    }
                }
            }

            // Expand/collapse chevron (if has children)
            if node.hasChildren {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: DesignTokens.IconSize.small))
                        .foregroundColor(ThemeManager.current.subtext0)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            } else {
                // Spacer for alignment
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 16, height: 16)
            }

            // Project name
            Text(node.name)
                .font(.system(size: DesignTokens.TypeScale.body))
                .foregroundColor(ThemeManager.current.text)
                .lineLimit(1)

            Spacer()

            // Stats pills
            HStack(spacing: DesignTokens.Spacing.extraSmall) {
                if node.stats.pendingCount > 0 {
                    StatsPill(count: node.stats.pendingCount, color: ThemeManager.current.peach)
                }
                if node.stats.activeCount > 0 {
                    StatsPill(count: node.stats.activeCount, color: ThemeManager.current.blue)
                }
                if node.stats.completedCount > 0 {
                    StatsPill(count: node.stats.completedCount, color: ThemeManager.current.green)
                }
                if node.stats.overdueCount > 0 {
                    StatsPill(count: node.stats.overdueCount, color: ThemeManager.current.red)
                }
            }

            // Burndown chart button
            Button(action: onShowBurndown) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: DesignTokens.IconSize.small))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .fill(isHovered ? ThemeManager.current.surface1 : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// A small colored pill showing a count.
struct StatsPill: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, DesignTokens.Spacing.extraSmall)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        ProjectStatsRow(
            node: ProjectNode(
                name: "backend",
                fullPath: "backend",
                stats: ProjectStats(
                    name: "backend",
                    pendingCount: 5,
                    activeCount: 3,
                    completedCount: 12,
                    overdueCount: 1,
                    totalCount: 20
                ),
                children: []
            ),
            isExpanded: false,
            indentLevel: 0,
            onToggleExpand: {},
            onSelect: {},
            onShowBurndown: {}
        )

        ProjectStatsRow(
            node: ProjectNode(
                name: "api",
                fullPath: "backend.api",
                stats: ProjectStats(
                    name: "api",
                    pendingCount: 2,
                    activeCount: 1,
                    completedCount: 5,
                    overdueCount: 0,
                    totalCount: 8
                ),
                children: []
            ),
            isExpanded: false,
            indentLevel: 1,
            onToggleExpand: {},
            onSelect: {},
            onShowBurndown: {}
        )
    }
    .padding()
    .background(ThemeManager.current.surface0)
    .frame(width: 400)
}
