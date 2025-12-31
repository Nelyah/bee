import Foundation

// MARK: - Action Handlers Protocol

/// Protocol for handling command palette actions.
///
/// Implementers provide handlers for building submenus and executing actions.
@MainActor
protocol CommandPaletteActionHandling {
    /// Builds a submenu for selecting reports
    func buildReportMenu(reports: [ReportSummary], currentReportName: String?) -> CommandPaletteMenu

    /// Builds a submenu for adding GitLab links
    func buildGitlabMenu(taskUUID: String) -> CommandPaletteMenu

    /// Builds a submenu for adding Jira links
    func buildJiraMenu(taskUUID: String) -> CommandPaletteMenu

    /// Clears the current project scope
    func clearProjectScope()

    /// Shows the save report sheet
    func showSaveReportSheet()

    /// Deletes a user report
    func deleteUserReport(name: String)
}

// MARK: - Actions Section Contributor

/// Contributes the main actions section to the command palette.
///
/// This section appears first and contains the primary palette actions:
/// - Select Report (always available)
/// - Add GitLab link (requires selected task)
/// - Add Jira link (requires selected task)
struct ActionsSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "actions" }
    var priority: Int { 0 }

    private let actionHandler: CommandPaletteActionHandling

    init(actionHandler: CommandPaletteActionHandling) {
        self.actionHandler = actionHandler
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        var items: [CommandPaletteItem] = []

        // Select Report (always available)
        items.append(
            .submenu(
                CommandPaletteSubmenuItem(
                    id: "select-report",
                    title: "Select Report",
                    subtitle: context.currentReportName,
                    icon: .system("doc.text"),
                    menuBuilder: { [actionHandler, context] in
                        actionHandler.buildReportMenu(
                            reports: context.availableReports,
                            currentReportName: context.currentReportName
                        )
                    }
                )
            )
        )

        // Add GitLab link (requires selected task)
        if context.hasSelectedTask, let taskUUID = context.selectedTaskUUID {
            items.append(
                .submenu(
                    CommandPaletteSubmenuItem(
                        id: "add-gitlab",
                        title: "Add GitLab Link",
                        subtitle: nil,
                        icon: .gitlab,
                        menuBuilder: { [actionHandler] in
                            actionHandler.buildGitlabMenu(taskUUID: taskUUID)
                        }
                    )
                )
            )

            items.append(
                .submenu(
                    CommandPaletteSubmenuItem(
                        id: "add-jira",
                        title: "Add Jira Link",
                        subtitle: nil,
                        icon: .jira,
                        menuBuilder: { [actionHandler] in
                            actionHandler.buildJiraMenu(taskUUID: taskUUID)
                        }
                    )
                )
            )
        }

        // Clear Project Scope (only when scope is set)
        if let scopedProject = context.currentProjectScope {
            items.append(
                .action(
                    CommandPaletteActionItem(
                        id: "clear-project-scope",
                        title: "Clear Project Scope",
                        subtitle: scopedProject,
                        icon: .system("xmark.circle"),
                        handler: { [actionHandler] in
                            Task { @MainActor in actionHandler.clearProjectScope() }
                        }
                    )
                )
            )
        }

        return [CommandPaletteSection(id: "actions", title: nil, items: items)]
    }
}

// MARK: - Shortcuts Section Contributor

/// Contributes the shortcuts section to the command palette.
///
/// This section appears last and displays available keyboard shortcuts.
/// Shortcuts are display-only and not selectable.
struct ShortcutsSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "shortcuts" }
    var priority: Int { 100 }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        // Don't show shortcuts when filtering
        guard query.isEmpty else { return [] }

        let items: [CommandPaletteItem] = [
            .shortcut(
                CommandPaletteShortcutItem(
                    id: "sc-escape",
                    title: "Close / Back",
                    keys: "Esc"
                )
            ),
            .shortcut(
                CommandPaletteShortcutItem(
                    id: "sc-enter",
                    title: "Select",
                    keys: "Return"
                )
            ),
            .shortcut(
                CommandPaletteShortcutItem(
                    id: "sc-up",
                    title: "Move Up",
                    keys: "↑ / Ctrl+P"
                )
            ),
            .shortcut(
                CommandPaletteShortcutItem(
                    id: "sc-down",
                    title: "Move Down",
                    keys: "↓ / Ctrl+N"
                )
            ),
        ]

        return [CommandPaletteSection(id: "shortcuts", title: "Shortcuts", items: items)]
    }
}

// MARK: - Group By Section Contributor

/// Grouping option for task list display.
enum GroupByOption: String, CaseIterable {
    case project
    case dueDate
    case tag
    case none

    var displayName: String {
        switch self {
        case .project: "Project"
        case .dueDate: "Due Date"
        case .tag: "Tag"
        case .none: "None"
        }
    }

    var icon: CommandPaletteIcon {
        switch self {
        case .project: .system("folder")
        case .dueDate: .system("calendar")
        case .tag: .system("tag")
        case .none: .system("list.bullet")
        }
    }

