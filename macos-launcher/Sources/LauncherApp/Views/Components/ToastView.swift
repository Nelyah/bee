import SwiftUI

/// Visual representation of a toast message.
struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            toastIcon
            Text(toast.message)
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                .foregroundStyle(ThemeManager.current.text)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, DesignTokens.Spacing.medium)
        .padding(.horizontal, DesignTokens.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(ThemeManager.current.surface0.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .stroke(ThemeManager.current.surface2.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
    }

    @ViewBuilder
    private var toastIcon: some View {
        switch toast.icon {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ThemeManager.current.green)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ThemeManager.current.red)
        case .gitlab:
            if let icon = AssetIcon.gitlab() {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: DesignTokens.IconSize.medium, height: DesignTokens.IconSize.medium)
            } else {
                Image(systemName: "link")
                    .foregroundStyle(ThemeManager.current.subtext0)
            }
        }
    }
}

/// Stack layout for multiple toast messages in the launcher UI.
struct ToastStackView: View {
    let toasts: [ToastMessage]

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(toasts) { toast in
                ToastView(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toasts)
    }
}
