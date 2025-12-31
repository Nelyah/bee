import SwiftUI

/// Displays an external link (GitLab MR, Jira issue, etc.) with status and actions.
struct ExternalLinkRow: View {
    let link: ExternalLinkDto
    let onCopyBranch: (String) -> Void
    let onCopyLink: (String) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                if let statusIconName = gitlabStatusIconName {
                    statusIconView(name: statusIconName)
                } else if gitlabSummary != nil {
                    statusIconView(name: "pr-open")
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    if isGitlabRow {
                        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                            HoverableButton(action: openMergeRequest) { isHovering in
                                Text(gitlabTitleLine)
                                    .font(.system(
                                        size: DesignTokens.TypeScale.bodySm,
                                        weight: .semibold,
                                        design: .rounded
                                    ))
                                    .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current
                                        .text)
                                    .underline(isHovering)
                            }
                            Spacer()
                        }

                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Text(gitlabStateText)
                                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                                .foregroundColor(ThemeManager.current.subtext0)
                            middleDot
                            Label("\(gitlabCommentsCount ?? 0)", systemImage: "bubble.left")
                                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                                .foregroundColor(ThemeManager.current.subtext0)
                            middleDot
                            mrLinkLine
                            Spacer()
                            approvalBadge
                        }

                        if let branch = gitlabBranchLine {
                            HoverableButton(action: { onCopyBranch(branch) }) { isHovering in
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    if let icon = AssetIcon.image(named: "git-branch") {
                                        icon
                                            .resizable()
                                            .renderingMode(.original)
                                            .scaledToFit()
                                            .frame(width: 12, height: 12)
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
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                        .fill(ThemeManager.current.surface2.opacity(isHovering ? 0.85 : 0.7))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                        .stroke(ThemeManager.current.surface1.opacity(0.6), lineWidth: 1)
                                )
                            }
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                            Text(titleText)
                                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                                .foregroundColor(ThemeManager.current.text)
                            Spacer()
                        }

                        HStack(spacing: DesignTokens.Spacing.sm) {
                            if !detailText.isEmpty {
                                Text(detailText)
                                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                                    .foregroundColor(ThemeManager.current.subtext0)
                            }
                            Spacer()
                        }
                    }
                }
            }

            if !isGitlabRow {
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
        .padding(.top, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.bottom, DesignTokens.Spacing.sm)
        .overlay(alignment: .topTrailing) {
            LinkStatusBadge(state: link.syncState(), timestamp: link.lastSyncedAt, compact: true)
                .padding(.top, DesignTokens.Spacing.xs)
                .padding(.trailing, DesignTokens.Spacing.xs)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(ThemeManager.current.surface1.opacity(0.7))
        )
    }

    private func openMergeRequest() {
        guard let url = URL(string: link.url) else { return }
        openURL(url)
    }

    private var mrLinkLine: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
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

            HoverableButton(action: { onCopyLink(link.url) }) { isHovering in
                Image(systemName: "doc.on.doc")
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
                    .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current.subtext0)
            }
            .help("Copy link")
        }
    }

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
        if let summary = cachedSummary {
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
                if let status = jira.status {
                    return status
                }
                return ""
            }
        }
        return ""
    }

    private var cachedSummary: ExternalLinkCachedSummary? {
        link.cachedSummary()
    }

    private var gitlabSummary: GitlabCachedSummary? {
        guard case let .gitlab(gitlab)? = cachedSummary else { return nil }
        return gitlab
    }

    private var gitlabStatusIconName: String? {
        guard let state = gitlabSummary?.state else { return nil }
        return GitlabMergeRequestState.fromRaw(state).iconName
    }

    private func statusIconView(name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ThemeManager.current.surface2.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ThemeManager.current.surface1.opacity(0.5), lineWidth: 1)
                )
            if let icon = AssetIcon.image(named: name) {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .padding(6)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .padding(8)
                    .foregroundColor(ThemeManager.current.yellow)
            }
        }
        .frame(width: 34, height: 34)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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

    private var gitlabCommentsCount: Int? {
        gitlabSummary?.comments
    }

    private var isGitlabRow: Bool {
        gitlabSummary != nil
    }

    private var gitlabTitleLine: String {
        let id = gitlabIidText
        if let id {
            return "\(id) \(gitlabSummary?.title ?? link.externalKey)"
        }
        return gitlabSummary?.title ?? link.externalKey
    }

    private var gitlabIidText: String? {
        if let iid = gitlabSummary?.iid {
            return "!\(iid)"
        }
        if link.externalKey.contains(":"),
           let last = link.externalKey.split(separator: ":").last
        {
            return "!\(last)"
        }
        return nil
    }

    private var gitlabStateText: String {
        guard let state = gitlabSummary?.state else { return "Open" }
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

    private var gitlabBranchLine: String? {
        gitlabSummary?.sourceBranch
    }

    private var approvalBadge: some View {
        let text: String
        let color: Color
        switch gitlabSummary?.approved {
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
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
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
