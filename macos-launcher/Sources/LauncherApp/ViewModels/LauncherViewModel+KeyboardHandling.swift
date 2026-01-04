import Foundation

// MARK: - Keyboard Handlers

extension LauncherViewModel {
    @discardableResult
    func handleEscape() -> Bool {
        // Close SaveReportSheet if it's open
        if showingSaveReportSheet {
            showingSaveReportSheet = false
            return true
        }

        // Cancel annotation input if active
        if isAddingAnnotation {
            cancelAddingAnnotation()
            return true
        }

        // Cancel task name editing if active
        if isEditingTaskName {
            cancelEditingTaskName()
            return true
        }

        // Cancel project editing if active
        if isEditingProject {
            cancelEditingProject()
            return true
        }

        // Cancel adding tag if active
        if isAddingTag {
            cancelAddingTag()
            return true
        }

        // Cancel annotation editing if active
        if editingAnnotationId != nil {
            cancelEditingAnnotation()
            return true
        }

        if interactionContext == .commandPalette {
            if commandPalette.handleEscape() {
                return true
            }
            closeCommandPalette()
            return true
        }

        let action = InteractionCoordinator.escapeAction(for: interactionContext)
        switch action {
        case .closeCommandPalette:
            closeCommandPalette()
            return true
        case .clearCompletions:
            clearCompletions()
            return true
        case .closeDetail:
            closeDetail()
            return true
        case .exitInsertMode:
            exitInsertMode()
            return true
        case .closeWindow:
            windowClose.send()
            return true
        case .none:
            return false
        }
    }

    @discardableResult
    func handleNormalModeAction(_ action: NormalModeAction) -> Bool {
        let effect = InteractionCoordinator.normalModeEffect(
            action: action,
            canToggleGroupCollapse: canToggleSelectedOrHoveredGroupCollapse()
        )
        switch effect {
        case .enterInsertMode:
            enterInsertMode()
            return true
        case let .moveSelection(delta):
            moveSelection(delta: delta)
            return true
        case .selectFirst:
            selectFirstRow()
            return true
        case .selectLast:
            selectLastRow()
            return true
        case .toggleGroupCollapse:
            return toggleSelectedOrHoveredGroupCollapse()
        case .toggleTaskExpansion:
            return toggleSelectedOrHoveredTaskExpansion()
        case .openDetail:
            openDetail()
            return true
        case .openCommandPalette:
            openCommandPalette()
            return true
        case .none:
            return false
        }
    }
}
