import SwiftUI

/// Displays an external link (GitLab MR, Jira issue, etc.) with status and actions.
struct ExternalLinkRow: View {
    let link: ExternalLinkDto
    let onCopyBranch: (String) -> Void
    let onCopyLink: (String) -> Void
    @Environment(\.openURL) private var openURL
    @State private var isHoveringTitle = false
    @State private var isHoveringBranch = false
    @State private var isHoveringLinkCopy = false
    @State private var isHoveringLink = false

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
                            Button(action: openMergeRequest) {
                                Text(gitlabTitleLine)
                                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                                    .foregroundColor(isHoveringTitle ? ThemeManager.current.subtext1 : ThemeManager.current.text)
                                    .underline(isHoveringTitle)
                            }
                            .buttonStyle(QuietButtonStyle(isHovering: isHoveringTitle))
                            .onHover { hovering in
                                isHoveringTitle = hovering
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
                            LinkStatusBadge(state: link.syncState(), timestamp: link.lastSyncedAt, compact: true)
                        }

                        if let branch = gitlabBranchLine {
                            Button(action: { onCopyBranch(branch) }) {
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
                                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .monospaced))
                                        .foregroundColor(ThemeManager.current.text)
                                }
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                        .fill(ThemeManager.current.surface2.opacity(isHoveringBranch ? 0.85 : 0.7))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                        .stroke(ThemeManager.current.surface1.opacity(0.6), lineWidth: 1)
                                )
                            }
                            .buttonStyle(QuietButtonStyle(isHovering: isHoveringBranch))
                            .onHover { hovering in
                                isHoveringBranch = hovering
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
                            LinkStatusBadge(state: link.syncState(), timestamp: link.lastSyncedAt, compact: true)
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
                Link(destination: url) {
                    Text(link.url)
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                        .foregroundColor(isHoveringLink ? ThemeManager.current.subtext1 : ThemeManager.current.subtext0)
                        .underline(isHoveringLink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .onHover { hovering in
                    isHoveringLink = hovering
                }
            } else {
                Text(link.url)
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button(action: { onCopyLink(link.url) }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
                    .foregroundColor(isHoveringLinkCopy ? ThemeManager.current.subtext1 : ThemeManager.current.subtext0)
            }
            .buttonStyle(QuietButtonStyle(isHovering: isHoveringLinkCopy))
            .onHover { hovering in
                isHoveringLinkCopy = hovering
            }
            .help("Copy link")
        }
    }

    private var titleText: String {
        if let summary = link.cachedSummary() {
            switch summary {
            case .gitlab(let gitlab):
                return gitlab.title
            case .jira(let jira):
                return jira.summary
            }
        }
        return link.externalKey
    }

    private var detailText: String {
        if let summary = cachedSummary {
            switch summary {
            case .gitlab(let gitlab):
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
                    case .unknown(let value):
                        parts.append(value.capitalized)
                    }
                }
                if let pipeline = gitlab.pipelineStatus {
                    parts.append(GitlabPipelineStatus.fromRaw(pipeline).label)
                }
                return parts.joined(separator: " • ")
            case .jira(let jira):
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
        guard case .gitlab(let gitlab)? = cachedSummary else { return nil }
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
                            ThemeManager.current.surface2.opacity(0.35)
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
           let last = link.externalKey.split(separator: ":").last {
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
        case .unknown(let value):
            return value.capitalized
        }
    }

    private var gitlabBranchLine: String? {
        gitlabSummary?.sourceBranch
    }

    private var middleDot: some View {
        Text("•")
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
            .foregroundColor(ThemeManager.current.subtext0)
    }
}
