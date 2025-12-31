import SwiftUI

struct CriteriaStripView: View {
    let filterChips: [CriteriaChip]
    let propertyChips: [CriteriaChip]

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.large) {
            CriteriaColumnView(
                title: "Filters",
                emptyText: "No filters",
                chips: filterChips
            )
            CriteriaColumnView(
                title: "Properties",
                emptyText: "No properties",
                chips: propertyChips
            )
        }
    }
}

private struct CriteriaColumnView: View {
    let title: String
    let emptyText: String
    let chips: [CriteriaChip]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
            Text(title)
                .font(.system(size: DesignTokens.TypeScale.label, weight: .semibold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)

            if chips.isEmpty {
                Text(emptyText)
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                    .foregroundColor(ThemeManager.current.overlay0)
            } else {
                FlowLayout(spacing: DesignTokens.Spacing.extraSmall, rowSpacing: DesignTokens.Spacing.extraSmall) {
                    ForEach(chips) { chip in
                        CriteriaChipView(chip: chip)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CriteriaChipView: View {
    let chip: CriteriaChip

    var body: some View {
        let tint = chip.tone.color
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            Image(systemName: chip.systemImage)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(tint)
            Text(chip.label)
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.text)
        }
        .padding(.horizontal, DesignTokens.Spacing.small)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(tint.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }
}
