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

struct InteractionContextCoordinator {
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
        case .list(let selection):
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

struct BottomHintModelBuilder {
    static func model(for context: InteractionContext) -> BottomHintModel {
        let left = [BottomHint(key: "Esc", label: escapeLabel(for: context))]
        let right = rightHints(for: context)
        return BottomHintModel(left: left, right: right)
    }

    private static func rightHints(for context: InteractionContext) -> [BottomHint] {
        var hints: [BottomHint] = []
        if let enterLabel = enterLabel(for: context) {
            hints.append(BottomHint(key: "Enter", label: enterLabel))
        }
        hints.append(BottomHint(key: "⌘K", label: "Command menu"))
        return hints
    }

    private static func escapeLabel(for context: InteractionContext) -> String {
        switch context {
        case .commandPalette:
            return "Close menu"
        case .completionMenu:
            return "Hide suggestions"
        case .detail:
            return "Back"
        case .list(_, let isInsertMode):
            return isInsertMode ? "Exit insert" : "Exit insert"
        }
    }

    private static func enterLabel(for context: InteractionContext) -> String? {
        switch context {
        case .commandPalette:
            return "Select"
        case .completionMenu:
            return "Accept suggestion"
        case .detail:
            return nil
        case .list(let selection, _):
            switch selection {
            case .groupHeader:
                return "Toggle fold"
            case .task:
                return "Open task"
            case .none:
                return "Run action"
            }
        }
    }
}
