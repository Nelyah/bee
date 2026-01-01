import Foundation

@MainActor
extension LauncherViewModel {
    func openCommandPalette() {
        let context = buildCommandPaletteContext()
        if let errorMessage = commandPalette.open(context: context) {
            showToast(message: errorMessage)
        }
    }

    func closeCommandPalette() {
        commandPalette.close()
        schedulePendingParseErrorAfterMenuClose()
    }

    func setupCommandPaletteContributors() {
        // Register the shortcuts section (always visible)
        commandPalette.dataSource.register(ShortcutsSectionContributor())

        // Register the actions section with handlers
        let actionHandler = CommandPaletteActionHandler(viewModel: self, apiClient: apiClient)
        commandPalette.dataSource.register(ActionsSectionContributor(actionHandler: actionHandler))

        // Register the group-by section
        commandPalette.dataSource.register(GroupBySectionContributor(
            currentGroupBy: { [weak self] in self?.currentGroupByOption ?? .project },
            onGroupBySelect: { [weak self] option in self?.setGroupingStrategy(option) }
        ))

        // Register the columns section for add/remove columns
        commandPalette.dataSource.register(ColumnsSectionContributor(
            currentColumns: { [weak self] in self?.columnConfigs ?? [] },
            onAddColumn: { [weak self] definition in self?.addColumn(definition) },
            onRemoveColumn: { [weak self] key in self?.removeColumn(key) }
        ))

        // Register the go-to section for project navigation
        commandPalette.dataSource.register(GoToSectionContributor(
            currentProjectScope: { [weak self] in self?.projectScope },
            onProjectSelect: { [weak self] project in
                self?.setProjectScope(project)
                self?.closeCommandPalette()
            }
        ))

        // Register the save report section
        commandPalette.dataSource.register(SaveReportSectionContributor(
            actionHandler: actionHandler,
            getCurrentFilters: { [weak self] in self?.criteriaFilterChips.map(\.label) ?? [] },
            getUserReports: { [weak self] in self?.availableReports ?? [] }
        ))
    }

    private func buildCommandPaletteContext() -> CommandPaletteContext {
        let selected = selectedTask
        return CommandPaletteContext(
            hasSelectedTask: selected != nil,
            selectedTaskUUID: selected?.uuid,
            currentReportName: currentReportDisplayName,
            availableReports: availableReports,
            projects: completion.projectNames.sorted(),
            tags: completion.tagNames.sorted(),
            currentProjectScope: projectScope
        )
    }
}
