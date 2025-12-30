import SwiftUI

struct DetailRow: View {
    let label: String
    let value: String
    let helpText: String?

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
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

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        DetailRow(label: "Project", value: "bee", helpText: nil)
        DetailRow(label: "Tags", value: "code, review", helpText: nil)
        DetailRow(label: "Status", value: "active", helpText: nil)
    }
    .padding()
    .background(ThemeManager.current.base)
}
