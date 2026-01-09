import SwiftUI

/// Displays linked tasks grouped by relationship type.
///
/// This component shows task links (blocks, depends on, parent/child, etc.)
/// in a consistent order with appropriate icons and styling.
/// Each link shows the target task's status badge and title, and is clickable
/// to navigate to that task.
struct LinkedTasksSection: View {
    let links: [TaskLinkDto]
    let linksByType: [LinkType: [TaskLinkDto]]
    let tasks: [ApiTask]
    let focusedItem: DetailFocusableItem?
    let onNavigateToTask: (String) -> Void

    /// Ordered list of link types for consistent display
    private static let linkTypeOrder: [LinkType] = [
        .blocking,
        .dependsOn,
        .parentOf,
        .childOf,
        .relatedTo,
        .duplicates,
    ]

    var body: some View {
        if !links.isEmpty {
            DetailSection(title: "Linked Tasks") {
                ForEach(Self.linkTypeOrder, id: \.self) { linkType in
                    if let linksOfType = linksByType[linkType], !linksOfType.isEmpty {
                        linkTypeGroup(linkType: linkType, links: linksOfType)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func linkTypeGroup(linkType: LinkType, links: [TaskLinkDto]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            // Link type header
            HStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: linkType.iconName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)
                Text(linkType.displayName.uppercased())
                    .font(.system(size: DesignTokens.TypeScale.label, weight: .semibold))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .padding(.top, DesignTokens.Spacing.extraSmall)

            // Links under this type
            ForEach(links) { link in
                linkRow(link: link)
            }
        }
    }

    @ViewBuilder
    private func linkRow(link: TaskLinkDto) -> some View {
        let isFocused = isLinkFocused(link)
        let target = targetTask(for: link)
        let status = target?.status ?? "pending"
        let title = target?.summary ?? shortUUID(link.targetUuid)

        Button {
            onNavigateToTask(link.targetUuid)
        } label: {
            HStack(spacing: DesignTokens.Spacing.small) {
                // Status indicator
                Circle()
                    .fill(statusColor(status))
                    .frame(width: 8, height: 8)

                // Task title
                Text(title)
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.text)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .navigationRegistrable(.linkedTask(link))
            .modifier(DetailFocusRing(isFocused: isFocused))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(isFocused ? "Press Enter to view task" : "Click to view task")
    }

    // MARK: - Helpers

    /// Looks up the target task from the available tasks array
    private func targetTask(for link: TaskLinkDto) -> ApiTask? {
        tasks.first { $0.uuid == link.targetUuid }
    }

    /// Checks if this link is currently keyboard-focused
    private func isLinkFocused(_ link: TaskLinkDto) -> Bool {
        if case let .linkedTask(focusedLink) = focusedItem {
            return focusedLink.id == link.id
        }
        return false
    }

    /// Formats UUID to show first 8 characters for display
    private func shortUUID(_ uuid: String) -> String {
        String(uuid.prefix(8))
    }
}
