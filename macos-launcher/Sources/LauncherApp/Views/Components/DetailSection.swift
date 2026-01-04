import SwiftUI

/// A card-style container for detail view sections.
/// All sections use consistent visual treatment for proper hierarchy.
struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(title.uppercased())
                .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
            content
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .fill(ThemeManager.current.surface0)
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .stroke(ThemeManager.current.surface1.opacity(DesignTokens.Border.containerOpacity), lineWidth: 1)
            }
        )
    }
}

/// A card-style section with an action button in the header.
struct DetailSectionWithAction<Content: View>: View {
    let title: String
    let actionLabel: String
    let actionIcon: String
    let onAction: () -> Void
    let content: Content

    init(
        title: String,
        actionLabel: String,
        actionIcon: String,
        onAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actionLabel = actionLabel
        self.actionIcon = actionIcon
        self.onAction = onAction
        self.content = content()
    }

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
                Spacer()
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Image(systemName: actionIcon)
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        Text(actionLabel)
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                    }
                    .foregroundColor(isHovering ? ThemeManager.current.text : ThemeManager.current.subtext0)
                }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
            }
            content
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(ThemeManager.current.surface0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .stroke(ThemeManager.current.surface1.opacity(DesignTokens.Border.containerOpacity), lineWidth: 1)
        )
    }
}
