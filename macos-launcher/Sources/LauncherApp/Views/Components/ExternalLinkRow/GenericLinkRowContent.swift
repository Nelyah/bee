import SwiftUI

/// Displays generic external link content (Jira, unknown providers, etc.).
///
/// This view provides a simpler layout than GitLab:
/// - Title text (from cached summary or external key)
/// - Detail text (status or other info)
/// - Clickable URL
struct GenericLinkRowContent: View {
    let link: ExternalLinkDto

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
            // Title line
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
                Text(titleText)
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                Spacer()
            }

            // Detail line
            HStack(spacing: DesignTokens.Spacing.small) {
                if !detailText.isEmpty {
                    Text(detailText)
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        .foregroundColor(ThemeManager.current.subtext0)
                }
                Spacer()
            }

            // URL link
            if let url = URL(string: link.url) {
                Link(destination: url) {
                    Text(link.url)
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        .foregroundColor(ThemeManager.current.subtext1)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                Text(link.url)
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext1)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // MARK: - Computed Properties

    private var titleText: String {
        if let summary = link.cachedSummary() {
            switch summary {
            case let .gitlab(gitlab):
                return gitlab.title
            case let .jira(jira):
                return jira.summary
            }
        }
        return link.externalKey
    }

    private var detailText: String {
        if let summary = link.cachedSummary() {
            switch summary {
            case let .gitlab(gitlab):
                var parts: [String] = []
                if let state = gitlab.state {
                    let display = GitlabMergeRequestState.fromRaw(state)
                    switch display {
                    case .opened:
                        parts.append("Open")
                    case .merged:
                        parts.append("Merged")
                    case .closed:
                        parts.append("Closed")
                    case let .unknown(value):
                        parts.append(value.capitalized)
                    }
                }
                if let pipeline = gitlab.pipelineStatus {
                    parts.append(GitlabPipelineStatus.fromRaw(pipeline).label)
                }
                return parts.joined(separator: " • ")
            case let .jira(jira):
                return jira.status ?? ""
            }
        }
        return ""
    }
}
