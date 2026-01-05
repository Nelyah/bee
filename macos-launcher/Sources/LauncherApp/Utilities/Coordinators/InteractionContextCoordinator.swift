import Foundation

enum ListSelectionKind: Equatable {
    case none
    case groupHeader
    case task
}

enum BaseInteractionContext: Equatable {
    case detail
    case list(selection: ListSelectionKind)
}

enum InteractionContext: Equatable {
    case commandPalette
    case completionMenu(selection: ListSelectionKind, isInsertMode: Bool)
    case detail(isEditing: Bool)
    case list(selection: ListSelectionKind, isInsertMode: Bool)

    /// Convenience accessor for detail mode when not editing (most common case).
    static var detail: InteractionContext { .detail(isEditing: false) }
}

struct BottomHintModel: Equatable {
    let left: [BottomHint]
    let right: [BottomHint]
}

enum InteractionContextCoordinator {
    static func baseContext(
        mode: LauncherMode,
        selectedRowIndex: Int?,
        rows: [GroupedListRow]
    ) -> BaseInteractionContext {
        switch mode {
        case .detail, .projectOverview:
            return .detail
        case .list:
            let selection = selectionKind(selectedRowIndex: selectedRowIndex, rows: rows)
            return .list(selection: selection)
        }
    }

    static func interactionContext(
        base: BaseInteractionContext,
        showCompletionMenu: Bool,
        commandPalettePresented: Bool,
        isInsertMode: Bool,
        isEditing: Bool = false
    ) -> InteractionContext {
        if commandPalettePresented {
            return .commandPalette
        }

        switch base {
        case .detail:
            return .detail(isEditing: isEditing)
        case let .list(selection):
            if showCompletionMenu {
                return .completionMenu(selection: selection, isInsertMode: isInsertMode)
            }
            return .list(selection: selection, isInsertMode: isInsertMode)
        }
    }

    private static func selectionKind(
        selectedRowIndex: Int?,
        rows: [GroupedListRow]
    ) -> ListSelectionKind {
        guard let index = selectedRowIndex, index >= 0, index < rows.count else {
            return .none
        }
        switch rows[index] {
        case .header:
            return .groupHeader
        case .task:
            return .task
        }
    }
}

enum BottomHintModelBuilder {
    static func model(for context: InteractionContext) -> BottomHintModel {
        model(for: context, detailCopyLabel: nil, hasTagSelected: false, multiSelectCount: 0)
    }

    /// Builds hint model with optional detail copy label (e.g., "UUID", "Branch", "Link").
    static func model(for context: InteractionContext, detailCopyLabel: String?) -> BottomHintModel {
        model(for: context, detailCopyLabel: detailCopyLabel, hasTagSelected: false, multiSelectCount: 0)
    }

    /// Builds hint model with optional detail copy label and tag selection state.
    static func model(
        for context: InteractionContext,
        detailCopyLabel: String?,
        hasTagSelected: Bool,
        multiSelectCount: Int = 0
    ) -> BottomHintModel {
        let left = leftHints(for: context, multiSelectCount: multiSelectCount)
        let right = rightHints(for: context, detailCopyLabel: detailCopyLabel, hasTagSelected: hasTagSelected)
        return BottomHintModel(left: left, right: right)
    }

    private static func leftHints(for context: InteractionContext, multiSelectCount: Int = 0) -> [BottomHint] {
        var hints: [BottomHint] = []

        // Show multi-selection count first when tasks are selected
        if multiSelectCount > 0 {
            hints.append(BottomHint(key: "\(multiSelectCount)", label: "selected", action: .none))
        }

        hints.append(BottomHint(keybinding: KeybindingRegistry.escape, label: escapeLabel(for: context)))
        switch context {
        case let .detail(isEditing):
            if !isEditing {
                // Informational hint - not a single action
                hints.append(BottomHint(key: "hjkl", label: "Navigate"))
            }
        case let .list(_, isInsertMode):
            if !isInsertMode {
                hints.append(BottomHint(keybinding: KeybindingRegistry.enterInsertMode, label: "Insert"))
            }
        default:
            break
        }
        return hints
    }

    private static func rightHints(
        for context: InteractionContext,
        detailCopyLabel: String?,
        hasTagSelected: Bool
    ) -> [BottomHint] {
        var hints: [BottomHint] = []

        switch context {
        case let .detail(isEditing):
            if isEditing {
                // Edit mode: show save hint instead of Enter
                hints.append(BottomHint(keybinding: KeybindingRegistry.saveEdit, label: "Save"))
            } else {
                // Normal detail mode: show Enter for Open
                hints.append(BottomHint(keybinding: KeybindingRegistry.openFocusedItem, label: "Open"))
                // Show tag deletion hint when a tag is selected
                if hasTagSelected {
                    hints.append(BottomHint(keybinding: KeybindingRegistry.deleteTag, label: "Delete tag"))
                }
                // Show action hints for detail mode
                hints.append(BottomHint(keybinding: KeybindingRegistry.addAnnotation, label: "Add note"))
                hints.append(BottomHint(keybinding: KeybindingRegistry.addTag, label: "Add tag"))
                hints.append(BottomHint(keybinding: KeybindingRegistry.linkTask, label: "Link task"))
                // Dynamic copy label based on focused item (e.g., "Copy UUID", "Copy Branch")
                let copyLabel = detailCopyLabel.map { "Copy \($0)" } ?? "Copy"
                hints.append(BottomHint(keybinding: KeybindingRegistry.copyFocused, label: copyLabel))
            }
        case let .list(selection, isInsertMode):
            // Enter key action depends on what's selected
            switch selection {
            case .groupHeader:
                hints.append(BottomHint(key: "Enter", label: "Toggle fold", action: .toggleFold))
            case .task:
                hints.append(BottomHint(keybinding: KeybindingRegistry.openTask, label: "Open task"))
            case .none:
                // No specific Enter action when nothing selected
                hints.append(BottomHint(key: "Enter", label: "Run action", action: .none))
            }
            // Show Tab hint in normal mode (collapse for headers, expand for tasks)
            if !isInsertMode {
                switch selection {
                case .groupHeader:
                    hints.append(BottomHint(keybinding: KeybindingRegistry.toggleFold, label: "Collapse"))
                case .task:
                    hints.append(BottomHint(keybinding: KeybindingRegistry.toggleFold, label: "Expand"))
                case .none:
                    break
                }
            }
        case .commandPalette:
            // Command palette Enter selects (not in our registry - internal to palette)
            hints.append(BottomHint(key: "Enter", label: "Select", action: .none))
        case .completionMenu:
            hints.append(BottomHint(key: "Enter", label: "Accept suggestion", action: .acceptSuggestion))
        }

        hints.append(BottomHint(keybinding: KeybindingRegistry.commandPalette, label: "Command menu"))
        return hints
    }

    private static func escapeLabel(for context: InteractionContext) -> String {
        switch context {
        case .commandPalette:
            "Close menu"
        case .completionMenu:
            "Hide suggestions"
        case let .detail(isEditing):
            isEditing ? "Cancel" : "Back"
        case let .list(_, isInsertMode):
            isInsertMode ? "Exit insert" : "Close"
        }
    }
}
