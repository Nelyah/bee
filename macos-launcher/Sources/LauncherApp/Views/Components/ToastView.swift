import SwiftUI

/// Visual representation of a toast message.
struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ThemeManager.current.red)
            Text(toast.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ThemeManager.current.text)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ThemeManager.current.surface0.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ThemeManager.current.surface2.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
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
