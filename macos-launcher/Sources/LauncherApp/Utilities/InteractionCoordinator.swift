struct InteractionCoordinator {
    enum EscapeAction: Equatable {
        case closeCommandPalette
        case clearCompletions
        case closeDetail
        case exitInsertMode
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

    static func escapeAction(
        isCommandPalettePresented: Bool,
        showCompletionMenu: Bool,
        mode: LauncherMode
    ) -> EscapeAction {
        if isCommandPalettePresented {
            return .closeCommandPalette
        }
        if showCompletionMenu {
            return .clearCompletions
        }
        if mode == .detail {
            return .closeDetail
        }
        return .exitInsertMode
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
