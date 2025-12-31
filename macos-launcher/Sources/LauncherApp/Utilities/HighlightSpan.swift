import AppKit

/// Highlight span categories for all recognized token types.
enum HighlightKind {
    case action // WordString matching action name → blue
    case tag // TagPlusPrefix, TagMinusPrefix → peach
    case project // ProjectPrefix → mauve
    case dateFilter // due:, due.before:, due.after:, created.*, end.* → teal
    case status // FilterStatus → pink
    case dependency // DependsOn → lavender
    case logicalOp // OperatorAnd, OperatorOr, OperatorXor → sky
    case parenthesis // LeftParenthesis, RightParenthesis → flamingo
    case identifier // Uuid, Int → rosewater
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
        let result = processToken(token, at: index, in: tokens, lowerAction: lowerAction)
        if let span = result.span {
            spans.append(span)
        }
        index = result.nextIndex
    }
    return spans
}

private func processToken(
    _ token: TokenSpan,
    at index: Int,
    in tokens: [TokenSpan],
    lowerAction: String
) -> (span: HighlightSpan?, nextIndex: Int) {
    let tokenType = token.tokenType

    // Prefix-based tokens that collect following WordStrings
    if let kind = prefixTokenKind(tokenType) {
        let (end, nextIndex) = collectContiguousTokens(from: index, in: tokens, matching: { $0 == .wordString })
        let span = end > token.start ? HighlightSpan(start: token.start, end: end, kind: kind) : nil
        return (span, nextIndex)
    }

    // Date/dependency filters that collect any non-blank tokens
    if let kind = filterTokenKind(tokenType) {
        let (end, nextIndex) = collectContiguousTokens(from: index, in: tokens, matching: { $0 != .blank })
        return (HighlightSpan(start: token.start, end: end, kind: kind), nextIndex)
    }

    // Single-token highlights
    if let kind = simpleTokenKind(tokenType) {
        return (HighlightSpan(start: token.start, end: token.end, kind: kind), index + 1)
    }

    // Action name match
    if tokenType == .wordString, !lowerAction.isEmpty, token.literal.lowercased() == lowerAction {
        return (HighlightSpan(start: token.start, end: token.end, kind: .action), index + 1)
    }

    return (nil, index + 1)
}

private func prefixTokenKind(_ tokenType: TokenType) -> HighlightKind? {
    if TokenClassifier.isTagPrefix(tokenType) { return .tag }
    if TokenClassifier.isProjectPrefix(tokenType) { return .project }
    if TokenClassifier.isStatusFilter(tokenType) { return .status }
    return nil
}

private func filterTokenKind(_ tokenType: TokenType) -> HighlightKind? {
    if TokenClassifier.isDateFilter(tokenType) { return .dateFilter }
    if TokenClassifier.isDependency(tokenType) { return .dependency }
    return nil
}

private func simpleTokenKind(_ tokenType: TokenType) -> HighlightKind? {
    if TokenClassifier.isLogicalOperator(tokenType) { return .logicalOp }
    if TokenClassifier.isParenthesis(tokenType) { return .parenthesis }
    if TokenClassifier.isIdentifier(tokenType) { return .identifier }
    return nil
}

private func collectContiguousTokens(
    from index: Int,
    in tokens: [TokenSpan],
    matching predicate: (TokenType) -> Bool
) -> (end: Int, nextIndex: Int) {
    var end = tokens[index].end
    var nextIndex = index + 1
    while nextIndex < tokens.count,
          predicate(tokens[nextIndex].tokenType),
          tokens[nextIndex].start == end {
        end = tokens[nextIndex].end
        nextIndex += 1
    }
    return (end, nextIndex)
}

/// Map highlight kinds to One Dark colors.
func highlightColor(for kind: HighlightKind) -> NSColor {
    switch kind {
    case .action:
        ThemeManager.current.blueNS
    case .tag:
        ThemeManager.current.peachNS
    case .project:
        ThemeManager.current.mauveNS
    case .dateFilter:
        ThemeManager.current.tealNS
    case .status:
        ThemeManager.current.pinkNS
    case .dependency:
        ThemeManager.current.lavenderNS
    case .logicalOp:
        ThemeManager.current.skyNS
    case .parenthesis:
        ThemeManager.current.flamingoNS
    case .identifier:
        ThemeManager.current.rosewaterNS
    }
}

/// Build an attributed string with token highlights using One Dark theme.
func highlightedText(text: String, tokens: [TokenSpan], actionName: String) -> NSAttributedString {
    let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .medium),
        .foregroundColor: ThemeManager.current.textNS,
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
          let endIndex = text.index(text.startIndex, offsetBy: end, limitedBy: text.endIndex)
    else {
        return nil
    }
    return NSRange(startIndex ..< endIndex, in: text)
}
