import AppKit
import SwiftUI

/// An AppKit view that provides reliable mouse hover tracking.
///
/// SwiftUI's `.onHover` and `.onContinuousHover` fail sporadically when the window
/// has a clear background (Apple bug FB11988707). This view uses `NSTrackingArea`
/// directly for reliable hover detection that works regardless of window background.
final class HoverTrackingNSView: NSView {
    var onHoverChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Ensure tracking areas are set up when view is added to window
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove existing tracking area
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }

        // Create new tracking area that covers the entire view
        // Using .activeAlways instead of .activeInKeyWindow to track even when window isn't key
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newArea)
        trackingArea = newArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    // Allow click events to pass through to SwiftUI views underneath.
    // This doesn't affect tracking areas - they operate independently.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

// MARK: - SwiftUI Wrapper

struct HoverTrackingView: NSViewRepresentable {
    let onHoverChanged: (Bool) -> Void

    func makeNSView(context: Context) -> HoverTrackingNSView {
        let view = HoverTrackingNSView()
        view.onHoverChanged = onHoverChanged
        return view
    }

    func updateNSView(_ nsView: HoverTrackingNSView, context: Context) {
        nsView.onHoverChanged = onHoverChanged
    }
}

// MARK: - View Modifier

extension View {
    /// Adds reliable mouse hover tracking using AppKit's NSTrackingArea.
    ///
    /// Use this instead of `.onHover` or `.onContinuousHover` when the app window
    /// has a clear background, which causes SwiftUI's hover modifiers to fail
    /// (Apple bug FB11988707).
    ///
    /// - Parameter action: Closure called with `true` when mouse enters, `false` when it exits.
    func onReliableHover(perform action: @escaping (Bool) -> Void) -> some View {
        overlay {
            HoverTrackingView(onHoverChanged: action)
            // Note: We don't use .allowsHitTesting(false) here because it can
            // interfere with NSTrackingArea events. Instead, the NSView's
            // hitTest(_:) returns nil to let clicks pass through.
        }
    }
}
