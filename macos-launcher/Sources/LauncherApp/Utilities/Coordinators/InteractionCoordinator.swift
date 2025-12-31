enum InteractionCoordinator {
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
        case toggleTaskExpansion
        case openDetail
        case openCommandPalette
        case none
    }

    static func escapeAction(for context: InteractionContext) -> EscapeAction {
        switch context {
        case .commandPalette:
            .closeCommandPalette
        case .completionMenu:
            .clearCompletions
        case .detail:
            .closeDetail
        case let .list(_, isInsertMode):
            isInsertMode ? .exitInsertMode : .closeWindow
        }
    }

    static func normalModeEffect(
        action: NormalModeAction,
        canToggleGroupCollapse: Bool
    ) -> NormalModeEffect {
        switch action {
        case .enterInsertMode:
            .enterInsertMode
        case let .moveSelection(delta):
            .moveSelection(delta)
        case .selectFirst:
            .selectFirst
        case .selectLast:
            .selectLast
        case .toggleGroupCollapse:
            .toggleGroupCollapse
        case .toggleWithTab:
            // Tab toggles collapse on headers, expansion on tasks
            canToggleGroupCollapse ? .toggleGroupCollapse : .toggleTaskExpansion
        case .activatePrimary:
            canToggleGroupCollapse ? .toggleGroupCollapse : .openDetail
        case .openCommandPalette:
            .openCommandPalette
        }
    }
}
