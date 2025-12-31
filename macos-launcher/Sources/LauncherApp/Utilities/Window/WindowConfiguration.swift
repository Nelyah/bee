import AppKit

/// Borderless Window Configuration
///
/// Achieving a Raycast-style borderless window requires coordinating SwiftUI and NSWindow settings.
/// This file documents the complete "recipe" and provides the NSWindow configuration.
///
/// ## Required Settings (all three layers must be configured):
///
/// ### 1. SwiftUI Scene Level (LauncherApp.swift)
/// ```swift
/// .windowStyle(.hiddenTitleBar)
/// ```
/// Removes the title bar chrome (close/minimize/zoom buttons and title text area).
///
/// ### 2. SwiftUI View Level (ContentView.swift)
/// ```swift
/// .clipShape(RoundedRectangle(cornerRadius: WindowConfiguration.cornerRadius))
/// .ignoresSafeArea()
/// ```
/// - `clipShape` creates the rounded corners
/// - `ignoresSafeArea` makes content fill the entire window (including where title bar was)
///
/// ### 3. NSWindow Level (via WindowAccessor)
/// ```swift
/// WindowConfiguration.applyBorderlessStyle(to: window)
/// ```
/// - `isMovableByWindowBackground` enables window dragging (no title bar to drag)
/// - `isOpaque = false` + `backgroundColor = .clear` allows rounded corners to show through
/// - Hide standard window buttons (close/minimize/zoom) - `.hiddenTitleBar` doesn't hide these
///
/// ## Why Each Setting is Needed
///
/// | Setting | Without It |
/// |---------|-----------|
/// | `.hiddenTitleBar` | Title bar chrome visible |
/// | `.ignoresSafeArea()` | Transparent gap at top of window |
/// | `.clipShape()` | Sharp corners instead of rounded |
/// | `isMovableByWindowBackground` | Window cannot be dragged |
/// | `backgroundColor = .clear` | Rounded corners show solid background |
/// | Hide window buttons | Traffic lights (close/minimize/zoom) visible |
///
/// ## Historical Note
///
/// Previous implementations used redundant NSWindow settings (`.fullSizeContentView`,
/// `titlebarAppearsTransparent`, `titleVisibility`, `contentView.cornerRadius`) that
/// duplicated SwiftUI functionality and caused conflicts. This simplified version
/// only includes settings that SwiftUI cannot handle natively.
enum WindowConfiguration {
    /// Corner radius used for window shape. Apply to both clipShape and stroke overlay.
    static let cornerRadius: CGFloat = 18

    /// Apply essential NSWindow settings for borderless appearance.
    ///
    /// Only includes settings that SwiftUI cannot handle:
    /// - Window dragging (no SwiftUI equivalent for `isMovableByWindowBackground`)
    /// - Transparent background (required for rounded corner effect)
    /// - Hidden window buttons (`.hiddenTitleBar` doesn't hide them automatically)
    ///
    /// - Parameter window: The NSWindow to configure
    static func applyBorderlessStyle(to window: NSWindow) {
        // Required: Enable dragging from anywhere since there's no title bar
        window.isMovableByWindowBackground = true

        // Required: Transparent background so rounded corners don't show solid color
        window.isOpaque = false
        window.backgroundColor = .clear

        // Required: Hide traffic light buttons (close/minimize/zoom)
        // Note: .hiddenTitleBar hides the title bar chrome but NOT these buttons
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
