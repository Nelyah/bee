import SwiftUI

/// Return a Catppuccin Mocha color based on task status.
func statusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "active":
        return CatppuccinTheme.green
    case "completed":
        return CatppuccinTheme.blue
    case "deleted":
        return CatppuccinTheme.red
    case "blocked":
        return CatppuccinTheme.mauve
    default:
        return CatppuccinTheme.yellow
    }
}
