import Foundation
import OSLog

/// Handles command palette actions and builds submenus.
///
/// This class is responsible for wiring action handlers to the command palette
/// and managing the integration between the palette and the LauncherViewModel.
@MainActor
final class CommandPaletteActionHandler: CommandPaletteActionHandling {
    private weak var viewModel: LauncherViewModel?
    private let apiClient: ApiClientProtocol
    private let logger = Logger(subsystem: "bee.macos-launcher", category: "command-palette")

    init(viewModel: LauncherViewModel, apiClient: ApiClientProtocol) {
        self.viewModel = viewModel
        self.apiClient = apiClient
    }

    // MARK: - CommandPaletteActionHandling

    func buildReportMenu(reports: [ReportSummary], currentReportName: String?) -> CommandPaletteMenu {
        let items: [CommandPaletteItem] = reports.map { report in
            let isCurrent = report.name == currentReportName
            let subtitle = CriteriaChipBuilder.reportSubtitle(for: report)

            return .suggestion(
                CommandPaletteSuggestionItem(
                    id: "report-\(report.name)",
                    title: report.name,
                    subtitle: isCurrent ? "\(subtitle) ✓" : subtitle,
                    icon: .system("doc.text"),
                    metadata: .report(report),
                    handler: { [weak self] in
                        self?.viewModel?.selectReport(report.name)
                        self?.viewModel?.closeCommandPalette()
                    }
                )
            )
        }

        let section = CommandPaletteSection(id: "reports", title: nil, items: items)
        return CommandPaletteMenu(
            id: "select-report",
            title: "Select Report",
            sections: [section]
        )
    }

    func buildGitlabMenu(taskUUID: String) -> CommandPaletteMenu {
        logger.info("buildGitlabMenu called for task: \(taskUUID, privacy: .public)")

        // Start loading suggestions asynchronously
        Task { [weak self] in
            await self?.loadGitlabSuggestions(taskUUID: taskUUID)
        }

        // URL entry action (always visible at top, pinned so it's not filtered out)
        let urlEntryItem = CommandPaletteActionItem(
            id: "gitlab-url-entry",
            title: "Enter GitLab URL...",
            subtitle: "Paste any merge request or issue URL",
            icon: .system("link"),
            isPinned: true,
            handler: { [weak self] in
                self?.handleGitlabUrlEntry(taskUUID: taskUUID)
            }
        )

        let urlSection = CommandPaletteSection(id: "gitlab-url", title: nil, items: [.action(urlEntryItem)])
        let suggestionsSection = CommandPaletteSection(id: "gitlab", title: "Recent", items: [])

        return CommandPaletteMenu(
            id: "add-gitlab",
            title: "Add GitLab Link",
            sections: [urlSection, suggestionsSection]
        )
    }

    func buildJiraMenu(taskUUID: String) -> CommandPaletteMenu {
        // Start loading suggestions asynchronously
        Task { [weak self] in
            await self?.loadJiraSuggestions(taskUUID: taskUUID)
        }

        // URL entry action (always visible at top, pinned so it's not filtered out)
        let urlEntryItem = CommandPaletteActionItem(
            id: "jira-url-entry",
            title: "Enter Jira URL...",
            subtitle: "Paste any issue URL",
            icon: .system("link"),
            isPinned: true,
            handler: { [weak self] in
                self?.handleJiraUrlEntry(taskUUID: taskUUID)
            }
        )

        let urlSection = CommandPaletteSection(id: "jira-url", title: nil, items: [.action(urlEntryItem)])
        let suggestionsSection = CommandPaletteSection(id: "jira", title: "Recent", items: [])

        return CommandPaletteMenu(
            id: "add-jira",
            title: "Add Jira Link",
            sections: [urlSection, suggestionsSection]
        )
    }

    func clearProjectScope() {
        viewModel?.clearProjectScope()
        viewModel?.closeCommandPalette()
    }

    func showSaveReportSheet() {
        viewModel?.closeCommandPalette()
        viewModel?.showingSaveReportSheet = true
    }

