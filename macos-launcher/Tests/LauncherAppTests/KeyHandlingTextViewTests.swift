import AppKit
import XCTest

@testable import LauncherAppKit

final class KeyHandlingTextViewTests: XCTestCase {
    func testMouseDownRequestsInsertMode() {
        let textView = KeyHandlingTextView()
        var didRequestFocus = false
        textView.onRequestFocus = {
            didRequestFocus = true
            return false
        }

        let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )

        XCTAssertNotNil(event)
        if let event {
            textView.mouseDown(with: event)
        }

        XCTAssertTrue(didRequestFocus)
    }
}
