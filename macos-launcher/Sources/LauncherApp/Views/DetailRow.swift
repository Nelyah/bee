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
/// Shows a copy icon on hover and copies the full value when clicked.
struct CopyableDetailRow: View {
    let label: String
    let value: String
    let fullValue: String
    let onCopy: (String) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.large) {
            Text(label.uppercased())
                .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 90, alignment: .leading)
            HStack(spacing: DesignTokens.Spacing.small) {
                Text(value)
                    .font(.system(size: DesignTokens.TypeScale.body, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                    .help(fullValue)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if isHovering {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        .foregroundColor(ThemeManager.current.subtext0)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                onCopy(fullValue)
            }
        }
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