    func makeStrategy() -> TaskGroupingStrategy {
        switch self {
        case .project: ProjectGroupingStrategy()
        case .dueDate: DueDateGroupingStrategy()
        case .tag: TagGroupingStrategy()
        case .none: NoGroupingStrategy()
        }
    }
}

/// Contributes group-by options to the command palette.
struct GroupBySectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "groupBy" }
    var priority: Int { 10 }

    private let currentGroupBy: () -> GroupByOption
    private let onGroupBySelect: (GroupByOption) -> Void

    init(
        currentGroupBy: @escaping () -> GroupByOption,
        onGroupBySelect: @escaping (GroupByOption) -> Void
    ) {
        self.currentGroupBy = currentGroupBy
        self.onGroupBySelect = onGroupBySelect
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        let current = currentGroupBy()
        let items: [CommandPaletteItem] = GroupByOption.allCases.map { option in
            .action(
                CommandPaletteActionItem(
                    id: "group-by-\(option.rawValue)",
                    title: option.displayName,
                    subtitle: option == current ? "Current" : nil,
                    icon: option.icon,
                    handler: { [onGroupBySelect] in onGroupBySelect(option) }
                )
            )
        }

        return [CommandPaletteSection(id: "groupBy", title: "Group By", items: items)]
    }
}

/// Provides a "Go To" section for navigating to project-scoped views.
struct GoToSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "goTo" }
    var priority: Int { 20 }

    private let currentProjectScope: () -> String?
    private let onProjectSelect: (String) -> Void

    init(
        currentProjectScope: @escaping () -> String?,
        onProjectSelect: @escaping (String) -> Void
    ) {
        self.currentProjectScope = currentProjectScope
        self.onProjectSelect = onProjectSelect
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        guard !context.projects.isEmpty else { return [] }

        let current = currentProjectScope()
        let items: [CommandPaletteItem] = context.projects.map { project in
            .action(
                CommandPaletteActionItem(
                    id: "goto-\(project)",
                    title: project,
                    subtitle: project == current ? "Current" : nil,
                    icon: .system("folder"),
                    handler: { [onProjectSelect] in onProjectSelect(project) }
                )
            )
        }

        return [CommandPaletteSection(id: "goTo", title: "Go To", items: items)]
    }
}

// MARK: - Save Report Section Contributor

/// Contributes save/delete report actions to the command palette.
///
/// Shows:
/// - "Save Current Filter as Report" when filters are present
/// - "Delete Report" submenu with user reports when user reports exist
struct SaveReportSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "saveReport" }
    var priority: Int { 5 } // Between actions (0) and groupBy (10)

    private let actionHandler: CommandPaletteActionHandling
    private let getCurrentFilters: () -> [String]
    private let getUserReports: () -> [ReportSummary]

    init(
        actionHandler: CommandPaletteActionHandling,
        getCurrentFilters: @escaping () -> [String],
        getUserReports: @escaping () -> [ReportSummary]
    ) {
        self.actionHandler = actionHandler
        self.getCurrentFilters = getCurrentFilters
        self.getUserReports = getUserReports
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        var items: [CommandPaletteItem] = []

        // Save Current Filter as Report (only when filters exist)
        let currentFilters = getCurrentFilters()
        if !currentFilters.isEmpty {
            items.append(
                .action(
                    CommandPaletteActionItem(
                        id: "save-report",
                        title: "Save Current Filter as Report",
                        subtitle: currentFilters.joined(separator: " "),
                        icon: .system("square.and.arrow.down"),
                        handler: { [actionHandler] in
                            Task { @MainActor in actionHandler.showSaveReportSheet() }
                        }
                    )
                )
            )
        }

        // Delete Report submenu (only when user reports exist)
        let userReports = getUserReports().filter(\.isUserReport)
        if !userReports.isEmpty {
            let deleteItems: [CommandPaletteItem] = userReports.map { report in
                .action(
                    CommandPaletteActionItem(
                        id: "delete-report-\(report.name)",
                        title: report.name,
                        subtitle: CriteriaChipBuilder.reportSubtitle(for: report),
                        icon: .system("trash"),
                        handler: { [actionHandler] in
                            Task { @MainActor in actionHandler.deleteUserReport(name: report.name) }
                        }
                    )
                )
            }

            items.append(
                .submenu(
                    CommandPaletteSubmenuItem(
                        id: "delete-report-menu",
                        title: "Delete User Report",
                        subtitle: "\(userReports.count) report\(userReports.count == 1 ? "" : "s")",
                        icon: .system("trash"),
                        menuBuilder: {
                            CommandPaletteMenu(
                                id: "delete-report",
                                title: "Delete User Report",
                                sections: [CommandPaletteSection(id: "delete-reports", title: nil, items: deleteItems)]
                            )
                        }
                    )
                )
            )
        }

        guard !items.isEmpty else { return [] }
        return [CommandPaletteSection(id: "saveReport", title: nil, items: items)]
    }
}
