import Foundation

/// Provides a "Go to Projects" action for navigating to the project overview view.
struct ProjectOverviewSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "projectOverview" }
    var priority: Int { 15 } // Between TaskLink (4) and GoTo (20)

    private let onNavigate: () -> Void

    init(onNavigate: @escaping () -> Void) {
        self.onNavigate = onNavigate
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        let title = "Go to Projects"
        let subtitle = "View project statistics and burndown charts"

        // Filter based on query
        let lowerQuery = query.lowercased()
        guard lowerQuery.isEmpty
            || title.lowercased().contains(lowerQuery)
            || subtitle.lowercased().contains(lowerQuery)
            || "projects".contains(lowerQuery)
            || "overview".contains(lowerQuery)
            || "burndown".contains(lowerQuery)
            || "statistics".contains(lowerQuery)
        else {
            return []
        }

        let items: [CommandPaletteItem] = [
            .action(
                CommandPaletteActionItem(
                    id: "go-to-projects",
                    title: title,
                    subtitle: subtitle,
                    icon: .system("chart.bar.xaxis"),
                    handler: { [onNavigate] in onNavigate() }
                )
            ),
        ]

        return [CommandPaletteSection(id: "projectOverview", title: nil, items: items)]
    }
}
