import SwiftUI

/// Displays the sync status of an external link with color-coded badge.
struct LinkStatusBadge: View {
    let state: ExternalLinkSyncState
    let timestamp: String?
    var compact: Bool = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let iconName {
                Image(systemName: iconName)
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
            }
            Text(label)
        }
        .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
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

    private var iconName: String? {
        switch state {
        case .synced(let date):
            return Calendar.current.isDateInToday(date) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        case .stale:
            return "exclamationmark.triangle.fill"
        default:
            return nil
        }
    }

    private var color: Color {
        switch state {
        case .pending:
            return ThemeManager.current.subtext0
        case .synced(let date):
            return Calendar.current.isDateInToday(date) ? ThemeManager.current.teal : ThemeManager.current.peach
        case .stale:
            return ThemeManager.current.peach
        case .error:
            return ThemeManager.current.red
        }
    }
}
