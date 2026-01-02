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
        model(for: context, detailCopyLabel: nil)
    }

    /// Builds hint model with optional detail copy label (e.g., "UUID", "Branch", "Link").
    static func model(for context: InteractionContext, detailCopyLabel: String?) -> BottomHintModel {
        let left = leftHints(for: context)
        let right = rightHints(for: context, detailCopyLabel: detailCopyLabel)
        return BottomHintModel(left: left, right: right)
    }

    private static func leftHints(for context: InteractionContext) -> [BottomHint] {
        var hints = [BottomHint(key: "Esc", label: escapeLabel(for: context))]
        switch context {
        case let .detail(isEditing):
            if !isEditing {
                hints.append(BottomHint(key: "hjkl", label: "Navigate"))
            }
        case let .list(_, isInsertMode):
            if !isInsertMode {
                hints.append(BottomHint(key: "i", label: "Insert"))
            }
        default:
            break
        }
        return hints
    }

    private static func rightHints(for context: InteractionContext, detailCopyLabel: String?) -> [BottomHint] {
        var hints: [BottomHint] = []

        switch context {
        case let .detail(isEditing):
            if isEditing {
                // Edit mode: show save hint instead of Enter
                hints.append(BottomHint(key: "⌘↩", label: "Save"))
            } else {
                // Normal detail mode: show Enter for Open
                if let enterLabel = enterLabel(for: context) {
                    hints.append(BottomHint(key: "Enter", label: enterLabel))
                }
                // Show action hints for detail mode
                hints.append(BottomHint(key: "a", label: "Add note"))
                // Dynamic copy label based on focused item (e.g., "Copy UUID", "Copy Branch")
                let copyLabel = detailCopyLabel.map { "Copy \($0)" } ?? "Copy"
                hints.append(BottomHint(key: "y", label: copyLabel))
            }
        case let .list(selection, isInsertMode):
            if let enterLabel = enterLabel(for: context) {
                hints.append(BottomHint(key: "Enter", label: enterLabel))
            }
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
            if let enterLabel = enterLabel(for: context) {
                hints.append(BottomHint(key: "Enter", label: enterLabel))
            }
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
        case let .detail(isEditing):
            isEditing ? "Cancel" : "Back"
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
        case let .detail(isEditing):
            // When editing, we don't show Enter hint (Cmd+Enter Save is shown instead)
            isEditing ? nil : "Open"
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