    func deleteUserReport(name: String) {
        guard let viewModel else { return }

        Task {
            do {
                try await apiClient.deleteUserReport(name: name)
                viewModel.showToast(message: "Report '\(name)' deleted", icon: .success)
                // Reload config to refresh reports list
                await viewModel.refreshConfig()
            } catch {
                viewModel.showToast(message: "Failed to delete report: \(error.localizedDescription)")
            }
        }
        viewModel.closeCommandPalette()
    }

    func addAttachment() {
        viewModel?.closeCommandPalette()
        viewModel?.addAttachment()
    }

    func buildLinkTypeMenu(taskUUID: String) -> CommandPaletteMenu {
        // All 6 link types in order matching the plan
        let linkTypes: [LinkType] = [
            .blocking,
            .dependsOn,
            .parentOf,
            .childOf,
            .relatedTo,
            .duplicates,
        ]

        let items: [CommandPaletteItem] = linkTypes.map { linkType in
            .submenu(
                CommandPaletteSubmenuItem(
                    id: "link-type-\(linkType.rawValue)",
                    title: "\(linkType.displayName)...",
                    subtitle: linkTypeDescription(linkType),
                    icon: .system(linkType.iconName),
                    menuBuilder: { [weak self] in
                        self?.buildTaskSelectorMenu(linkType: linkType, sourceTaskUUID: taskUUID)
                            ?? CommandPaletteMenu(id: "empty", title: "", sections: [])
                    }
                )
            )
        }

        let section = CommandPaletteSection(id: "linkTypes", title: "Relationship Type", items: items)
        return CommandPaletteMenu(
            id: "link-type",
            title: "Link to Task",
            sections: [section]
        )
    }

    func buildTaskSelectorMenu(linkType: LinkType, sourceTaskUUID: String) -> CommandPaletteMenu {
        guard let viewModel else {
            return CommandPaletteMenu(id: "empty", title: "", sections: [])
        }

        // Get all tasks except the source task
        let availableTasks = viewModel.tasks.filter { $0.uuid != sourceTaskUUID }

        let items: [CommandPaletteItem] = availableTasks.map { task in
            .action(
                CommandPaletteActionItem(
                    id: "task-\(task.uuid)",
                    title: task.summary,
                    subtitle: task.project ?? "No project",
                    icon: .system("circle.fill"),
                    handler: { [weak self] in
                        self?.handleTaskLinkSelection(
                            linkType: linkType,
                            sourceTaskUUID: sourceTaskUUID,
                            targetTask: task
                        )
                    }
                )
            )
        }

        let section = CommandPaletteSection(
            id: "taskSelector",
            title: "Select Task to Link",
            items: items
        )
        return CommandPaletteMenu(
            id: "task-selector-\(linkType.rawValue)",
            title: linkType.displayName,
            sections: [section]
        )
    }

    // MARK: - Private Methods

    private func linkTypeDescription(_ linkType: LinkType) -> String {
        switch linkType {
        case .blocking:
            "This task blocks..."
        case .dependsOn:
            "This task depends on..."
        case .parentOf:
            "This task is parent of..."
        case .childOf:
            "This task is child of..."
        case .relatedTo:
            "Related tasks"
        case .duplicates:
            "This task duplicates..."
        }
    }

    private func handleTaskLinkSelection(
        linkType: LinkType,
        sourceTaskUUID: String,
        targetTask: ApiTask
    ) {
        guard let viewModel else { return }

        // Build property string for the modify action
        // The property syntax depends on link type
        let propertyKey = linkTypeToPropertyKey(linkType)
        let propertyValue = targetTask.uuid

        Task {
            do {
                // Use the action system to create the link via modify action
                let parseInput = "modify \(propertyKey):\(propertyValue)"
                let parsed = try await apiClient.parse(input: parseInput)

                // Run the action with the source task's UUID as filter
                // Note: Filter type must be "UuidFilter" (not "UUIDFilter") to match API expectations
                let filterValue: JSONValue = .object([
                    "type": .string("UuidFilter"),
                    "value": .object([
                        "uuid": .string(sourceTaskUUID),
                    ]),
                ])

                _ = try await apiClient.runAction(
                    action: "modify",
                    properties: parsed.properties,
                    filter: filterValue
                )

                viewModel.showToast(
                    message: "Linked to \"\(targetTask.summary)\"",
                    icon: .success
                )

                // Refresh task detail to show the new link
                viewModel.loadTaskDetail(taskUUID: sourceTaskUUID)
            } catch {
                viewModel.showToast(
                    message: "Failed to create link: \(error.localizedDescription)"
                )
            }
        }

        viewModel.closeCommandPalette()
    }

