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

        switch detailEditingState {
        case .none:
            return false
        case .addingAnnotation:
            annotationInput = ""
            detailEditingState = .none
            return true
        case .editingAnnotation:
            annotationEditInput = ""
            detailEditingState = .none
            return true
        case .editingTaskName:
            taskNameEditInput = ""
            detailEditingState = .none
            return true
        case .editingProject:
            projectEditInput = ""
            detailEditingState = .none
            return true
        case .addingTag:
            tagAddQuery = ""
            detailEditingState = .none
            return true
        case .editingDueDate:
            detailEditingState = .none
            return true
        case .editingPlannedDate:
            detailEditingState = .none
            return true
        case .addingImportantLink:
            importantLinkUrlInput = ""
            importantLinkTitleInput = ""
            detailEditingState = .none
            return true
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
