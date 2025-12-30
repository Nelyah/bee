struct InteractionCoordinator {
    enum EscapeAction: Equatable {
        case closeCommandPalette
        case clearCompletions
        case closeDetail
        case exitInsertMode
        case closeWindow
        case none
    }

    enum NormalModeEffect: Equatable {
        case enterInsertMode
        case moveSelection(Int)
        case selectFirst
        case selectLast
        case toggleGroupCollapse
        case openDetail
        case none
    }

    static func escapeAction(for context: InteractionContext) -> EscapeAction {
        switch context {
        case .commandPalette:
            return .closeCommandPalette
        case .completionMenu:
            return .clearCompletions
        case .detail:
            return .closeDetail
        case .list(_, let isInsertMode):
            return isInsertMode ? .exitInsertMode : .closeWindow
        }
    }

    static func normalModeEffect(
        action: NormalModeAction,
        canToggleGroupCollapse: Bool
    ) -> NormalModeEffect {
        switch action {
        case .enterInsertMode:
            return .enterInsertMode
        case .moveSelection(let delta):
            return .moveSelection(delta)
        case .selectFirst:
            return .selectFirst
        case .selectLast:
            return .selectLast
        case .toggleGroupCollapse:
            return .toggleGroupCollapse
        case .activatePrimary:
            return canToggleGroupCollapse ? .toggleGroupCollapse : .openDetail
        }
    }
}
