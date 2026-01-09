import SwiftUI

/// A section displaying external links for a specific provider (GitLab, Jira, etc.)
struct ExternalLinksProviderSection: View {
    let title: String
    let icon: Image?
    let useOriginalIcon: Bool
    let isRefreshing: Bool
    let links: [ExternalLinkDto]
    let onRefresh: () -> Void
    let onCopyBranch: (String) -> Void
    let onCopyLink: (String) -> Void
    /// The ID of the currently keyboard-focused link (if any).
    var focusedLinkId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.small) {
                if let icon {
                    icon
                        .resizable()
                        .renderingMode(useOriginalIcon ? .original : .template)
                        .foregroundColor(useOriginalIcon ? nil : ThemeManager.current.subtext0)
                        .frame(width: DesignTokens.IconSize.medium, height: DesignTokens.IconSize.medium)
                }
                Text(title)
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                Spacer()
                if !links.isEmpty {
                    HoverableButton(
                        action: onRefresh,
                        pressedOpacity: 0.6,
                        pressedScale: 0.96,
                        animationDuration: 0.15
                    ) { isHovering in
                        Group {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Refresh")
                                    .underline(isHovering)
                            }
                        }
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current.subtext0)
                    }
                    .contentShape(Rectangle())
                    .disabled(isRefreshing)
                }
            }

            if links.isEmpty {
                Text("—")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.overlay0)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    ForEach(links, id: \.id) { link in
                        let focusableItem: DetailFocusableItem = link.provider.lowercased() == "gitlab"
                            ? .gitlabMR(link)
                            : .jiraIssue(link)
                        ExternalLinkRow(
                            link: link,
                            onCopyBranch: onCopyBranch,
                            onCopyLink: onCopyLink,
                            isKeyboardFocused: link.id == focusedLinkId
                        )
                        .navigationRegistrable(focusableItem)
                    }
                }
            }
        }
    }
}
