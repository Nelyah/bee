import SwiftUI

/// A compact preview of external links for expanded task rows.
struct TaskRowLinksPreview: View {
    let links: [ExternalLinkDto]
    var maxVisible: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Section header
            Text("Links")
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
                .foregroundColor(ThemeManager.current.subtext0)

            // Link chips in flow layout
            FlowLayout(spacing: DesignTokens.Spacing.xs, rowSpacing: DesignTokens.Spacing.xs) {
                ForEach(visibleLinks, id: \.id) { link in
                    CompactLinkChip(link: link)
                }

                // "+N more" indicator
                if remainingCount > 0 {
                    moreIndicator
                }
            }
        }
    }

    private var visibleLinks: [ExternalLinkDto] {
        Array(links.prefix(maxVisible))
    }

    private var remainingCount: Int {
        max(0, links.count - maxVisible)
    }

    private var moreIndicator: some View {
        Text("+\(remainingCount) more")
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
            .foregroundColor(ThemeManager.current.subtext0)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(ThemeManager.current.surface0.opacity(0.5))
            )
    }
}

/// A compact chip displaying a single external link with quiet hover styling.
struct CompactLinkChip: View {
    let link: ExternalLinkDto
    @Environment(\.openURL) private var openURL
    @State private var isHovering = false

    var body: some View {
        Button {
            if let url = URL(string: link.url) {
                openURL(url)
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                providerIcon
                    .frame(width: 12, height: 12)

                Text(displayText)
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                    .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current.text)
                    .underline(isHovering)
                    .lineLimit(1)

                syncStatusIcon
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(isHovering ? ThemeManager.current.surface1 : ThemeManager.current.surface1.opacity(0.7))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var providerIcon: some View {
        switch link.provider.lowercased() {
        case "gitlab":
            if let icon = AssetIcon.gitlab() {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
        case "jira":
            if let icon = AssetIcon.jira() {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
        default:
            Image(systemName: "link")
                .font(.system(size: 10))
                .foregroundColor(ThemeManager.current.subtext0)
        }
    }

    private var displayText: String {
        if let summary = link.cachedSummary() {
            switch summary {
            case let .gitlab(g):
                return truncate(g.title, to: 30)
            case let .jira(j):
                return truncate(j.summary, to: 30)
            }
        }
        return link.externalKey
    }

    @ViewBuilder
    private var syncStatusIcon: some View {
        let state = link.syncState()
        switch state {
        case .synced:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 8))
                .foregroundColor(ThemeManager.current.teal)
        case .stale:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8))
                .foregroundColor(ThemeManager.current.peach)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 8))
                .foregroundColor(ThemeManager.current.red)
        case .pending:
            Image(systemName: "clock.fill")
                .font(.system(size: 8))
                .foregroundColor(ThemeManager.current.subtext0)
        }
    }

    private func truncate(_ text: String, to length: Int) -> String {
        if text.count <= length {
            return text
        }
        return String(text.prefix(length - 1)) + "…"
    }
}

#Preview("Links Preview") {
    VStack(alignment: .leading, spacing: 20) {
        TaskRowLinksPreview(links: [
            ExternalLinkDto(
                id: 1,
                provider: "gitlab",
                url: "https://gitlab.com/project/-/merge_requests/123",
                externalKey: "project:123",
                cachedResponse: nil,
                lastSyncedAt: nil,
                syncError: nil
            ),
            ExternalLinkDto(
                id: 2,
                provider: "jira",
                url: "https://jira.example.com/browse/PROJ-456",
                externalKey: "PROJ-456",
                cachedResponse: nil,
                lastSyncedAt: "2025-01-15T10:00:00Z",
                syncError: nil
            ),
        ])
    }
    .padding()
    .background(ThemeManager.current.base)
}
