@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for simple, low-complexity components.
///
/// This file contains tests for:
/// - HoverableButton
/// - QuietLinkButton
/// - TimelineRow
/// - ProjectScopeChipView
/// - TagsOverflowText
final class SimpleComponentsSnapshotTests: SnapshotTestCase {
    // MARK: - HoverableButton Tests

    func testHoverableButtonDefault() {
        let view = HoverableButton(action: {}) { isHovering in
            Text("Click Me")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isHovering ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(6)
        }

        assertViewSnapshot(view, size: CGSize(width: 150, height: 50))
    }

    func testHoverableButtonWithIcon() {
        let view = HoverableButton(action: {}) { isHovering in
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                Text("Favorite")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovering ? Color.yellow : Color.gray.opacity(0.3))
            .foregroundColor(isHovering ? .black : .primary)
            .cornerRadius(6)
        }

        assertViewSnapshot(view, size: CGSize(width: 150, height: 50))
    }

    func testHoverableLinkDefault() {
        let view = HoverableLink { isHovering in
            Text("Visit Site")
                .underline(isHovering)
                .foregroundColor(isHovering ? .blue : .primary)
        }

        assertViewSnapshot(view, size: CGSize(width: 150, height: 40))
    }

    // MARK: - QuietLinkButton Tests

    func testQuietLinkButtonDefault() {
        let view = QuietLinkButton(action: {}) { isHovering in
            Text("Quiet Link")
                .foregroundColor(isHovering ? .blue : .secondary)
                .underline(isHovering)
        }

        assertViewSnapshot(view, size: CGSize(width: 150, height: 40))
    }

    func testQuietLinkButtonWithIcon() {
        let view = QuietLinkButton(action: {}) { isHovering in
            HStack(spacing: 4) {
                Image(systemName: "arrow.right.circle")
                Text("Learn more")
            }
            .foregroundColor(isHovering ? .blue : .secondary)
        }

        assertViewSnapshot(view, size: CGSize(width: 150, height: 40))
    }

    func testQuietURLLinkDefault() {
        let view = QuietURLLink(
            text: "example.com",
            url: URL(string: "https://example.com")!
        )

        assertViewSnapshot(view, size: CGSize(width: 150, height: 40))
    }

    // MARK: - TimelineRow Tests

    func testTimelineRowDefault() {
        let view = TimelineRow(
            timestamp: "2024-01-15T10:30:00Z",
            value: "Task created"
        )

        assertViewSnapshot(view, size: CGSize(width: 400, height: 50))
    }

    func testTimelineRowWithLongValue() {
        let view = TimelineRow(
            timestamp: "2024-01-15T10:30:00Z",
            value: "Status changed from 'pending' to 'active' after review"
        )

        assertViewSnapshot(view, size: CGSize(width: 400, height: 60))
    }

    func testTimelineRowShortTimestamp() {
        let view = TimelineRow(
            timestamp: "2024-12-31T23:59:59Z",
            value: "New year update"
        )

        assertViewSnapshot(view, size: CGSize(width: 400, height: 50))
    }

    func testTimelineRowMultiple() {
        let view = VStack(spacing: 8) {
            TimelineRow(
                timestamp: "2024-01-18T14:00:00Z",
                value: "Latest update"
            )
            TimelineRow(
                timestamp: "2024-01-17T10:30:00Z",
                value: "Previous change"
            )
            TimelineRow(
                timestamp: "2024-01-15T08:00:00Z",
                value: "Initial creation"
            )
        }

        assertViewSnapshot(view, size: CGSize(width: 400, height: 180))
    }

    // MARK: - ProjectScopeChipView Tests

    func testProjectScopeChipDefault() {
        let view = ProjectScopeChipView(
            project: "my-project",
            onClear: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 200, height: 50))
    }

    func testProjectScopeChipShortName() {
        let view = ProjectScopeChipView(
            project: "api",
            onClear: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 150, height: 50))
    }

    func testProjectScopeChipLongName() {
        let view = ProjectScopeChipView(
            project: "very-long-project-name-here",
            onClear: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 300, height: 50))
    }

    func testProjectScopeChipSpecialCharacters() {
        let view = ProjectScopeChipView(
            project: "my-project.v2",
            onClear: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 200, height: 50))
    }

    // MARK: - TagsOverflowText Tests

    func testTagsOverflowTextEmpty() {
        let view = TagsOverflowText(tags: [])
            .frame(width: 100)
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 120, height: 30))
    }

    func testTagsOverflowTextSingleTag() {
        let view = TagsOverflowText(tags: ["api"])
            .frame(width: 100)
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 120, height: 30))
    }

    func testTagsOverflowTextTwoTags() {
        let view = TagsOverflowText(tags: ["api", "backend"])
            .frame(width: 100)
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 120, height: 30))
    }

    func testTagsOverflowTextWithOverflow() {
        let view = TagsOverflowText(tags: ["api", "backend", "urgent"])
            .frame(width: 100)
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 120, height: 30))
    }

    func testTagsOverflowTextManyTags() {
        let view = TagsOverflowText(tags: ["api", "backend", "urgent", "refactor", "testing"])
            .frame(width: 100)
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 120, height: 30))
    }

    func testTagsOverflowTextCustomMaxVisible() {
        let view = TagsOverflowText(tags: ["api", "backend", "urgent", "refactor"], maxVisible: 3)
            .frame(width: 150)
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 170, height: 30))
    }

    // MARK: - TagChip Tests

    func testTagChipDefault() {
        let view = TagChip(tag: "hobby", isSelected: false, onRemove: {})
            .padding()
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 120, height: 50))
    }

    func testTagChipSelected() {
        let view = TagChip(tag: "urgent", isSelected: true, onRemove: {})
            .padding()
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 120, height: 50))
    }

    func testTagChipLongName() {
        let view = TagChip(tag: "very-long-tag-name", isSelected: false, onRemove: {})
            .padding()
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 200, height: 50))
    }

    // MARK: - EditableTagsRow Tests

    func testEditableTagsRowEmpty() {
        let view = EditableTagsRow(
            tags: [],
            selectedTagIndex: nil,
            isAddingTag: false,
            tagAddQuery: .constant(""),
            allTagCompletions: [],
            isSubmitting: false,
            onSelectTagIndex: { _ in },
            onStartAdding: {},
            onCancelAdding: {},
            onSelectCompletion: { _ in },
            onRemoveTag: { _ in }
        )
        .padding()
        .frame(width: 350)
        .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 400, height: 80))
    }

    func testEditableTagsRowWithTags() {
        let view = EditableTagsRow(
            tags: ["hobby", "code", "urgent"],
            selectedTagIndex: nil,
            isAddingTag: false,
            tagAddQuery: .constant(""),
            allTagCompletions: [],
            isSubmitting: false,
            onSelectTagIndex: { _ in },
            onStartAdding: {},
            onCancelAdding: {},
            onSelectCompletion: { _ in },
            onRemoveTag: { _ in }
        )
        .padding()
        .frame(width: 350)
        .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 400, height: 80))
    }

    func testEditableTagsRowWithSelection() {
        let view = EditableTagsRow(
            tags: ["hobby", "code", "urgent"],
            selectedTagIndex: 1,
            isAddingTag: false,
            tagAddQuery: .constant(""),
            allTagCompletions: [],
            isSubmitting: false,
            onSelectTagIndex: { _ in },
            onStartAdding: {},
            onCancelAdding: {},
            onSelectCompletion: { _ in },
            onRemoveTag: { _ in }
        )
        .padding()
        .frame(width: 350)
        .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 400, height: 80))
    }

    func testEditableTagsRowManyTags() {
        let view = EditableTagsRow(
            tags: ["hobby", "code", "urgent", "review", "backend", "api"],
            selectedTagIndex: nil,
            isAddingTag: false,
            tagAddQuery: .constant(""),
            allTagCompletions: [],
            isSubmitting: false,
            onSelectTagIndex: { _ in },
            onStartAdding: {},
            onCancelAdding: {},
            onSelectCompletion: { _ in },
            onRemoveTag: { _ in }
        )
        .padding()
        .frame(width: 350)
        .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 400, height: 120))
    }
}
