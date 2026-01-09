import Foundation

// MARK: - Keyboard Handlers

extension LauncherViewModel {
    @discardableResult
    func handleEscape() -> Bool {
        // Handle editing states first (extracted to reduce complexity)
        if handleEscapeForEditingStates() {
            return true
        }

        // Clear multi-selection if active
        if hasMultiSelection {
            clearMultiSelection()
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
        case .navigateBack:
            return navigateBack()
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

    /// Handle escape for various editing states in detail view.
    /// Returns true if an editing state was active and cancelled.
    private func handleEscapeForEditingStates() -> Bool {
        if showingSaveReportSheet {
            showingSaveReportSheet = false
            return true
        }
        if isAddingAnnotation {
            cancelAddingAnnotation()
            return true
        }
        if isEditingTaskName {
            cancelEditingTaskName()
            return true
        }
        if isEditingProject {
            cancelEditingProject()
            return true
        }
        if isAddingTag {
            cancelAddingTag()
            return true
        }
        if editingAnnotationId != nil {
            cancelEditingAnnotation()
            return true
        }
        if isEditingDueDate {
            cancelEditingDueDate()
            return true
        }
        return false
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
        case .toggleMultiSelect:
            return toggleMultiSelectAtCursor()
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
