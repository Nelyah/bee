import SwiftUI

/// Return a One Dark color based on task status.
func statusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "active":
        return ThemeManager.current.green
    case "completed":
        return ThemeManager.current.blue
    case "deleted":
        return ThemeManager.current.red
    case "blocked":
        return ThemeManager.current.mauve
    default:
        return ThemeManager.current.yellow
    }
}
