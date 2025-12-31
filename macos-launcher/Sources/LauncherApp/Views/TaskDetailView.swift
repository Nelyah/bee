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
            // Back button
            HStack {
                Button {
                    onClose()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                        Text("Back")
                            .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    }
                    .foregroundColor(ThemeManager.current.subtext0)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }

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
                DetailRow(
                    label: "Tags",
                    value: task.tags.isEmpty ? "None" : task.tags.joined(separator: ", "),
                    helpText: nil
                )
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
                  let right = RelativeDateFormatter.date(from: rhs.time)
            else {
                return lhs.time > rhs.time
            }
            return left > right
        }
    }

    private func sortedHistory(_ items: [TaskHistoryDto]) -> [TaskHistoryDto] {
        items.sorted { lhs, rhs in
            guard let left = RelativeDateFormatter.date(from: lhs.datetime),
                  let right = RelativeDateFormatter.date(from: rhs.datetime)
            else {
                return lhs.datetime > rhs.datetime
            }
            return left > right
        }
    }

    private var detailForTask: ApiTaskDetail? {
        guard detailState.taskUUID == task.uuid,
              let detail = detailState.detail,
              detail.uuid == task.uuid
        else {
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

#Preview {
    TaskDetailView(
        task: MockApiClient.sampleTasks[0],
        detailState: TaskDetailState(
            taskUUID: MockApiClient.sampleTaskDetail.uuid,
            detail: MockApiClient.sampleTaskDetail
        ),
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
