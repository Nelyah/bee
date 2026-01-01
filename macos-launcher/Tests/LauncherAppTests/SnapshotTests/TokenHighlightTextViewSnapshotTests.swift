@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for TokenHighlightTextView syntax highlighting.
///
/// Tests various token highlighting states including action keywords,
/// tags, projects, status filters, and ghost text autocomplete.
final class TokenHighlightTextViewSnapshotTests: SnapshotTestCase {
    // MARK: - Empty and Plain Text

    func testEmptyInput() {
        let view = makeTokenHighlightTextView(text: "", tokens: [])
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    func testPlainText() {
        let view = makeTokenHighlightTextView(
            text: "hello world",
            tokens: [
                TokenSpan(tokenType: .wordString, literal: "hello", start: 0, end: 5),
                TokenSpan(tokenType: .blank, literal: " ", start: 5, end: 6),
                TokenSpan(tokenType: .wordString, literal: "world", start: 6, end: 11),
            ]
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    // MARK: - Action Highlighting

    func testWithActionHighlight() {
        let view = makeTokenHighlightTextView(
            text: "list",
            tokens: [
                TokenSpan(tokenType: .wordString, literal: "list", start: 0, end: 4),
            ],
            actionName: "list"
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    func testWithAddAction() {
        let view = makeTokenHighlightTextView(
            text: "add new task",
            tokens: [
                TokenSpan(tokenType: .wordString, literal: "add", start: 0, end: 3),
                TokenSpan(tokenType: .blank, literal: " ", start: 3, end: 4),
                TokenSpan(tokenType: .wordString, literal: "new", start: 4, end: 7),
                TokenSpan(tokenType: .blank, literal: " ", start: 7, end: 8),
                TokenSpan(tokenType: .wordString, literal: "task", start: 8, end: 12),
            ],
            actionName: "add"
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    // MARK: - Tag Highlighting

    func testWithTagHighlight() {
        let view = makeTokenHighlightTextView(
            text: "+work",
            tokens: [
                TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 0, end: 1),
                TokenSpan(tokenType: .wordString, literal: "work", start: 1, end: 5),
            ]
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    func testWithMinusTag() {
        let view = makeTokenHighlightTextView(
            text: "-personal",
            tokens: [
                TokenSpan(tokenType: .tagMinusPrefix, literal: "-", start: 0, end: 1),
                TokenSpan(tokenType: .wordString, literal: "personal", start: 1, end: 9),
            ]
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    // MARK: - Project Highlighting

    func testWithProjectHighlight() {
        let view = makeTokenHighlightTextView(
            text: "project:api",
            tokens: [
                TokenSpan(tokenType: .projectPrefix, literal: "project:", start: 0, end: 8),
                TokenSpan(tokenType: .wordString, literal: "api", start: 8, end: 11),
            ]
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    // MARK: - Status Highlighting

    func testWithStatusHighlight() {
        let view = makeTokenHighlightTextView(
            text: "status:pending",
            tokens: [
                TokenSpan(tokenType: .filterStatus, literal: "status:", start: 0, end: 7),
                TokenSpan(tokenType: .wordString, literal: "pending", start: 7, end: 14),
            ]
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    // MARK: - Logical Operators

    func testWithLogicalOperators() {
        let view = makeTokenHighlightTextView(
            text: "+work and +urgent",
            tokens: [
                TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 0, end: 1),
                TokenSpan(tokenType: .wordString, literal: "work", start: 1, end: 5),
                TokenSpan(tokenType: .blank, literal: " ", start: 5, end: 6),
                TokenSpan(tokenType: .operatorAnd, literal: "and", start: 6, end: 9),
                TokenSpan(tokenType: .blank, literal: " ", start: 9, end: 10),
                TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 10, end: 11),
                TokenSpan(tokenType: .wordString, literal: "urgent", start: 11, end: 17),
            ]
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    func testWithOrOperator() {
        let view = makeTokenHighlightTextView(
            text: "status:pending or status:active",
            tokens: [
                TokenSpan(tokenType: .filterStatus, literal: "status:", start: 0, end: 7),
                TokenSpan(tokenType: .wordString, literal: "pending", start: 7, end: 14),
                TokenSpan(tokenType: .blank, literal: " ", start: 14, end: 15),
                TokenSpan(tokenType: .operatorOr, literal: "or", start: 15, end: 17),
                TokenSpan(tokenType: .blank, literal: " ", start: 17, end: 18),
                TokenSpan(tokenType: .filterStatus, literal: "status:", start: 18, end: 25),
                TokenSpan(tokenType: .wordString, literal: "active", start: 25, end: 31),
            ]
        )
        assertViewSnapshot(view, size: CGSize(width: 500, height: 50))
    }

    // MARK: - Complex Input

    func testWithMultipleTokenTypes() {
        let view = makeTokenHighlightTextView(
            text: "list +work project:api",
            tokens: TestHelpers.sampleTokens,
            actionName: "list"
        )
        assertViewSnapshot(view, size: CGSize(width: 400, height: 50))
    }

    func testComplexQueryWithParentheses() {
        let view = makeTokenHighlightTextView(
            text: "(+work or +urgent) and project:api",
            tokens: [
                TokenSpan(tokenType: .leftParenthesis, literal: "(", start: 0, end: 1),
                TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 1, end: 2),
                TokenSpan(tokenType: .wordString, literal: "work", start: 2, end: 6),
                TokenSpan(tokenType: .blank, literal: " ", start: 6, end: 7),
                TokenSpan(tokenType: .operatorOr, literal: "or", start: 7, end: 9),
                TokenSpan(tokenType: .blank, literal: " ", start: 9, end: 10),
                TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 10, end: 11),
                TokenSpan(tokenType: .wordString, literal: "urgent", start: 11, end: 17),
                TokenSpan(tokenType: .rightParenthesis, literal: ")", start: 17, end: 18),
                TokenSpan(tokenType: .blank, literal: " ", start: 18, end: 19),
                TokenSpan(tokenType: .operatorAnd, literal: "and", start: 19, end: 22),
                TokenSpan(tokenType: .blank, literal: " ", start: 22, end: 23),
                TokenSpan(tokenType: .projectPrefix, literal: "project:", start: 23, end: 31),
                TokenSpan(tokenType: .wordString, literal: "api", start: 31, end: 34),
            ]
        )
        assertViewSnapshot(view, size: CGSize(width: 500, height: 50))
    }

    // MARK: - Ghost Text

    func testWithGhostText() {
        let view = makeTokenHighlightTextView(
            text: "proj",
            tokens: [
                TokenSpan(tokenType: .wordString, literal: "proj", start: 0, end: 4),
            ],
            ghostText: "ect:api"
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    func testWithGhostTextAfterTag() {
        let view = makeTokenHighlightTextView(
            text: "+wo",
            tokens: [
                TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 0, end: 1),
                TokenSpan(tokenType: .wordString, literal: "wo", start: 1, end: 3),
            ],
            ghostText: "rk"
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    // MARK: - Focus States

    func testFocusedState() {
        let view = makeTokenHighlightTextView(
            text: "list +work",
            tokens: [
                TokenSpan(tokenType: .wordString, literal: "list", start: 0, end: 4),
                TokenSpan(tokenType: .blank, literal: " ", start: 4, end: 5),
                TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 5, end: 6),
                TokenSpan(tokenType: .wordString, literal: "work", start: 6, end: 10),
            ],
            actionName: "list",
            isFocused: true
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    func testUnfocusedState() {
        let view = makeTokenHighlightTextView(
            text: "list +work",
            tokens: [
                TokenSpan(tokenType: .wordString, literal: "list", start: 0, end: 4),
                TokenSpan(tokenType: .blank, literal: " ", start: 4, end: 5),
                TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 5, end: 6),
                TokenSpan(tokenType: .wordString, literal: "work", start: 6, end: 10),
            ],
            actionName: "list",
            isFocused: false
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    // MARK: - Date Filters

    func testWithDueDateFilter() {
        let view = makeTokenHighlightTextView(
            text: "due:tomorrow",
            tokens: [
                TokenSpan(tokenType: .filterTokDateDue, literal: "due:", start: 0, end: 4),
                TokenSpan(tokenType: .wordString, literal: "tomorrow", start: 4, end: 12),
            ]
        )
        assertViewSnapshot(view, size: TestSizes.tokenInput)
    }

    // MARK: - Helper

    /// Create a TokenHighlightTextView with test-friendly defaults.
    private func makeTokenHighlightTextView(
        text: String,
        tokens: [TokenSpan],
        actionName: String = "",
        isFocused: Bool = false,
        ghostText: String? = nil,
        cursorPosition: Int? = nil
    ) -> some View {
        StatefulTokenHighlightTextView(
            initialText: text,
            tokens: tokens,
            actionName: actionName,
            isFocused: isFocused,
            ghostText: ghostText,
            cursorPosition: cursorPosition ?? text.count
        )
    }
}

/// Wrapper view that provides @State for the text binding.
private struct StatefulTokenHighlightTextView: View {
    @State private var text: String

    let tokens: [TokenSpan]
    let actionName: String
    let isFocused: Bool
    let ghostText: String?
    let cursorPosition: Int

    init(
        initialText: String,
        tokens: [TokenSpan],
        actionName: String,
        isFocused: Bool,
        ghostText: String?,
        cursorPosition: Int
    ) {
        _text = State(initialValue: initialText)
        self.tokens = tokens
        self.actionName = actionName
        self.isFocused = isFocused
        self.ghostText = ghostText
        self.cursorPosition = cursorPosition
    }

    var body: some View {
        TokenHighlightTextView(
            text: $text,
            tokens: tokens,
            actionName: actionName,
            isFocused: isFocused,
            ghostText: ghostText,
            cursorPosition: cursorPosition,
            showCompletionMenu: false,
            onSubmit: {},
            onEscape: {},
            onMoveSelection: { _ in },
            onCursorChange: { _ in },
            onToggleMenu: {},
            onAcceptGhost: {},
            onMenuNavigation: { _ in },
            onAcceptCompletion: {},
            onRequestFocus: { true }
        )
        .frame(height: 40)
        .padding(.horizontal, 8)
        .background(ThemeManager.current.surface0)
    }
}
