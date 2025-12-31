import Foundation

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
