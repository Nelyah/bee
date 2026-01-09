import SwiftUI

/// A timeline row that can be tapped to enter edit mode.
///
/// Used in TaskDetailView to display annotations that can be edited.
/// Supports keyboard navigation via hjkl keys with focus ring highlighting.
struct EditableTimelineRow: View {
    let timestamp: String
    let value: String
    let annotation: TaskAnnotationDto
    let focusedItem: DetailFocusableItem?
    let onTap: () -> Void

    @State private var isHovering: Bool = false

    /// Whether this annotation is currently keyboard-focused
    private var isFocused: Bool {
        if case let .annotation(focusedAnnotation) = focusedItem {
            return focusedAnnotation.id == annotation.id
        }
        return false
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
            Text(RelativeDateFormatter.description(for: timestamp))
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 90, alignment: .leading)
                .help(timestamp)
            Text(value)
                .font(.system(size: DesignTokens.TypeScale.body, weight: .regular))
                .foregroundColor(ThemeManager.current.annotationText)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, DesignTokens.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .fill(isHovering ? ThemeManager.current.surfaceHover : ThemeManager.current.surface1.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .stroke(isHovering ? ThemeManager.current.blue.opacity(0.5) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onTap()
        }
        .navigationRegistrable(.annotation(annotation))
        .modifier(DetailFocusRing(isFocused: isFocused))
        .help(isFocused ? "Press Enter to edit" : "Click to edit")
    }
}
