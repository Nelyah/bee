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
    case detail
    case list(selection: ListSelectionKind, isInsertMode: Bool)
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
        case .detail:
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
        isInsertMode: Bool
    ) -> InteractionContext {
        if commandPalettePresented {
            return .commandPalette
        }

        switch base {
        case .detail:
            return .detail
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
        let left = leftHints(for: context)
        let right = rightHints(for: context)
        return BottomHintModel(left: left, right: right)
    }

    private static func leftHints(for context: InteractionContext) -> [BottomHint] {
        var hints = [BottomHint(key: "Esc", label: escapeLabel(for: context))]
        switch context {
        case .detail:
            hints.append(BottomHint(key: "j/k", label: "Navigate"))
        case let .list(_, isInsertMode):
            if !isInsertMode {
                hints.append(BottomHint(key: "i", label: "Insert"))
            }
        default:
            break
        }
        return hints
    }

    private static func rightHints(for context: InteractionContext) -> [BottomHint] {
        var hints: [BottomHint] = []
        if let enterLabel = enterLabel(for: context) {
            hints.append(BottomHint(key: "Enter", label: enterLabel))
        }

        switch context {
        case .detail:
            // Show open/copy hints for detail mode
            hints.append(BottomHint(key: "o", label: "Open"))
            hints.append(BottomHint(key: "y", label: "Copy"))
        case let .list(selection, isInsertMode):
            // Show Tab hint in normal mode (collapse for headers, expand for tasks)
            if !isInsertMode {
                switch selection {
                case .groupHeader:
                    hints.append(BottomHint(key: "Tab", label: "Collapse"))
                case .task:
                    hints.append(BottomHint(key: "Tab", label: "Expand"))
                case .none:
                    break
                }
            }
        default:
            break
        }

        hints.append(BottomHint(key: "⌘K", label: "Command menu"))
        return hints
    }

    private static func escapeLabel(for context: InteractionContext) -> String {
        switch context {
        case .commandPalette:
            "Close menu"
        case .completionMenu:
            "Hide suggestions"
        case .detail:
            "Back"
        case let .list(_, isInsertMode):
            isInsertMode ? "Exit insert" : "Close"
        }
    }

    private static func enterLabel(for context: InteractionContext) -> String? {
        switch context {
        case .commandPalette:
            "Select"
        case .completionMenu:
            "Accept suggestion"
        case .detail:
            nil
        case let .list(selection, _):
            switch selection {
            case .groupHeader:
                "Toggle fold"
            case .task:
                "Open task"
            case .none:
                "Run action"
            }
        }
    }
}
