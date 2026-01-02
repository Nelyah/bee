import SwiftUI

/// Editable project row with autocomplete support for the task detail view.
struct EditableProjectRow: View {
    let currentProject: String?
    let isEditing: Bool
    @Binding var editInput: String
    let isSubmitting: Bool
    let filteredProjects: [CompletionItem]
    let selectedIndex: Int
    let isFocused: Bool

    let onStartEditing: () -> Void
    let onSubmit: () -> Void
    let onSelectCompletion: (CompletionItem) -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DesignTokens.Spacing.medium) {
                    Text("Project")
                        .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                        .foregroundColor(ThemeManager.current.subtext0)
                        .frame(width: 80, alignment: .leading)

                    TextField("Project name...", text: $editInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: DesignTokens.TypeScale.body, weight: .regular, design: .monospaced))
                        .foregroundColor(ThemeManager.current.text)
                        .padding(.horizontal, DesignTokens.Spacing.small)
                        .padding(.vertical, DesignTokens.Spacing.extraSmall)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .fill(ThemeManager.current.surface1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .stroke(ThemeManager.current.blue, lineWidth: 2)
                        )
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.6 : 1.0)
                        .onSubmit {
                            onSubmit()
                        }
                        .focused($isTextFieldFocused)
                        // Autocomplete dropdown floats below text field using overlay
                        // (overlays don't participate in layout, preventing parent expansion)
                        .overlay(alignment: .topLeading) {
                            if !filteredProjects.isEmpty {
                                CompletionMenuView(
                                    items: filteredProjects,
                                    selectedIndex: selectedIndex,
                                    currentValue: currentProject,
                                    onSelect: onSelectCompletion
                                )
                                .frame(width: 200, height: 200)
                                .offset(y: 32)
                            }
                        }
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
            .onAppear {
                isTextFieldFocused = true
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
}
