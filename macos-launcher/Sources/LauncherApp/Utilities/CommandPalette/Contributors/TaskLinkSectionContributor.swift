import Foundation

/// Contributes the "Link to Task" section to the command palette.
///
/// This section appears when a task is selected and allows the user to
/// create relationships between tasks (blocks, depends on, parent/child, etc.).
struct TaskLinkSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "taskLink" }
    var priority: Int { 4 }

    private let actionHandler: CommandPaletteActionHandling

    init(actionHandler: CommandPaletteActionHandling) {
        self.actionHandler = actionHandler
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        // Only show when a task is selected
        guard context.hasSelectedTask, let taskUUID = context.selectedTaskUUID else {
            return []
        }

        let items: [CommandPaletteItem] = [
            .submenu(
                CommandPaletteSubmenuItem(
                    id: "link-to-task",
                    title: "Link to Task",
                    subtitle: nil,
                    icon: .system("link"),
                    menuBuilder: { [actionHandler] in
                        actionHandler.buildLinkTypeMenu(taskUUID: taskUUID)
                    }
                )
            ),
        ]

        return [CommandPaletteSection(id: "taskLink", title: nil, items: items)]
    }
}
