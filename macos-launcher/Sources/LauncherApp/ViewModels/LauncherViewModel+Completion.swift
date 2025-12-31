import Foundation

// MARK: - Completion Methods

extension LauncherViewModel {
    /// Load all completion data from the API at startup.
    func loadCompletionData() async {
        if let errorMessage = await completion.loadData(actionService: actionService) {
            logger.error("Failed to load completions: \(errorMessage, privacy: .public)")
            return
        }
        completion.update(input: input, tokens: tokens, tasks: tasks)
        let counts = completion.cacheCounts
        logger.info("Completions loaded: \(counts.projects) projects, \(counts.tags) tags, \(counts.actions) actions")
    }

    /// Update completions based on the current context and prefix.
    func updateCompletions() {
        completion.update(input: input, tokens: tokens, tasks: tasks)
    }

    /// Accept the currently selected completion.
    func acceptCompletion(_ item: CompletionItem? = nil) {
        guard let result = completion.applyCompletion(item, input: input) else { return }
        suppressInputHandling = true
        input = result.text
        completion.cursorPosition = result.cursorPosition
        suppressInputHandling = false

        clearCompletions()

        // Re-parse after completion
        handleInputChange(input)
    }

    /// Accept the ghost text completion (Tab key).
    func acceptGhostText() {
        if let item = completion.acceptGhostText() {
            acceptCompletion(item)
        }
    }

    /// Toggle the completion menu visibility.
    func toggleCompletionMenu() {
        completion.toggleMenu(input: input, tokens: tokens, tasks: tasks)
    }

    /// Move completion selection up/down.
    func moveCompletionSelection(delta: Int) {
        completion.moveSelection(delta: delta)
    }

    /// Clear all completion state.
    func clearCompletions() {
        completion.clear()
        schedulePendingParseErrorAfterMenuClose()
    }

    /// Handle cursor position changes from the text view.
    func handleCursorChange(_ position: Int) {
        completion.updateCursorPosition(position, input: input, tokens: tokens, tasks: tasks)
    }
}
