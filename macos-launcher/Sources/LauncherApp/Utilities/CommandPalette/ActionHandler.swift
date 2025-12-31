import Foundation

/// Handles command palette actions and builds submenus.
///
/// This class is responsible for wiring action handlers to the command palette
/// and managing the integration between the palette and the LauncherViewModel.
@MainActor
final class CommandPaletteActionHandler: CommandPaletteActionHandling {
    private weak var viewModel: LauncherViewModel?
    private let apiClient: ApiClientProtocol

    init(viewModel: LauncherViewModel, apiClient: ApiClientProtocol) {
        self.viewModel = viewModel
        self.apiClient = apiClient
    }

    // MARK: - CommandPaletteActionHandling

    func buildReportMenu(reports: [ReportSummary], currentReportName: String?) -> CommandPaletteMenu {
        let items: [CommandPaletteItem] = reports.map { report in
            let isCurrent = report.name == currentReportName
            let subtitle = report.filters.isEmpty ? "No filters" : report.filters.joined(separator: " • ")

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
        // Start loading suggestions asynchronously
        Task { [weak self] in
            await self?.loadGitlabSuggestions(taskUUID: taskUUID)
        }

        // Return empty menu initially - items will be added when loaded
        let section = CommandPaletteSection(id: "gitlab", title: nil, items: [])
        return CommandPaletteMenu(
            id: "add-gitlab",
            title: "Add GitLab Link",
            sections: [section]
        )
    }

    func buildJiraMenu(taskUUID: String) -> CommandPaletteMenu {
        // Start loading suggestions asynchronously
        Task { [weak self] in
            await self?.loadJiraSuggestions(taskUUID: taskUUID)
        }

        // Return empty menu initially - items will be added when loaded
        let section = CommandPaletteSection(id: "jira", title: nil, items: [])
        return CommandPaletteMenu(
            id: "add-jira",
            title: "Add Jira Link",
            sections: [section]
        )
    }

    // MARK: - Private Methods

    private func loadGitlabSuggestions(taskUUID: String) async {
        guard let viewModel else { return }

        viewModel.commandPalette.isLoading = true
        defer { viewModel.commandPalette.isLoading = false }

        do {
            let suggestions = try await apiClient.fetchRecentGitlabMergeRequests(limit: 20)
            let items = buildGitlabItems(suggestions: suggestions, taskUUID: taskUUID)

            // Update the current menu with the loaded items
            if !items.isEmpty {
                let section = CommandPaletteSection(id: "gitlab", title: nil, items: items)
                let menu = CommandPaletteMenu(
                    id: "add-gitlab",
                    title: "Add GitLab Link",
                    sections: [section]
                )
                // Replace current menu on stack
                viewModel.commandPalette.navigationStack.pop()
                viewModel.commandPalette.navigationStack.push(menu)
            }
        } catch {
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

            // Update the current menu with the loaded items
            if !items.isEmpty {
                let section = CommandPaletteSection(id: "jira", title: nil, items: items)
                let menu = CommandPaletteMenu(
                    id: "add-jira",
                    title: "Add Jira Link",
                    sections: [section]
                )
                // Replace current menu on stack
                viewModel.commandPalette.navigationStack.pop()
                viewModel.commandPalette.navigationStack.push(menu)
            }
        } catch {
            viewModel.showToast(message: "Failed to load Jira suggestions: \(error.localizedDescription)")
        }
    }

    private func buildGitlabItems(
        suggestions: [GitlabMergeRequestSuggestion],
        taskUUID: String
    ) -> [CommandPaletteItem] {
        suggestions.map { mr in
            .suggestion(
                CommandPaletteSuggestionItem(
                    id: "gitlab-\(mr.id)",
                    title: mr.title,
                    subtitle: "MR !\(mr.id) • \(mr.projectPath)",
                    icon: .gitlab,
                    metadata: .gitlab(mr),
                    handler: { [weak self] in
                        self?.handleGitlabSelection(mr: mr, taskUUID: taskUUID)
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

    private func handleGitlabSelection(mr: GitlabMergeRequestSuggestion, taskUUID: String) {
        guard let viewModel else { return }

        Task {
            do {
                _ = try await apiClient.addExternalLink(
                    taskUUID: taskUUID,
                    url: mr.webURL
                )
                viewModel.showToast(message: "GitLab link added")
                viewModel.loadExternalLinks(taskUUID: taskUUID)
            } catch {
                viewModel.showToast(message: "Failed to add link: \(error.localizedDescription)")
            }
        }
        viewModel.closeCommandPalette()
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
}
