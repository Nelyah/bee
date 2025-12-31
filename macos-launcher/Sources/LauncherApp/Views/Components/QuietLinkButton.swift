import SwiftUI

/// A reusable "quietly highlighted" clickable link button.
/// Shows subtle hover effect with color change and underline, matching the detail view style.
struct QuietLinkButton<Label: View>: View {
    let action: () -> Void
    let label: (Bool) -> Label

    @State private var isHovering = false

    init(
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping (Bool) -> Label
    ) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label(isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// A text-based quiet link that opens a URL.
/// Shows underline and color change on hover.
struct QuietURLLink: View {
    let text: String
    let url: URL
    var font: Font = .system(size: DesignTokens.TypeScale.caption, weight: .medium)

    @Environment(\.openURL) private var openURL
    @State private var isHovering = false

    var body: some View {
        Button {
            openURL(url)
        } label: {
            Text(text)
                .font(font)
                .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current.text)
                .underline(isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview("Quiet Link Button") {
    VStack(alignment: .leading, spacing: 12) {
        QuietLinkButton(action: { print("Tapped") }) { isHovering in
            Text("Hover me")
                .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current.text)
                .underline(isHovering)
        }

        QuietURLLink(
            text: "Open Example",
            url: URL(string: "https://example.com")!
        )
    }
    .padding()
    .background(ThemeManager.current.base)
}
