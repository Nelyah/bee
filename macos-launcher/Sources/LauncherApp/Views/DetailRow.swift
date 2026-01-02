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
    /// Whether this row is focused via detail view keyboard navigation (j/k keys).
    var isKeyboardFocused: Bool = false

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    /// Combined focus state: either SwiftUI Tab focus or keyboard nav focus.
    private var showFocusRing: Bool {
        isFocused || isKeyboardFocused
    }

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
                        .underline(isHovering || showFocusRing)
                        .help(fullValue)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if isHovering || showFocusRing {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                            .foregroundColor(ThemeManager.current.subtext0)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(CopyableDetailRowButtonStyle(isFocused: showFocusRing, isHovering: isHovering))
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

/// Custom button style for CopyableDetailRow that shows a focus ring when focused
/// and a subtle background highlight when hovering.
private struct CopyableDetailRowButtonStyle: ButtonStyle {
    let isFocused: Bool
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(isHovering ? ThemeManager.current.surface1.opacity(0.5) : Color.clear)
            )
            .overlay(
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
