struct CompletionCache {
    var projects: [CompletionItem] = []
    var tags: [CompletionItem] = []
    var actions: [CompletionItem] = []
    var status: [CompletionItem] = []
    var dates: [CompletionItem] = []
}

struct CompletionResult {
    let items: [CompletionItem]
    let ghostText: String?
}

struct CompletionEngine {
    private static let tagSuffixes = ["+", "-"]
    private static let projectPrefixes = ["project:", "proj:"]
    private static let statusPrefixes = ["status:"]
    private static let datePrefixes = [
        "due:",
        "due.before:",
        "due.after:",
        "created.before:",
        "created.after:",
        "end.before:",
        "end.after:"
    ]
    private static let dependencyPrefixes = ["depends:"]
    private static let filterKeywords = [
        "status:",
        "project:",
        "proj:",
        "due:",
        "due.before:",
        "due.after:",
        "created.before:",
        "created.after:",
        "end.before:",
        "end.after:",
        "depends:"
    ]

    static func detectContext(input: String, cursorPosition: Int, tokens: [TokenSpan]) -> CompletionContext {
        let pos = min(cursorPosition, input.count)
        let beforeCursor = String(input.prefix(pos))
        let lastWord = lastWordBeforeCursor(beforeCursor)

        if let lastToken = tokens.last(where: { $0.end <= pos }) {
            let tokenType = lastToken.tokenType
            if TokenClassifier.isTagPrefix(tokenType) {
                return .tag
            }
            if TokenClassifier.isProjectPrefix(tokenType) {
                return .project
            }
            if TokenClassifier.isStatusFilter(tokenType) {
                return .status
            }
            if TokenClassifier.isDateFilter(tokenType) {
                return .date
            }
            if TokenClassifier.isDependency(tokenType) {
                return .taskRef
            }
        }

        if hasSuffix(beforeCursor, in: tagSuffixes) {
            return .tag
        }
        if hasSuffix(beforeCursor, in: projectPrefixes) {
            return .project
        }
        if hasSuffix(beforeCursor, in: statusPrefixes) {
            return .status
        }
        if hasSuffix(beforeCursor, in: datePrefixes) {
            return .date
        }
        if hasSuffix(beforeCursor, in: dependencyPrefixes) {
            return .taskRef
        }

        if hasPrefix(lastWord, in: projectPrefixes) {
            return .project
        }
        if hasPrefix(lastWord, in: statusPrefixes) {
            return .status
        }
        if hasPrefix(lastWord, in: datePrefixes) {
            return .date
        }
        if hasPrefix(lastWord, in: dependencyPrefixes) {
            return .taskRef
        }

        if !lastWord.isEmpty && !lastWord.contains(":") {
            return .action
        }

        return .none
    }

    private static func hasSuffix(_ text: String, in candidates: [String]) -> Bool {
        candidates.contains { text.hasSuffix($0) }
    }

    private static func hasPrefix(_ text: String, in candidates: [String]) -> Bool {
        candidates.contains { text.hasPrefix($0) }
    }

    private static func mergedActions(_ actions: [CompletionItem]) -> [CompletionItem] {
        var merged = actions
        let existing = Set(actions.map { $0.value })
        for keyword in filterKeywords where !existing.contains(keyword) {
            merged.append(CompletionItem(value: keyword, count: nil))
        }
        return merged
    }

    static func currentPrefix(input: String, cursorPosition: Int) -> String {
        let pos = min(cursorPosition, input.count)
        let beforeCursor = String(input.prefix(pos))

        var wordStart = beforeCursor.count
        for (i, char) in beforeCursor.enumerated().reversed() {
            if char == " " || char == ":" || char == "+" || char == "-" {
                wordStart = i + 1
                break
            }
            if i == 0 {
                wordStart = 0
            }
        }

        return String(beforeCursor.dropFirst(wordStart))
    }

    static func buildCompletions(
        context: CompletionContext,
        prefix: String,
        cache: CompletionCache,
        tasks: [ApiTask]
    ) -> CompletionResult {
        let source: [CompletionItem]
        switch context {
        case .action:
            source = mergedActions(cache.actions)
        case .tag:
            source = cache.tags
        case .project:
            source = cache.projects
        case .status:
            source = cache.status
        case .date:
            source = cache.dates
        case .taskRef:
            source = tasks.map { CompletionItem(value: String($0.uuid.prefix(8)), count: nil) }
        case .none:
            return CompletionResult(items: [], ghostText: nil)
        }

        let items: [CompletionItem]
        if prefix.isEmpty {
            items = source
        } else {
            items = source.filter { $0.value.lowercased().hasPrefix(prefix) }
        }

        let ghostText: String?
        if let first = items.first, (!prefix.isEmpty || context != .action) {
            if prefix.isEmpty {
                ghostText = first.value
            } else {
                let suffix = String(first.value.dropFirst(prefix.count))
                ghostText = suffix.isEmpty ? nil : suffix
            }
        } else {
            ghostText = nil
        }

        return CompletionResult(items: items, ghostText: ghostText)
    }

    static func applyCompletion(
        input: String,
        cursorPosition: Int,
        completion: CompletionItem
    ) -> (text: String, cursorPosition: Int) {
        let prefix = currentPrefix(input: input, cursorPosition: cursorPosition)
        let pos = min(cursorPosition, input.count)
        let prefixStart = pos - prefix.count
        guard prefixStart >= 0 else { return (input, cursorPosition) }

        var newInput = input
        let startIndex = newInput.index(newInput.startIndex, offsetBy: prefixStart)
        let endIndex = newInput.index(newInput.startIndex, offsetBy: pos)
        newInput.replaceSubrange(startIndex..<endIndex, with: completion.value)

        return (newInput, prefixStart + completion.value.count)
    }

    private static func lastWordBeforeCursor(_ beforeCursor: String) -> String {
        beforeCursor.split(whereSeparator: { $0 == " " })
            .last
            .map(String.init) ?? ""
    }
}
