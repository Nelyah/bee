import SwiftUI

/// An inline text field for entering annotation text.
struct AnnotationInputField: View {
    @Binding var text: String
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            TextField("Enter annotation...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: DesignTokens.TypeScale.bodySm))
                .foregroundColor(ThemeManager.current.text)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .disabled(isSubmitting)

            if isSubmitting {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        .foregroundColor(ThemeManager.current.subtext0)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
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
