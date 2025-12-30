import SwiftUI

struct TaskDetailView: View {
    let task: ApiTask
    let detailState: TaskDetailState
    let externalLinksState: ExternalLinksState
    let onRefreshLinks: (ExternalLinkProvider) -> Void
    let onCopyBranch: (String) -> Void
    let onCopyLink: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    header

                    if isSingleColumn(for: proxy.size.width) {
                        metadataColumn
                        externalLinksSection
                    } else {
                        twoColumnLayout(totalWidth: proxy.size.width)
                    }

                    annotationsSection
                    historySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onExitCommand {
                onClose()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top) {
                Text(task.summary)
                    .font(.system(size: DesignTokens.TypeScale.title, weight: .bold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                    .lineLimit(2)
                Spacer()
                Text(task.status.uppercased())
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            .fill(ThemeManager.current.surface1)
                    )
            }

            if detailLoading {
                Text("Loading details…")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)
            } else if let error = detailError {
                Text(error)
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.red)
            }
        }
    }

    private var externalLinksSection: some View {
        DetailSection(title: "External Links") {
            if externalLinksLoading {
                Text("Loading links…")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)
            } else if let error = externalLinksError {
                Text(error)
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.red)
            }

            ExternalLinksProviderSection(
                title: "GitLab",
                icon: AssetIcon.gitlab(),
                useOriginalIcon: true,
                isRefreshing: externalLinksState.refreshingProviders.contains(.gitlab),
                links: externalLinksForTask.filter { $0.provider.lowercased() == ExternalLinkProvider.gitlab.rawValue },
                onRefresh: { onRefreshLinks(.gitlab) },
                onCopyBranch: onCopyBranch,
                onCopyLink: onCopyLink
            )

            ExternalLinksProviderSection(
                title: "Jira",
                icon: AssetIcon.jira(),
                useOriginalIcon: true,
                isRefreshing: externalLinksState.refreshingProviders.contains(.jira),
                links: externalLinksForTask.filter { $0.provider.lowercased() == ExternalLinkProvider.jira.rawValue },
                onRefresh: { onRefreshLinks(.jira) },
                onCopyBranch: onCopyBranch,
                onCopyLink: onCopyLink
            )
        }
    }

    private var metadataColumn: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            DetailSection(title: "Overview") {
                DetailRow(label: "UUID", value: shortUUID(task.uuid), helpText: task.uuid)
                DetailRow(label: "Project", value: task.project ?? "None", helpText: nil)
                DetailRow(label: "Tags", value: task.tags.isEmpty ? "None" : task.tags.joined(separator: ", "), helpText: nil)
                DetailRow(label: "Urgency", value: task.urgency.map(String.init) ?? "None", helpText: nil)
            }

            DetailSection(title: "Dates") {
                let created = formattedDate(task.dateCreated)
                DetailRow(label: "Created", value: created.display, helpText: created.help)

                let completed = formattedOptionalDate(task.dateCompleted, emptyLabel: "Not completed")
                DetailRow(label: "Completed", value: completed.display, helpText: completed.help)

                let due = formattedOptionalDate(task.dateDue, emptyLabel: "Not set")
                DetailRow(label: "Due", value: due.display, helpText: due.help)
            }
        }
    }

    private func twoColumnLayout(totalWidth: CGFloat) -> some View {
        let availableWidth = max(0, totalWidth - TaskDetailLayout.columnSpacing)
        let leftWidth = availableWidth * TaskDetailLayout.leftColumnFraction
        let rightWidth = availableWidth * TaskDetailLayout.rightColumnFraction

        return HStack(alignment: .top, spacing: TaskDetailLayout.columnSpacing) {
            metadataColumn
                .frame(width: leftWidth, alignment: .leading)

            externalLinksSection
                .frame(width: rightWidth, alignment: .leading)
        }
    }

    private func isSingleColumn(for width: CGFloat) -> Bool {
        width < TaskDetailLayout.collapseWidth
    }

    private var annotationsSection: some View {
        DetailSection(title: "Annotations") {
            let annotations = sortedAnnotations(detailForTask?.annotations ?? [])
            if annotations.isEmpty {
                Text("No annotations")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ForEach(annotations) { annotation in
                        TimelineRow(
                            timestamp: annotation.time,
                            value: annotation.value
                        )
                    }
                }
            }
        }
    }

    private var historySection: some View {
        DetailSection(title: "History") {
            let history = sortedHistory(detailForTask?.history ?? [])
            if history.isEmpty {
                Text("No history yet")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ForEach(history) { entry in
                        TimelineRow(
                            timestamp: entry.datetime,
                            value: entry.value
                        )
                    }
                }
            }
        }
    }

    private func shortUUID(_ value: String) -> String {
        let prefix = value.prefix(8)
        return "\(prefix)…"
    }

    private func formattedDate(_ value: String) -> (display: String, help: String?) {
        let display = RelativeDateFormatter.description(for: value)
        return (display, value)
    }

    private func formattedOptionalDate(_ value: String?, emptyLabel: String) -> (display: String, help: String?) {
        guard let value else {
            return (emptyLabel, nil)
        }
        return formattedDate(value)
    }

    private func sortedAnnotations(_ items: [TaskAnnotationDto]) -> [TaskAnnotationDto] {
        items.sorted { lhs, rhs in
            guard let left = RelativeDateFormatter.date(from: lhs.time),
                  let right = RelativeDateFormatter.date(from: rhs.time) else {
                return lhs.time > rhs.time
            }
            return left > right
        }
    }

    private func sortedHistory(_ items: [TaskHistoryDto]) -> [TaskHistoryDto] {
        items.sorted { lhs, rhs in
            guard let left = RelativeDateFormatter.date(from: lhs.datetime),
                  let right = RelativeDateFormatter.date(from: rhs.datetime) else {
                return lhs.datetime > rhs.datetime
            }
            return left > right
        }
    }

    private var detailForTask: ApiTaskDetail? {
        guard detailState.taskUUID == task.uuid,
              let detail = detailState.detail,
              detail.uuid == task.uuid else {
            return nil
        }
        return detail
    }

    private var detailLoading: Bool {
        detailState.isLoading && detailState.taskUUID == task.uuid
    }

    private var detailError: String? {
        guard detailState.taskUUID == task.uuid else { return nil }
        return detailState.errorMessage
    }

    private var externalLinksForTask: [ExternalLinkDto] {
        guard externalLinksState.taskUUID == task.uuid else { return [] }
        return externalLinksState.links
    }

    private var externalLinksLoading: Bool {
        externalLinksState.isLoading && externalLinksState.taskUUID == task.uuid
    }

    private var externalLinksError: String? {
        guard externalLinksState.taskUUID == task.uuid else { return nil }
        return externalLinksState.errorMessage
    }
}

