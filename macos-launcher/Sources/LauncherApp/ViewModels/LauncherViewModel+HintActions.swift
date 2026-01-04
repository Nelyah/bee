import Foundation

extension LauncherViewModel {
    /// Handles hint bar click actions by routing to existing ViewModel methods.
    func handleHintAction(_ action: HintAction) {
        switch action {
        case .escape:
            _ = handleEscape()

        case .enterInsertMode:
            enterInsertMode()

        case .toggleFold:
            _ = toggleSelectedOrHoveredGroupCollapse() || toggleSelectedOrHoveredTaskExpansion()

        case .openTask:
            openDetail()

        case .openFocusedItem:
            _ = openFocusedDetailItem()

        case .addAnnotation:
            startAddingAnnotation()

        case .addTag:
            startAddingTag()

        case .copyFocused:
            _ = copyFocusedDetailItem()

        case .deleteTag:
            _ = deleteFocusedDetailItem()

        case .saveEdit:
            // Save is handled directly by the text editor's onCommit
            break

        case .openCommandPalette:
            openCommandPalette()

        case .acceptSuggestion:
            // Completion menu acceptance is handled by CompletionField
            break

        case .none:
            // Non-actionable hint, do nothing
            break
        }
    }
}
