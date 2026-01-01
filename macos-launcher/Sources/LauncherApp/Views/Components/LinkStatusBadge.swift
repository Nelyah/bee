import SwiftUI

/// Displays the sync status of an external link with color-coded badge.
struct LinkStatusBadge: View {
    let state: ExternalLinkSyncState
    let timestamp: String?
    var compact: Bool = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
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
            "Pending"
        case .error:
            "Error"
        case let .synced(date):
            "Synced \(RelativeDateFormatter.description(for: date, now: Date(), calendar: .current))"
        case let .stale(date):
            "Last synced \(RelativeDateFormatter.description(for: date, now: Date(), calendar: .current))"
        }
    }

    private var helpText: String? {
        switch state {
        case let .error(message):
            message
        case .stale:
            "Data may be outdated. Expand task to refresh."
        default:
            timestamp
        }
    }

    private var iconName: String? {
        switch state {
        case let .synced(date):
            Calendar.current.isDateInToday(date) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        case .stale:
            "exclamationmark.triangle.fill"
        default:
            nil
        }
    }

    private var color: Color {
        switch state {
        case .pending:
            ThemeManager.current.subtext0
        case let .synced(date):
            Calendar.current.isDateInToday(date) ? ThemeManager.current.teal : ThemeManager.current.peach
        case .stale:
            ThemeManager.current.peach
        case .error:
            ThemeManager.current.red
        }
    }
}