private enum TaskDetailLayout {
    static let leftColumnFraction: CGFloat = 0.3
    static let rightColumnFraction: CGFloat = 0.7
    static let columnSpacing: CGFloat = DesignTokens.Spacing.lg
    static let collapseWidth: CGFloat = 760
}

private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title.uppercased())
                .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
            content
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(ThemeManager.current.surface0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(ThemeManager.current.surface1.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct ExternalLinksProviderSection: View {
    let title: String
    let icon: Image?
    let useOriginalIcon: Bool
    let isRefreshing: Bool
    let links: [ExternalLinkDto]
    let onRefresh: () -> Void
    let onCopyBranch: (String) -> Void
    let onCopyLink: (String) -> Void
    @State private var isHoveringRefresh = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let icon {
                    icon
                        .resizable()
                        .renderingMode(useOriginalIcon ? .original : .template)
                        .foregroundColor(useOriginalIcon ? nil : ThemeManager.current.subtext0)
                        .frame(width: 14, height: 14)
                }
                Text(title)
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                Spacer()
                if !links.isEmpty {
                    Button(action: onRefresh) {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Refresh")
                                .underline(isHoveringRefresh)
                        }
                    }
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                    .foregroundColor(isHoveringRefresh ? ThemeManager.current.subtext1 : ThemeManager.current.subtext0)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringRefresh = hovering
                    }
                    .buttonStyle(QuietRefreshButtonStyle(isHovering: isHoveringRefresh))
                    .disabled(isRefreshing)
                }
            }

            if links.isEmpty {
                Text("No links yet")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ForEach(links, id: \.id) { link in
                        ExternalLinkRow(
                            link: link,
                            onCopyBranch: onCopyBranch,
                            onCopyLink: onCopyLink
                        )
                    }
                }
            }
        }
    }
}

private struct QuietRefreshButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

private struct ExternalLinkRow: View {
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
                            .buttonStyle(QuietTextButtonStyle(isHovering: isHoveringTitle))
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
                            .buttonStyle(QuietTextButtonStyle(isHovering: isHoveringBranch))
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
        _ = openURL(url)
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
            .buttonStyle(QuietTextButtonStyle(isHovering: isHoveringLinkCopy))
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

private struct LinkStatusBadge: View {
    let state: ExternalLinkSyncState
    let timestamp: String?
    var compact: Bool = false

    var body: some View {
        Text(label)
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
            .padding(.horizontal, compact ? DesignTokens.Spacing.xs : DesignTokens.Spacing.sm)
            .padding(.vertical, compact ? 2 : 4)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(color.opacity(0.2))
            )
            .foregroundColor(color)
            .help(helpText ?? "")
    }

    private var label: String {
        switch state {
        case .pending:
            return "Pending"
        case .error:
            return "Error"
        case .synced(let date):
            return "Synced \(RelativeDateFormatter.description(for: date, now: Date(), calendar: .current))"
        case .stale(let date):
            return "Stale \(RelativeDateFormatter.description(for: date, now: Date(), calendar: .current))"
        }
    }

    private var helpText: String? {
        switch state {
        case .error(let message):
            return message
        default:
            return timestamp
        }
    }

    private var color: Color {
        switch state {
        case .pending:
            return ThemeManager.current.subtext0
        case .synced:
            return ThemeManager.current.green
        case .stale:
            return ThemeManager.current.yellow
        case .error:
            return ThemeManager.current.red
        }
    }
}

private struct QuietTextButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct TimelineRow: View {
    let timestamp: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Text(RelativeDateFormatter.description(for: timestamp))
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 90, alignment: .leading)
                .help(timestamp)
            Text(value)
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.text)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(ThemeManager.current.surface1.opacity(0.6))
        )
    }
}

#Preview {
    TaskDetailView(
        task: MockApiClient.sampleTasks[0],
        detailState: TaskDetailState(taskUUID: MockApiClient.sampleTaskDetail.uuid, detail: MockApiClient.sampleTaskDetail),
        externalLinksState: ExternalLinksState(
            taskUUID: MockApiClient.sampleTaskDetail.uuid,
            links: MockApiClient.sampleExternalLinks
        ),
        onRefreshLinks: { _ in },
        onCopyBranch: { _ in },
        onCopyLink: { _ in },
        onClose: {}
    )
        .padding(24)
        .frame(width: 600, height: 400)
        .background(ThemeManager.current.base)
}
