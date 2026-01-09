import XCTest

@testable import LauncherAppKit

final class FilePromiseDropViewTests: XCTestCase {
    /// Tests that the drop overlay allows mouse events to pass through.
    ///
    /// The FilePromiseDropNSView is used as an overlay for drag-and-drop.
    /// It must return nil from hitTest(_:) to allow clicks and hovers
    /// to reach the underlying SwiftUI views.
    ///
    /// **Why this matters:**
    /// When an NSView is used as a SwiftUI overlay, it intercepts all mouse events
    /// by default. This breaks hover highlighting and click handling on the
    /// underlying attachment/email rows. Returning nil from hitTest makes the
    /// overlay "transparent" to mouse events while still receiving drag events.
    func testHitTestReturnsNilForMouseEventPassthrough() {
        let view = FilePromiseDropNSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        // hitTest should return nil to allow mouse events to pass through
        let result = view.hitTest(NSPoint(x: 50, y: 50))

        XCTAssertNil(result, "hitTest should return nil to allow mouse events to pass through to underlying views")
    }

    /// Tests that points outside the view also return nil.
    func testHitTestReturnsNilForPointsOutsideView() {
        let view = FilePromiseDropNSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        let result = view.hitTest(NSPoint(x: 150, y: 150))

        XCTAssertNil(result, "hitTest should return nil for points outside the view")
    }
}
