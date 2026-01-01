import SwiftUI

/// Displays an external link (GitLab MR, Jira issue, etc.) with status and actions.
///
/// This is a thin coordinator that dispatches to provider-specific content views:
/// - `GitLabLinkRowContent` for GitLab merge requests (rich display with branch, approval, etc.)
/// - `GenericLinkRowContent` for Jira, or other providers (simple title/detail/URL display)
///
/// To add a new provider:
/// 1. Create a new content view (e.g., `GitHubLinkRowContent`)
/// 2. Add the provider check in `content` below
/// 3. The new view will automatically get the shared container styling
struct ExternalLinkRow: View {
    let link: ExternalLinkDto
    let onCopyBranch: (String) -> Void
    let onCopyLink: (String) -> Void
    /// Whether this row is focused via detail view keyboard navigation (j/k keys).
    var isKeyboardFocused: Bool = false

    var body: some View {
        content
            .padding(.top, DesignTokens.Spacing.small)
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.bottom, DesignTokens.Spacing.small)
            .overlay(alignment: .topTrailing) {
                LinkStatusBadge(state: link.syncState(), timestamp: link.lastSyncedAt, compact: true)
                    .padding(.top, DesignTokens.Spacing.extraSmall)
                    .padding(.trailing, DesignTokens.Spacing.extraSmall)
            }
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                    .fill(ThemeManager.current.surface1.opacity(0.7))
            )
            .detailFocusRing(isFocused: isKeyboardFocused)
    }

    /// Dispatches to the appropriate provider-specific content view.
    @ViewBuilder
    private var content: some View {
        if let gitlabSummary {
            GitLabLinkRowContent(
                link: link,
                summary: gitlabSummary,
                onCopyBranch: onCopyBranch,
                onCopyLink: onCopyLink
            )
        } else {
            GenericLinkRowContent(link: link)
        }
    }

    /// Extracts GitLab summary if this is a GitLab link with cached data.
    private var gitlabSummary: GitlabCachedSummary? {
        guard case let .gitlab(summary)? = link.cachedSummary() else { return nil }
        return summary
    }
}
