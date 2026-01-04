import Foundation

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

        // Add Attachment (requires selected task)
        if context.hasSelectedTask {
            items.append(
                .action(
                    CommandPaletteActionItem(
                        id: "add-attachment",
                        title: "Add Attachment",
                        subtitle: nil,
                        icon: .system("paperclip"),
                        handler: { [actionHandler] in
                            Task { @MainActor in actionHandler.addAttachment() }
                        }
                    )
                )
            )
        }

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
