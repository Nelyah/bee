import AppKit
import SwiftUI

/// Captures the hosting NSWindow and applies configuration.
///
/// This is the idiomatic SwiftUI way to access the underlying NSWindow.
/// Use this instead of iterating `NSApplication.shared.windows`.
///
/// ## Usage
/// ```swift
/// var body: some View {
///     ZStack {
///         WindowAccessor { window in
///             WindowConfiguration.applyBorderlessStyle(to: window)
///         }
///         // ... your content ...
///     }
/// }
/// ```
///
/// The closure is called once when the view is first added to a window.
/// The NSView itself is invisible (zero-sized).
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowAccessorView(onWindow: onWindow)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed - configuration is applied once
    }
}

/// Internal view that captures window reference when added to view hierarchy.
private class WindowAccessorView: NSView {
    private let onWindow: (NSWindow) -> Void
    private var didConfigure = false

    init(onWindow: @escaping (NSWindow) -> Void) {
        self.onWindow = onWindow
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Configure only once, when first added to a window
        guard let window, !didConfigure else { return }
        didConfigure = true
        onWindow(window)
    }
}
