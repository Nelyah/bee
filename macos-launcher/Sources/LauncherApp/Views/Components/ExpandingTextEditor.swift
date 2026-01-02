import SwiftUI

/// A multiline text editor that grows vertically with content.
///
/// Features:
/// - Auto-expands as text grows (no max height)
/// - Auto-focuses on appear
/// - Cmd+Enter to submit
/// - Escape to cancel
/// - Shows loading indicator during submission
/// - Focus ring styling (blue border when focused)
struct ExpandingTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    /// Minimum height for the editor
    var minHeight: CGFloat = 32

    @FocusState private var isFocused: Bool
    @State private var textHeight: CGFloat = 32

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
            ZStack(alignment: .topLeading) {
                // Placeholder text
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: DesignTokens.TypeScale.body))
                        .foregroundColor(ThemeManager.current.overlay0)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                // The actual text editor
                TextEditor(text: $text)
                    .font(.system(size: DesignTokens.TypeScale.body))
                    .foregroundColor(ThemeManager.current.annotationText)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .disabled(isSubmitting)
                    .frame(minHeight: minHeight)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Submit/cancel controls
            VStack(spacing: DesignTokens.Spacing.extraSmall) {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    // Cancel button
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                            .foregroundColor(ThemeManager.current.subtext0)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .help("Cancel (Esc)")

                    // Submit button
                    Button(action: onSubmit) {
                        Image(systemName: "checkmark")
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                            .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? ThemeManager.current.overlay0
                                : ThemeManager.current.blue)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Submit (⌘↩)")
                }
            }
            .padding(.top, DesignTokens.Spacing.extraSmall)
        }
        .padding(.horizontal, DesignTokens.Spacing.small)
        .padding(.vertical, DesignTokens.Spacing.extraSmall)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .fill(ThemeManager.current.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .stroke(
                    isFocused ? ThemeManager.current.blue : ThemeManager.current.surface2,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Preview

#Preview("Empty") {
    ExpandingTextEditor(
        text: .constant(""),
        placeholder: "Enter annotation...",
        isSubmitting: false,
        onSubmit: {},
        onCancel: {}
    )
    .padding()
    .background(ThemeManager.current.base)
}

#Preview("With Text") {
    ExpandingTextEditor(
        text: .constant(
            "This is a longer annotation that might span multiple lines when the content is extensive enough to wrap."
        ),
        placeholder: "Enter annotation...",
        isSubmitting: false,
        onSubmit: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 400)
    .background(ThemeManager.current.base)
}

#Preview("Submitting") {
    ExpandingTextEditor(
        text: .constant("Submitting this annotation..."),
        placeholder: "Enter annotation...",
        isSubmitting: true,
        onSubmit: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 400)
    .background(ThemeManager.current.base)
}