    private func linkTypeToPropertyKey(_ linkType: LinkType) -> String {
        switch linkType {
        case .dependsOn:
            "depends"
        case .blocking:
            "blocks"
        case .parentOf:
            "parent"
        case .childOf:
            "child"
        case .relatedTo:
            "related"
        case .duplicates:
            "duplicates"
        }
    }

    private func loadGitlabSuggestions(taskUUID: String) async {
        logger.info("loadGitlabSuggestions: starting for task \(taskUUID, privacy: .public)")

        guard let viewModel else {
            logger.error("loadGitlabSuggestions: viewModel is nil, aborting")
            return
        }

        viewModel.commandPalette.isLoading = true
        defer { viewModel.commandPalette.isLoading = false }

        do {
            logger.info("loadGitlabSuggestions: fetching from API...")
            let suggestions = try await apiClient.fetchRecentGitlabMergeRequests(limit: 20)
            logger.info("loadGitlabSuggestions: received \(suggestions.count) suggestions from API")

            let items = buildGitlabItems(suggestions: suggestions, taskUUID: taskUUID)
            logger.info("loadGitlabSuggestions: built \(items.count) menu items")

            // URL entry section (always present at top, pinned so it's not filtered out)
            let urlEntryItem = CommandPaletteActionItem(
                id: "gitlab-url-entry",
                title: "Enter GitLab URL...",
                subtitle: "Paste any merge request or issue URL",
                icon: .system("link"),
                isPinned: true,
                handler: { [weak self] in
                    self?.handleGitlabUrlEntry(taskUUID: taskUUID)
                }
            )
            let urlSection = CommandPaletteSection(id: "gitlab-url", title: nil, items: [.action(urlEntryItem)])

            // Suggestions section (may be empty)
            let suggestionsSection = CommandPaletteSection(
                id: "gitlab",
                title: items.isEmpty ? nil : "Recent",
                items: items
            )

            let menu = CommandPaletteMenu(
                id: "add-gitlab",
                title: "Add GitLab Link",
                sections: [urlSection, suggestionsSection]
            )

            // Replace current menu on stack
            let stackDepthBefore = viewModel.commandPalette.navigationStack.depth
            viewModel.commandPalette.navigationStack.pop()
            viewModel.commandPalette.navigationStack.push(menu)
            let stackDepthAfter = viewModel.commandPalette.navigationStack.depth
            let sectionCount = menu.sections.count
            logger.info(
                "loadGitlabSuggestions: nav stack (\(stackDepthBefore) -> \(stackDepthAfter)), \(sectionCount) sections"
            )
        } catch {
            logger.error("loadGitlabSuggestions: API error - \(error.localizedDescription, privacy: .public)")
            viewModel.showToast(message: "Failed to load GitLab suggestions: \(error.localizedDescription)")
        }
    }

    private func loadJiraSuggestions(taskUUID: String) async {
        guard let viewModel else { return }

        viewModel.commandPalette.isLoading = true
        defer { viewModel.commandPalette.isLoading = false }

        do {
            let suggestions = try await apiClient.fetchRecentJiraIssues(limit: 20, scope: .both)
            let items = buildJiraItems(suggestions: suggestions, taskUUID: taskUUID)

            // URL entry section (always present at top, pinned so it's not filtered out)
            let urlEntryItem = CommandPaletteActionItem(
                id: "jira-url-entry",
                title: "Enter Jira URL...",
                subtitle: "Paste any issue URL",
                icon: .system("link"),
                isPinned: true,
                handler: { [weak self] in
                    self?.handleJiraUrlEntry(taskUUID: taskUUID)
                }
            )
            let urlSection = CommandPaletteSection(id: "jira-url", title: nil, items: [.action(urlEntryItem)])

            // Suggestions section (may be empty)
            let suggestionsSection = CommandPaletteSection(
                id: "jira",
                title: items.isEmpty ? nil : "Recent",
                items: items
            )

            let menu = CommandPaletteMenu(
                id: "add-jira",
                title: "Add Jira Link",
                sections: [urlSection, suggestionsSection]
            )

            // Replace current menu on stack
            viewModel.commandPalette.navigationStack.pop()
            viewModel.commandPalette.navigationStack.push(menu)
        } catch {
            viewModel.showToast(message: "Failed to load Jira suggestions: \(error.localizedDescription)")
        }
    }

