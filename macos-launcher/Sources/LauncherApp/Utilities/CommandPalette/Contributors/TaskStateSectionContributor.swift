import Foundation

/// Provides task state actions (complete, delete, start, stop) when a task is selected.
struct TaskStateSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "taskState" }
    var priority: Int { 3 }  // After actions (0), before save report (5)

    private let onTaskStateChange: (TaskStateAction, String) -> Void

    init(onTaskStateChange: @escaping (TaskStateAction, String) -> Void) {
        self.onTaskStateChange = onTaskStateChange
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        guard context.hasSelectedTask, let taskUUID = context.selectedTaskUUID else {
            return []
        }

        let items: [CommandPaletteItem] = [
            .action(CommandPaletteActionItem(
                id: "task-complete",
                title: "Completed",
                icon: .system("checkmark.circle"),
                handler: { [onTaskStateChange] in onTaskStateChange(.complete, taskUUID) }
            )),
            .action(CommandPaletteActionItem(
                id: "task-active",
                title: "Active",
                icon: .system("play.circle"),
                handler: { [onTaskStateChange] in onTaskStateChange(.start, taskUUID) }
            )),
            .action(CommandPaletteActionItem(
                id: "task-pending",
                title: "Pending",
                icon: .system("pause.circle"),
                handler: { [onTaskStateChange] in onTaskStateChange(.stop, taskUUID) }
            )),
            .action(CommandPaletteActionItem(
                id: "task-delete",
                title: "Deleted",
                icon: .system("trash"),
                handler: { [onTaskStateChange] in onTaskStateChange(.delete, taskUUID) }
            )),
        ]

        return [CommandPaletteSection(id: "taskState", title: "Mark task as...", items: items)]
    }
}
