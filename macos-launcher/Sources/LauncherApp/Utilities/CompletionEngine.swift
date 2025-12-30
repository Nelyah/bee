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

        if beforeCursor.hasSuffix("+") || beforeCursor.hasSuffix("-") {
            return .tag
        }
        if beforeCursor.hasSuffix("project:") || beforeCursor.hasSuffix("proj:") {
            return .project
        }
        if beforeCursor.hasSuffix("status:") {
            return .status
        }
        if beforeCursor.hasSuffix("due:") || beforeCursor.hasSuffix("due.before:") ||
           beforeCursor.hasSuffix("due.after:") || beforeCursor.hasSuffix("created.before:") ||
           beforeCursor.hasSuffix("created.after:") || beforeCursor.hasSuffix("end.before:") ||
           beforeCursor.hasSuffix("end.after:") {
            return .date
        }
        if beforeCursor.hasSuffix("depends:") {
            return .taskRef
        }

        if lastWord.hasPrefix("project:") || lastWord.hasPrefix("proj:") {
            return .project
        }
        if lastWord.hasPrefix("status:") {
            return .status
        }
        if lastWord.hasPrefix("due:") || lastWord.hasPrefix("due.before:") ||
            lastWord.hasPrefix("due.after:") || lastWord.hasPrefix("created.before:") ||
            lastWord.hasPrefix("created.after:") || lastWord.hasPrefix("end.before:") ||
            lastWord.hasPrefix("end.after:") {
            return .date
        }
        if lastWord.hasPrefix("depends:") {
            return .taskRef
        }

        if !beforeCursor.contains(" ") && !beforeCursor.isEmpty {
            return .action
        }

        return .none
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
            source = cache.actions
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
        if let first = items.first, !prefix.isEmpty {
            let suffix = String(first.value.dropFirst(prefix.count))
            ghostText = suffix.isEmpty ? nil : suffix
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
