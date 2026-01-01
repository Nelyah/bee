import SwiftUI

/// A text component that displays tags with overflow indicator.
///
/// When the number of tags exceeds `maxVisible`, shows "tag1, tag2 +N" format.
/// A tooltip displays the full list of tags on hover.
///
/// ## Usage
/// ```swift
/// TagsOverflowText(tags: ["api", "security", "backend"], maxVisible: 2)
/// // Displays: "api, security +1"
/// // Tooltip: "api, security, backend"
/// ```
struct TagsOverflowText: View {
    let tags: [String]
    let maxVisible: Int
    let font: Font
    let color: Color

    init(
        tags: [String],
        maxVisible: Int = 2,
        font: Font = .system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded),
        color: Color = ThemeManager.current.subtext1
    ) {
        self.tags = tags
        self.maxVisible = maxVisible
        self.font = font
        self.color = color
    }

    var body: some View {
        Text(displayText)
            .font(font)
            .foregroundColor(color)
            .lineLimit(1)
            .help(fullTagList)
    }

    private var displayText: String {
        guard !tags.isEmpty else { return "-" }

        let visibleTags = Array(tags.prefix(maxVisible))
        let visibleText = visibleTags.joined(separator: ", ")

        let overflow = tags.count - maxVisible
        if overflow > 0 {
            return "\(visibleText) +\(overflow)"
        }
        return visibleText
    }

    private var fullTagList: String {
        guard !tags.isEmpty else { return "No tags" }
        return tags.joined(separator: ", ")
    }
}

#Preview("No tags") {
    TagsOverflowText(tags: [])
        .padding()
        .background(ThemeManager.current.base)
}

#Preview("One tag") {
    TagsOverflowText(tags: ["api"])
        .padding()
        .background(ThemeManager.current.base)
}

#Preview("Two tags (max visible)") {
    TagsOverflowText(tags: ["api", "security"])
        .padding()
        .background(ThemeManager.current.base)
}

#Preview("Three tags (overflow)") {
    TagsOverflowText(tags: ["api", "security", "backend"])
        .padding()
        .background(ThemeManager.current.base)
}

#Preview("Many tags") {
    TagsOverflowText(tags: ["api", "security", "backend", "urgent", "review"])
        .padding()
        .background(ThemeManager.current.base)
}
