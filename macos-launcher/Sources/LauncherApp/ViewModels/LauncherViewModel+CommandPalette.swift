import Foundation

// MARK: - Command Palette

extension LauncherViewModel {
    func openCommandPalette() {
        let context = CommandPaletteContext(
            hasSelectedTask: selectedTask != nil,
            selectedTaskUUID: selectedTask?.uuid,
            currentReportName: selectedReportName,
            availableReports: availableReports,
            projects: completion.projectNames,
            tags: completion.tagNames,
            currentProjectScope: projectScope
        )
        if let message = commandPalette.open(context: context) {
            showToast(message: message)
        }
    }

    func closeCommandPalette() {
        commandPalette.close()
    }

    func submitCommandPaletteSelection() {
        commandPalette.handleEnter()
    }

    func moveCommandPaletteSelection(delta: Int) {
        commandPalette.moveSelection(delta: delta)
    }
}
