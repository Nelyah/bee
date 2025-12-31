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

/// Placeholder contributor for go-to project navigation (DEBT-0033).
///
/// This is a stub for future implementation. To enable:
/// 1. Wire up `onProjectSelect` callback to view model
/// 2. Populate `context.projects` with available projects
/// 3. Register with data source
struct GoToSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "goTo" }
    var priority: Int { 20 }

    private let onProjectSelect: (String) -> Void

    init(onProjectSelect: @escaping (String) -> Void) {
        self.onProjectSelect = onProjectSelect
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        guard !context.projects.isEmpty else { return [] }

        let items: [CommandPaletteItem] = context.projects.map { project in
            .action(
                CommandPaletteActionItem(
                    id: "goto-\(project)",
                    title: project,
                    icon: .system("folder"),
                    handler: { [onProjectSelect] in onProjectSelect(project) }
                )
            )
        }

        return [CommandPaletteSection(id: "goTo", title: "Go To", items: items)]
    }
}
