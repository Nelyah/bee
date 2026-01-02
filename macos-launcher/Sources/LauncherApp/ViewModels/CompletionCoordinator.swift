import Foundation

struct CacheCounts {
    let projects: Int
    let tags: Int
    let actions: Int
}

@MainActor
final class CompletionCoordinator: ObservableObject {
    @Published var items: [CompletionItem] = []
    @Published var selectedIndex: Int = 0
    @Published var showMenu: Bool = false
    @Published var ghostText: String?
    @Published var context: CompletionContext = .none
    @Published var cursorPosition: Int = 0

    private var cache = CompletionCache()
    private var isLoaded = false

    var cacheCounts: CacheCounts {
        CacheCounts(projects: cache.projects.count, tags: cache.tags.count, actions: cache.actions.count)
    }

    /// Project names from completion cache.
    var projectNames: [String] {
        cache.projects.map(\.value)
    }

    /// Project completion items from cache.
    var projectItems: [CompletionItem] {
        cache.projects
    }

    /// Tag names from completion cache.
    var tagNames: [String] {
        cache.tags.map(\.value)
    }

    func loadData(actionService: LauncherActionService) async -> String? {
        guard !isLoaded else { return nil }
        do {
            cache = try await actionService.fetchCompletions()
            isLoaded = true
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func update(input: String, tokens: [TokenSpan], tasks: [ApiTask]) {
        let context = CompletionEngine.detectContext(
            input: input,
            cursorPosition: cursorPosition,
            tokens: tokens
        )
        self.context = context

        let prefix = CompletionEngine.currentPrefix(
            input: input,
            cursorPosition: cursorPosition
        ).lowercased()

        let result = CompletionEngine.buildCompletions(
            context: context,
            prefix: prefix,
            cache: cache,
            tasks: tasks
        )

        items = result.items
        ghostText = result.ghostText

        if context != .none {
            selectedIndex = 0
        }
    }

    func toggleMenu(input: String, tokens: [TokenSpan], tasks: [ApiTask]) {
        if showMenu {
            showMenu = false
        } else {
            update(input: input, tokens: tokens, tasks: tasks)
            showMenu = !items.isEmpty
        }
    }

    func moveSelection(delta: Int) {
        guard !items.isEmpty else { return }
        let count = items.count
        selectedIndex = (selectedIndex + delta + count) % count
    }

    func clear() {
        items = []
        ghostText = nil
        showMenu = false
        selectedIndex = 0
        context = .none
    }

    func acceptGhostText() -> CompletionItem? {
        guard ghostText != nil, !items.isEmpty else { return nil }
        return items.first
    }

    func applyCompletion(_ item: CompletionItem?, input: String) -> (text: String, cursorPosition: Int)? {
        let completion = item ?? items[safe: selectedIndex]
        guard let completion else { return nil }
        return CompletionEngine.applyCompletion(
            input: input,
            cursorPosition: cursorPosition,
            completion: completion
        )
    }

    func updateCursorPosition(_ position: Int, input: String, tokens: [TokenSpan], tasks: [ApiTask]) {
        cursorPosition = position
        update(input: input, tokens: tokens, tasks: tasks)
    }
}
