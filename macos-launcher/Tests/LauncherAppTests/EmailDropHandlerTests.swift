import UniformTypeIdentifiers
import XCTest

@testable import LauncherAppKit

/// Tests for the EmailDropHandler utility functions.
///
/// The actual drop handling is done by `FilePromiseDropNSView` (AppKit-based).
/// These tests cover the static utility functions in `EmailDropHandler`.
final class EmailDropHandlerTests: XCTestCase {
    // MARK: - EML File Detection

    func testIsEMLFile() {
        // .eml extension should be detected
        let emlURL = URL(fileURLWithPath: "/tmp/test.eml")
        XCTAssertTrue(EmailDropHandler.isEMLFile(emlURL))

        // Case insensitive
        let emlUpperURL = URL(fileURLWithPath: "/tmp/test.EML")
        XCTAssertTrue(EmailDropHandler.isEMLFile(emlUpperURL))

        // Other extensions should not be detected as EML
        let pdfURL = URL(fileURLWithPath: "/tmp/test.pdf")
        XCTAssertFalse(EmailDropHandler.isEMLFile(pdfURL))

        let txtURL = URL(fileURLWithPath: "/tmp/test.txt")
        XCTAssertFalse(EmailDropHandler.isEMLFile(txtURL))
    }

    func testAcceptedTypesContainsExpectedTypes() {
        let types = EmailDropHandler.acceptedTypes

        XCTAssertTrue(types.contains(.emailMessage), "Should accept emailMessage UTType")
        XCTAssertTrue(types.contains(.fileURL), "Should accept fileURL UTType")
    }
}
