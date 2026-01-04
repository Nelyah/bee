import SwiftUI

/// Editable project row with autocomplete support for the task detail view.
///
/// Now uses the reusable `CompletionField` component for all completion logic.
struct EditableProjectRow: View {
    let currentProject: String?
    let isEditing: Bool
    @Binding var editInput: String
    let isSubmitting: Bool
    let allProjects: [CompletionItem] // All available projects (fuzzy filtering done by CompletionField)
    let isFocused: Bool

    let onStartEditing: () -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onSelectCompletion: (CompletionItem) -> Void

    @State private var isHovering = false

    var body: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DesignTokens.Spacing.medium) {
                    Text("Project")
                        .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                        .foregroundColor(ThemeManager.current.subtext0)
                        .frame(width: 80, alignment: .leading)

                    // Use the reusable CompletionField component
                    CompletionField(
                        text: $editInput,
                        placeholder: "Project name...",
                        items: allProjects,
                        currentValue: currentValue,
                        onSubmit: onSubmit,
                        onCancel: onCancel,
                        onSelect: onSelectCompletion,
                        theme: .default,
                        minWidth: 200,
                        minHeight: 200,
                        maxHeight: 200,
                        allowsFreeformEntry: false
                    )
                    .disabled(isSubmitting)
                    .opacity(isSubmitting ? 0.6 : 1.0)
                }

                if isSubmitting {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }
                    .padding(.top, DesignTokens.Spacing.extraSmall)
                }
            }
        } else {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.large) {
                Text("PROJECT")
                    .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
                    .frame(width: 90, alignment: .leading)

                Text(currentProject ?? "None")
                    .font(.system(size: DesignTokens.TypeScale.body, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                    .help(currentProject ?? "None")
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .background(
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(isHovering ? ThemeManager.current.surface1.opacity(0.5) : Color.clear)
                        .frame(
                            width: geo.size.width + 2 * DesignTokens.Spacing.small,
                            height: geo.size.height + 2 * DesignTokens.Spacing.extraSmall
                        )
                        .offset(
                            x: -DesignTokens.Spacing.small,
                            y: -DesignTokens.Spacing.extraSmall
                        )
                }
            )
            .modifier(DetailFocusRing(isFocused: isFocused))
            .contentShape(Rectangle())
            .onTapGesture {
                onStartEditing()
            }
            .onHover { isHovering = $0 }
            .help(isFocused ? "Press Enter to edit" : "Click to edit")
        }
    }

    /// Finds the CompletionItem that matches the current project value.
    private var currentValue: CompletionItem? {
        guard let currentProject else { return nil }
        return allProjects.first { $0.value == currentProject }
    }
}
