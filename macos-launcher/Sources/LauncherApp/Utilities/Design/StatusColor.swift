import SwiftUI

/// Return a One Dark color based on task status.
func statusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "active":
        ThemeManager.current.green
    case "completed":
        ThemeManager.current.blue
    case "deleted":
        ThemeManager.current.red
    case "blocked":
        ThemeManager.current.mauve
    default:
        ThemeManager.current.yellow
    }
}
