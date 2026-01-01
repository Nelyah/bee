import SwiftUI

struct DetailRow: View {
    let label: String
    let value: String
    let helpText: String?

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.large) {
            Text(label.uppercased())
                .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: DesignTokens.TypeScale.body, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.text)
                .help(helpText ?? value)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A detail row with tap-to-copy functionality.
///
/// Shows a copy icon on hover/focus and copies the full value when clicked or activated.
/// Supports keyboard navigation (Tab to focus, Enter/Space to copy) and VoiceOver.
struct CopyableDetailRow: View {
    let label: String
    let value: String
    let fullValue: String
    let onCopy: (String) -> Void

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.large) {
            Text(label.uppercased())
                .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 90, alignment: .leading)
            Button {
                onCopy(fullValue)
            } label: {
                HStack(spacing: DesignTokens.Spacing.small) {
                    Text(value)
                        .font(.system(size: DesignTokens.TypeScale.body, weight: .medium, design: .rounded))
                        .foregroundColor(ThemeManager.current.text)
                        .help(fullValue)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if isHovering || isFocused {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                            .foregroundColor(ThemeManager.current.subtext0)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(CopyableDetailRowButtonStyle(isFocused: isFocused))
            .focused($isFocused)
            .onHover { hovering in
                isHovering = hovering
            }
            .accessibilityLabel("Copy \(label)")
            .accessibilityHint("Copies \(fullValue) to clipboard")
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// Custom button style for CopyableDetailRow that shows a focus ring when focused.
private struct CopyableDetailRowButtonStyle: ButtonStyle {
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .stroke(
                        isFocused ? ThemeManager.current.blue : Color.clear,
                        lineWidth: 2
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        DetailRow(label: "Project", value: "bee", helpText: nil)
        DetailRow(label: "Tags", value: "code, review", helpText: nil)
        DetailRow(label: "Status", value: "active", helpText: nil)
        CopyableDetailRow(
            label: "UUID",
            value: "...12345678",
            fullValue: "abc-def-12345678",
            onCopy: { _ in }
        )
    }
    .padding()
    .background(ThemeManager.current.base)
}
