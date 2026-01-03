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
            DetailRow(label: "Project", value: currentProject ?? "None", helpText: nil)
                .modifier(DetailFocusRing(isFocused: isFocused))
                .contentShape(Rectangle())
                .onTapGesture {
                    onStartEditing()
                }
                .help(isFocused ? "Press Enter to edit" : "Click to edit")
        }
    }

    /// Finds the CompletionItem that matches the current project value.
    private var currentValue: CompletionItem? {
        guard let currentProject else { return nil }
        return allProjects.first { $0.value == currentProject }
    }
}