    private func buildGitlabItems(
        suggestions: [GitlabMergeRequestSuggestion],
        taskUUID: String
    ) -> [CommandPaletteItem] {
        suggestions.map { mergeRequest in
            .suggestion(
                CommandPaletteSuggestionItem(
                    id: "gitlab-\(mergeRequest.id)",
                    title: mergeRequest.title,
                    subtitle: "MR !\(mergeRequest.id) • \(mergeRequest.projectPath)",
                    icon: .gitlab,
                    metadata: .gitlab(mergeRequest),
                    handler: { [weak self] in
                        self?.handleGitlabSelection(mergeRequest: mergeRequest, taskUUID: taskUUID)
                    }
                )
            )
        }
    }

    private func buildJiraItems(
        suggestions: [JiraIssueSuggestion],
        taskUUID: String
    ) -> [CommandPaletteItem] {
        suggestions.map { issue in
            .suggestion(
                CommandPaletteSuggestionItem(
                    id: "jira-\(issue.key)",
                    title: issue.summary,
                    subtitle: "\(issue.key) • \(issue.status)",
                    icon: .jira,
                    metadata: .jira(issue),
                    handler: { [weak self] in
                        self?.handleJiraSelection(issue: issue, taskUUID: taskUUID)
                    }
                )
            )
        }
    }

    private func handleGitlabSelection(mergeRequest: GitlabMergeRequestSuggestion, taskUUID: String) {
        guard let viewModel else { return }

        Task {
            do {
                _ = try await apiClient.addExternalLink(
                    taskUUID: taskUUID,
                    url: mergeRequest.webURL
                )
                viewModel.showToast(message: "GitLab link added")
                viewModel.loadExternalLinks(taskUUID: taskUUID)
            } catch {
                viewModel.showToast(message: "Failed to add link: \(error.localizedDescription)")
            }
        }
        viewModel.closeCommandPalette()
    }

    private func handleGitlabUrlEntry(taskUUID: String) {
        guard let viewModel else { return }

        let query = viewModel.commandPalette.query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            viewModel.showToast(message: "Please enter a GitLab URL")
            return
        }

        viewModel.closeCommandPalette()

        Task {
            do {
                _ = try await apiClient.addExternalLink(taskUUID: taskUUID, url: query)
                viewModel.showToast(message: "GitLab link added", icon: .success)
                viewModel.loadExternalLinks(taskUUID: taskUUID)
            } catch {
                viewModel.showToast(message: "Failed to add link: \(error.localizedDescription)")
            }
        }
    }

    private func handleJiraSelection(issue: JiraIssueSuggestion, taskUUID: String) {
        guard let viewModel else { return }

        Task {
            do {
                _ = try await apiClient.addExternalLink(
                    taskUUID: taskUUID,
                    url: issue.webURL
                )
                viewModel.showToast(message: "Jira link added")
                viewModel.loadExternalLinks(taskUUID: taskUUID)
            } catch {
                viewModel.showToast(message: "Failed to add link: \(error.localizedDescription)")
            }
        }
        viewModel.closeCommandPalette()
    }

    private func handleJiraUrlEntry(taskUUID: String) {
        guard let viewModel else { return }

        let query = viewModel.commandPalette.query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            viewModel.showToast(message: "Please enter a Jira URL")
            return
        }

        viewModel.closeCommandPalette()

        Task {
            do {
                _ = try await apiClient.addExternalLink(taskUUID: taskUUID, url: query)
                viewModel.showToast(message: "Jira link added", icon: .success)
                viewModel.loadExternalLinks(taskUUID: taskUUID)
            } catch {
                viewModel.showToast(message: "Failed to add link: \(error.localizedDescription)")
            }
        }
    }
}
