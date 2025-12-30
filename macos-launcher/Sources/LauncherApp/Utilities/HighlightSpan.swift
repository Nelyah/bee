import AppKit

/// Highlight span categories for all recognized token types.
enum HighlightKind {
    case action         // WordString matching action name → blue
    case tag            // TagPlusPrefix, TagMinusPrefix → peach
    case project        // ProjectPrefix → mauve
    case dateFilter     // due:, due.before:, due.after:, created.*, end.* → teal
    case status         // FilterStatus → pink
    case dependency     // DependsOn → lavender
    case logicalOp      // OperatorAnd, OperatorOr, OperatorXor → sky
    case parenthesis    // LeftParenthesis, RightParenthesis → flamingo
    case identifier     // Uuid, Int → rosewater
}

/// Describes a highlighted span in the input text.
struct HighlightSpan {
    let start: Int
    let end: Int
    let kind: HighlightKind
}

/// Build highlight spans for all recognized token types.
func buildHighlightSpans(tokens: [TokenSpan], actionName: String) -> [HighlightSpan] {
    var spans: [HighlightSpan] = []
    let lowerAction = actionName.lowercased()
    var index = 0

    while index < tokens.count {
        let token = tokens[index]
        let tokenType = token.tokenType

        // Tags: +tag or -tag (prefix + following WordStrings)
        if TokenClassifier.isTagPrefix(tokenType) {
            let start = token.start
            var end = token.end
            var nextIndex = index + 1
            while nextIndex < tokens.count,
                  tokens[nextIndex].tokenType == .wordString,
                  tokens[nextIndex].start == end {
                end = tokens[nextIndex].end
                nextIndex += 1
            }
            if end > start {
                spans.append(HighlightSpan(start: start, end: end, kind: .tag))
            }
            index = nextIndex
            continue
        }

        // Projects: project:value or proj:value
        if TokenClassifier.isProjectPrefix(tokenType) {
            let start = token.start
            var end = token.end
            var nextIndex = index + 1
            while nextIndex < tokens.count,
                  tokens[nextIndex].tokenType == .wordString,
                  tokens[nextIndex].start == end {
                end = tokens[nextIndex].end
                nextIndex += 1
            }
            if end > start {
                spans.append(HighlightSpan(start: start, end: end, kind: .project))
            }
            index = nextIndex
            continue
        }

        // Date filters: due:, due.before:, due.after:, created.*, end.*
        if TokenClassifier.isDateFilter(tokenType) {
            let start = token.start
            var end = token.end
            var nextIndex = index + 1
            // Include following value tokens
            while nextIndex < tokens.count,
                  tokens[nextIndex].start == end,
                  tokens[nextIndex].tokenType != .blank {
                end = tokens[nextIndex].end
                nextIndex += 1
            }
            spans.append(HighlightSpan(start: start, end: end, kind: .dateFilter))
            index = nextIndex
            continue
        }

        // Status filter: status:value
        if TokenClassifier.isStatusFilter(tokenType) {
            let start = token.start
            var end = token.end
            var nextIndex = index + 1
            while nextIndex < tokens.count,
                  tokens[nextIndex].start == end,
                  tokens[nextIndex].tokenType == .wordString {
                end = tokens[nextIndex].end
                nextIndex += 1
            }
            spans.append(HighlightSpan(start: start, end: end, kind: .status))
            index = nextIndex
            continue
        }

        // Dependencies: depends:uuid
        if TokenClassifier.isDependency(tokenType) {
            let start = token.start
            var end = token.end
            var nextIndex = index + 1
            while nextIndex < tokens.count,
                  tokens[nextIndex].start == end,
                  tokens[nextIndex].tokenType != .blank {
                end = tokens[nextIndex].end
                nextIndex += 1
            }
            spans.append(HighlightSpan(start: start, end: end, kind: .dependency))
            index = nextIndex
            continue
        }

        // Logical operators: and, or, xor
        if TokenClassifier.isLogicalOperator(tokenType) {
            spans.append(HighlightSpan(start: token.start, end: token.end, kind: .logicalOp))
            index += 1
            continue
        }

        // Parentheses
        if TokenClassifier.isParenthesis(tokenType) {
            spans.append(HighlightSpan(start: token.start, end: token.end, kind: .parenthesis))
            index += 1
            continue
        }

        // Identifiers: UUID and Int
        if TokenClassifier.isIdentifier(tokenType) {
            spans.append(HighlightSpan(start: token.start, end: token.end, kind: .identifier))
            index += 1
            continue
        }

        // Action name match
        if tokenType == .wordString,
           !lowerAction.isEmpty,
           token.literal.lowercased() == lowerAction {
            spans.append(HighlightSpan(start: token.start, end: token.end, kind: .action))
        }

        index += 1
    }
    return spans
}

/// Map highlight kinds to One Dark colors.
func highlightColor(for kind: HighlightKind) -> NSColor {
    switch kind {
    case .action:
        return ThemeManager.current.blueNS
    case .tag:
        return ThemeManager.current.peachNS
    case .project:
        return ThemeManager.current.mauveNS
    case .dateFilter:
        return ThemeManager.current.tealNS
    case .status:
        return ThemeManager.current.pinkNS
    case .dependency:
        return ThemeManager.current.lavenderNS
    case .logicalOp:
        return ThemeManager.current.skyNS
    case .parenthesis:
        return ThemeManager.current.flamingoNS
    case .identifier:
        return ThemeManager.current.rosewaterNS
    }
}

/// Build an attributed string with token highlights using One Dark theme.
func highlightedText(text: String, tokens: [TokenSpan], actionName: String) -> NSAttributedString {
    let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .medium),
        .foregroundColor: ThemeManager.current.textNS
    ]
    let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)

    for span in buildHighlightSpans(tokens: tokens, actionName: actionName) {
        guard let range = nsRange(start: span.start, end: span.end, in: text) else { continue }
        let background = highlightColor(for: span.kind).withAlphaComponent(0.3)
        attributed.addAttributes([.backgroundColor: background], range: range)
    }
    return attributed
}

/// Convert a span range to UTF-16 ranges for attributed strings.
func nsRange(start: Int, end: Int, in text: String) -> NSRange? {
    guard start <= end else { return nil }
    guard let startIndex = text.index(text.startIndex, offsetBy: start, limitedBy: text.endIndex),
          let endIndex = text.index(text.startIndex, offsetBy: end, limitedBy: text.endIndex) else {
        return nil
    }
    return NSRange(startIndex..<endIndex, in: text)
}
