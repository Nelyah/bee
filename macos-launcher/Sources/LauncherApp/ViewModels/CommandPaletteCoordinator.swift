import Foundation

@MainActor
final class CommandPaletteCoordinator: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var mode: CommandPaletteMode = .root
    @Published var query: String = ""
    @Published var selectionIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published private(set) var gitlabSuggestions: [GitlabMergeRequestSuggestion] = []
    @Published private(set) var jiraSuggestions: [JiraIssueSuggestion] = []

    func open(hasSelectedTask: Bool) -> String? {
        guard hasSelectedTask else {
            return "Select a task to add a link."
        }
        resetForOpen()
        isPresented = true
        return nil
    }

    func close() {
        isPresented = false
        resetForOpen()
    }

    func resetForOpen() {
        mode = .root
        query = ""
        selectionIndex = 0
    }

    func resetSelection() {
        selectionIndex = 0
    }

    var filteredActions: [CommandPaletteAction] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return CommandPaletteAction.allCases }
        return CommandPaletteAction.allCases.filter { fuzzyMatches(trimmed, in: $0.rawValue.lowercased()) }
    }

    var filteredSuggestions: [CommandPaletteSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        var items: [CommandPaletteSuggestion]

        switch mode {
        case .addGitlab:
            items = gitlabSuggestions
                .filter {
                    lower.isEmpty
                        || fuzzyMatches(lower, in: $0.title.lowercased())
                        || fuzzyMatches(lower, in: "\($0.id)")
                }
                .map { .gitlab($0) }
        case .addJira:
            items = jiraSuggestions
                .filter {
                    lower.isEmpty
                        || fuzzyMatches(lower, in: $0.summary.lowercased())
                        || fuzzyMatches(lower, in: $0.key.lowercased())
                }
                .map { .jira($0) }
        case .root:
            items = []
        }

        if !trimmed.isEmpty && mode != .root {
            items.insert(.rawInput(trimmed), at: 0)
        }

        return items
    }

    func selectAction(_ action: CommandPaletteAction) {
        switch action {
        case .addGitlab:
            mode = .addGitlab
        case .addJira:
            mode = .addJira
        }
        query = ""
        selectionIndex = 0
    }

    func loadSuggestions(apiClient: ApiClientProtocol) async -> String? {
        guard mode != .root else { return nil }
        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .addGitlab:
                let items = try await apiClient.fetchRecentGitlabMergeRequests(limit: 20)
                setGitlabSuggestions(items)
            case .addJira:
                let items = try await apiClient.fetchRecentJiraIssues(limit: 20, scope: .both)
                setJiraSuggestions(items)
            case .root:
                break
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func setGitlabSuggestions(_ items: [GitlabMergeRequestSuggestion]) {
        gitlabSuggestions = items
    }

    func setJiraSuggestions(_ items: [JiraIssueSuggestion]) {
        jiraSuggestions = items
    }

    func moveSelection(delta: Int, maxCount: Int) {
        guard maxCount > 0 else {
            selectionIndex = 0
            return
        }
        let next = max(0, min(selectionIndex + delta, maxCount - 1))
        selectionIndex = next
    }

    private func fuzzyMatches(_ query: String, in value: String) -> Bool {
        guard !query.isEmpty else { return true }
        var remaining = value[...]
        for char in query {
            guard let idx = remaining.firstIndex(of: char) else {
                return false
            }
            remaining = remaining[remaining.index(after: idx)...]
        }
        return true
    }
}
