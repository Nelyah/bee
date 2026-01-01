import SwiftUI

/// A prominent error banner with icon, message, and optional retry action.
/// Used to display errors in a visually distinct way that users cannot miss.
struct ErrorBannerView: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: DesignTokens.TypeScale.bodyXl, weight: .medium))
                .foregroundColor(ThemeManager.current.red)

            Text(message)
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.text)
                .lineLimit(2)

            Spacer()

            if let onRetry {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                        .foregroundColor(ThemeManager.current.blue)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.medium)
        .padding(.horizontal, DesignTokens.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(ThemeManager.current.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .stroke(ThemeManager.current.red.opacity(0.3), lineWidth: 1)
        )
    }
}
