import SwiftUI

struct CriteriaStripView: View {
    let activeReportName: String?
    let reportFilterChips: [CriteriaChip]
    let manualFilterChips: [CriteriaChip]
    let propertyChips: [CriteriaChip]

    var onRemoveReportFilter: ((CriteriaChip) -> Void)?
    var onRemoveManualFilter: ((CriteriaChip) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.large) {
            FiltersColumnView(
                activeReportName: activeReportName,
                reportFilterChips: reportFilterChips,
                manualFilterChips: manualFilterChips,
                onRemoveReportFilter: onRemoveReportFilter,
                onRemoveManualFilter: onRemoveManualFilter
            )
            CriteriaColumnView(
                title: "Properties",
                chips: propertyChips
            )
        }
    }
}

// MARK: - Filters Column (vertical stacking: report above manual)

private struct FiltersColumnView: View {
    let activeReportName: String?
    let reportFilterChips: [CriteriaChip]
    let manualFilterChips: [CriteriaChip]
    var onRemoveReportFilter: ((CriteriaChip) -> Void)?
    var onRemoveManualFilter: ((CriteriaChip) -> Void)?

    private let theme = ThemeManager.current

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
            // Section title
            Text("Filters")
                .font(.system(size: DesignTokens.TypeScale.label, weight: .semibold, design: .rounded))
                .foregroundColor(theme.subtext0)

            // Filter chips stacked vertically: report filters on top, manual filters below
            if !reportFilterChips.isEmpty || !manualFilterChips.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    // Report filters section (top)
                    if !reportFilterChips.isEmpty {
                        FilterGroupView(
                            label: reportSectionLabel,
                            chips: reportFilterChips,
                            isReportSource: true,
                            onRemove: onRemoveReportFilter
                        )
                    }

                    // Manual filters section (below)
                    if !manualFilterChips.isEmpty {
                        FilterGroupView(
                            label: "Your Filters",
                            chips: manualFilterChips,
                            isReportSource: false,
                            onRemove: onRemoveManualFilter
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reportSectionLabel: String {
        if let name = activeReportName, !name.isEmpty {
            let truncated = name.count > 20 ? String(name.prefix(17)) + "..." : name
            return "From \"\(truncated)\""
        }
        return "From Report"
    }
}

// MARK: - Filter Group (label + chips)

private struct FilterGroupView: View {
    let label: String
    let chips: [CriteriaChip]
    let isReportSource: Bool
    var onRemove: ((CriteriaChip) -> Void)?

    private let theme = ThemeManager.current

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
            // Group label
            Text(label)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
                .foregroundColor(theme.subtext0)

            FlowLayout(spacing: DesignTokens.Spacing.extraSmall, rowSpacing: DesignTokens.Spacing.extraSmall) {
                ForEach(chips) { chip in
                    CriteriaChipView(
                        chip: chip,
                        isReportSource: isReportSource,
                        onRemove: onRemove
                    )
                }
            }
        }
    }
}

// MARK: - Properties Column (unchanged structure)

private struct CriteriaColumnView: View {
    let title: String
    let chips: [CriteriaChip]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
            Text(title)
                .font(.system(size: DesignTokens.TypeScale.label, weight: .semibold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)

            if !chips.isEmpty {
                FlowLayout(spacing: DesignTokens.Spacing.extraSmall, rowSpacing: DesignTokens.Spacing.extraSmall) {
                    ForEach(chips) { chip in
                        CriteriaChipView(chip: chip, isReportSource: false, onRemove: nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chip View (with conditional styling)

private struct CriteriaChipView: View {
    let chip: CriteriaChip
    let isReportSource: Bool
    var onRemove: ((CriteriaChip) -> Void)?

    @State private var isHovered = false

    private let theme = ThemeManager.current

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            Image(systemName: chip.systemImage)
                .font(.system(size: DesignTokens.TypeScale.label, weight: .semibold, design: .rounded))
                .foregroundColor(iconColor)
            Text(chip.label)
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                .foregroundColor(labelColor)

            // Remove button
            if shouldShowRemoveButton {
                Button {
                    onRemove?(chip)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.subtext0)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.small)
        .padding(.vertical, DesignTokens.Spacing.extraSmall)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(tooltipText)
    }

    // MARK: - Conditional Styling

    private var iconColor: Color {
        isReportSource ? theme.subtext0 : chip.tone.color
    }

    private var labelColor: Color {
        isReportSource ? theme.subtext1 : theme.text
    }

    private var backgroundColor: Color {
        isReportSource ? theme.surface0 : chip.tone.color.opacity(0.16)
    }

    private var borderColor: Color {
        isReportSource ? theme.overlay0.opacity(0.5) : chip.tone.color.opacity(0.35)
    }

    private var shouldShowRemoveButton: Bool {
        guard onRemove != nil else { return false }
        // Report filters: show on hover only
        // Manual filters: always show
        return isReportSource ? isHovered : true
    }

    private var tooltipText: String {
        if isReportSource, let reportName = chip.reportName {
            return "From report: \(reportName)"
        }
        return ""
    }
}
