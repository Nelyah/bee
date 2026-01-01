import SwiftUI

/// Displays GitLab MR-specific content within an ExternalLinkRow.
///
/// This view handles the rich GitLab MR display including:
/// - MR state icon (open/merged/closed)
/// - Title with IID prefix
/// - State, comments count, and approval status
/// - Source branch with copy action
struct GitLabLinkRowContent: View {
    let link: ExternalLinkDto
    let summary: GitlabCachedSummary
    let onCopyBranch: (String) -> Void
    let onCopyLink: (String) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
            statusIconView(name: statusIconName)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
                // Title line
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
                    HoverableButton(action: openMergeRequest) { isHovering in
                        Text(titleLine)
                            .font(.system(
                                size: DesignTokens.TypeScale.bodySm,
                                weight: .semibold,
                                design: .rounded
                            ))
                            .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current.text)
                            .underline(isHovering)
                    }
                    Spacer()
                }

                // State, comments, link, approval
                HStack(spacing: DesignTokens.Spacing.small) {
                    Text(stateText)
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                        .foregroundColor(ThemeManager.current.subtext0)
                    middleDot
                    Label("\(summary.comments ?? 0)", systemImage: "bubble.left")
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                        .foregroundColor(ThemeManager.current.subtext0)
                    middleDot
                    linkLine
                    Spacer()
                    approvalBadge
                }

                // Branch line (if available)
                if let branch = summary.sourceBranch {
                    HoverableButton(action: { onCopyBranch(branch) }, label: { isHovering in
                        HStack(spacing: DesignTokens.Spacing.extraSmall) {
                            if let icon = AssetIcon.image(named: "git-branch") {
                                icon
                                    .resizable()
                                    .renderingMode(.original)
                                    .scaledToFit()
                                    .frame(width: DesignTokens.IconSize.small, height: DesignTokens.IconSize.small)
                            } else {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
                                    .foregroundColor(ThemeManager.current.subtext0)
                            }
                            Text(branch)
                                .font(.system(
                                    size: DesignTokens.TypeScale.caption,
                                    weight: .semibold,
                                    design: .monospaced
                                ))
                                .foregroundColor(ThemeManager.current.text)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.small)
                        .padding(.vertical, DesignTokens.Spacing.extraSmall)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                                .fill(ThemeManager.current.surface2.opacity(isHovering ? 0.85 : 0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                                .stroke(ThemeManager.current.surface1.opacity(0.6), lineWidth: 1)
                        )
                    })
                }
            }
        }
    }

    // MARK: - Actions

    private func openMergeRequest() {
        guard let url = URL(string: link.url) else { return }
        openURL(url)
    }

    // MARK: - Computed Properties

    private var statusIconName: String {
        guard let state = summary.state else { return "pr-open" }
        return GitlabMergeRequestState.fromRaw(state).iconName
    }

    private var titleLine: String {
        let id = iidText
        if let id {
            return "\(id) \(summary.title)"
        }
        return summary.title
    }

    private var iidText: String? {
        if let iid = summary.iid {
            return "!\(iid)"
        }
        if link.externalKey.contains(":"),
           let last = link.externalKey.split(separator: ":").last {
            return "!\(last)"
        }
        return nil
    }

    private var stateText: String {
        guard let state = summary.state else { return "Open" }
        switch GitlabMergeRequestState.fromRaw(state) {
        case .opened:
            return "Open"
        case .merged:
            return "Merged"
        case .closed:
            return "Closed"
        case let .unknown(value):
            return value.capitalized
        }
    }

    // MARK: - Subviews

    private func statusIconView(name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                .fill(ThemeManager.current.surface2.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                        .stroke(ThemeManager.current.surface1.opacity(0.5), lineWidth: 1)
                )
            if let icon = AssetIcon.image(named: name) {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .padding(DesignTokens.Spacing.small - 2)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .padding(DesignTokens.Spacing.small)
                    .foregroundColor(ThemeManager.current.yellow)
            }
        }
        .frame(width: DesignTokens.IconSize.large, height: DesignTokens.IconSize.large)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ThemeManager.current.surface2.opacity(0.65),
                            ThemeManager.current.surface2.opacity(0.35),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .opacity(0.5)
        )
        .shadow(color: ThemeManager.current.surface2.opacity(0.35), radius: 4, x: 0, y: 2)
        .zIndex(1)
    }

    private var linkLine: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            if let url = URL(string: link.url) {
                HoverableLink { isHovering in
                    Link(destination: url) {
                        Text(link.url)
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                            .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current.subtext0)
                            .underline(isHovering)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            } else {
                Text(link.url)
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HoverableButton(action: { onCopyLink(link.url) }, label: { isHovering in
                Image(systemName: "doc.on.doc")
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
                    .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current.subtext0)
            })
            .help("Copy link")
        }
    }

    private var approvalBadge: some View {
        let text: String
        let color: Color
        switch summary.approved {
        case .some(true):
            text = "Approved"
            color = ThemeManager.current.green
        case .some(false):
            text = "Needs approval"
            color = ThemeManager.current.yellow
        case .none:
            text = "Approval unknown"
            color = ThemeManager.current.subtext0
        }

        return Text(text)
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                    .fill(color.opacity(0.2))
            )
            .foregroundColor(color)
    }

    private var middleDot: some View {
        Text("•")
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
            .foregroundColor(ThemeManager.current.subtext0)
    }
}
