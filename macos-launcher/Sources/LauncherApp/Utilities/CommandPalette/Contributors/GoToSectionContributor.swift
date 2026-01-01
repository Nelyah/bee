import Foundation

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

        return [CommandPaletteSection(id: "goTo", title: "Go to project", items: items)]
    }
}
