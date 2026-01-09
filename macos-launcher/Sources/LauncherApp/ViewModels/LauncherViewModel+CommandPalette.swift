import Foundation

@MainActor
public extension LauncherViewModel {
    func openCommandPalette() {
        let context = buildCommandPaletteContext()
        if let errorMessage = commandPalette.open(context: context) {
            showToast(message: errorMessage)
        }
    }

    internal func closeCommandPalette() {
        commandPalette.close()
        schedulePendingParseErrorAfterMenuClose()
    }

    /// Opens the command palette directly to the link type menu.
    /// Requires a task to be selected; shows toast if no task selected.
    func openLinkPalette() {
        guard let task = selectedTask else {
            showToast(message: "Select a task first", icon: .warning)
            return
        }
        // First open the command palette
        let context = buildCommandPaletteContext()
        if let errorMessage = commandPalette.open(context: context) {
            showToast(message: errorMessage)
            return
        }
        // Build and push the link type menu directly using stored handler
        let linkMenu = paletteActionHandler.buildLinkTypeMenu(taskUUID: task.uuid)
        commandPalette.navigationStack.push(linkMenu)
    }

    // MARK: - Contextual Menu (Cmd+P)

    /// Handles Cmd+P - dispatches to the appropriate contextual menu based on current mode.
    /// In list mode: shows report menu. In detail mode: shows task state menu.
    /// Note: reportMenuTrigger and taskStateMenuTrigger properties are stored in LauncherViewModel.swift
    func handleContextualMenu() {
        switch mode {
        case .list:
            reportMenuTrigger?()
        case .detail:
            taskStateMenuTrigger?()
        case .projectOverview:
            // No contextual menu in project overview - do nothing
            break
        }
    }

    internal func setupCommandPaletteContributors() {
        // Register the shortcuts section (always visible)
        commandPalette.dataSource.register(ShortcutsSectionContributor())

        // Register the actions section with handlers (use stored handler for lifecycle)
        commandPalette.dataSource.register(ActionsSectionContributor(actionHandler: paletteActionHandler))

        // Register the task link section (requires selected task)
        commandPalette.dataSource.register(TaskLinkSectionContributor(actionHandler: paletteActionHandler))

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

        // Register the task state section for task actions (complete, delete, start, stop)
        commandPalette.dataSource.register(TaskStateSectionContributor(
            onTaskStateChange: { [weak self] action, uuid in
                self?.handleTaskStateChange(action, taskUUID: uuid)
            }
        ))

        // Register the go-to section for project navigation
        commandPalette.dataSource.register(GoToSectionContributor(
            currentProjectScope: { [weak self] in self?.projectScope },
            onProjectSelect: { [weak self] project in
                self?.setProjectScope(project)
                self?.closeCommandPalette()
            }
        ))

        // Register the project overview section
        commandPalette.dataSource.register(ProjectOverviewSectionContributor(
            onNavigate: { [weak self] in
                self?.navigateToProjectOverview()
                self?.closeCommandPalette()
            }
        ))

        // Register the save report section
        commandPalette.dataSource.register(SaveReportSectionContributor(
            actionHandler: paletteActionHandler,
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
