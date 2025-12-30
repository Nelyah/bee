import SwiftUI

/// Displays the sync status of an external link with color-coded badge.
struct LinkStatusBadge: View {
    let state: ExternalLinkSyncState
    let timestamp: String?
    var compact: Bool = false

    var body: some View {
        Text(label)
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
            .padding(.horizontal, compact ? DesignTokens.Spacing.xs : DesignTokens.Spacing.sm)
            .padding(.vertical, compact ? 2 : 4)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(color.opacity(0.2))
            )
            .foregroundColor(color)
            .help(helpText ?? "")
    }

    private var label: String {
        switch state {
        case .pending:
            return "Pending"
        case .error:
            return "Error"
        case .synced(let date):
            return "Synced \(RelativeDateFormatter.description(for: date, now: Date(), calendar: .current))"
        case .stale(let date):
            return "Stale \(RelativeDateFormatter.description(for: date, now: Date(), calendar: .current))"
        }
    }

    private var helpText: String? {
        switch state {
        case .error(let message):
            return message
        default:
            return timestamp
        }
    }

    private var color: Color {
        switch state {
        case .pending:
            return ThemeManager.current.subtext0
        case .synced:
            return ThemeManager.current.green
        case .stale:
            return ThemeManager.current.yellow
        case .error:
            return ThemeManager.current.red
        }
    }
}
