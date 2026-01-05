import UniformTypeIdentifiers
import XCTest

@testable import LauncherApp

// MARK: - Apple Mail NSItemProvider Mock

/// Simulates Apple Mail's NSItemProvider behavior for testing.
///
/// When dragging from Mail:
/// - `canLoadObject(ofClass: URL.self)` returns TRUE
/// - `loadObject(ofClass: URL.self)` is called but FAILS
/// - The email content IS available via `loadFileRepresentation`
///
/// The handler must fall back to `loadFileRepresentation` when `loadObject` fails.
final class MailProviderWhereLoadObjectFails: NSItemProvider {
    let emlContent: String
    var tempFileURL: URL?
    var canLoadObjectWasCalled = false
    var loadObjectWasCalled = false
    var loadFileRepresentationWasCalled = false

    init(emlContent: String) {
        self.emlContent = emlContent
        super.init()

        // Pre-create the file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("mail-bug-\(UUID()).eml")
        try? emlContent.write(to: fileURL, atomically: true, encoding: .utf8)
        tempFileURL = fileURL
    }

    deinit {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    override func canLoadObject(ofClass aClass: NSItemProviderReading.Type) -> Bool {
        canLoadObjectWasCalled = true
        print("[TEST] canLoadObject called for \(aClass), returning true")
        // Mail says "yes I can load URLs" but then fails
        return true
    }

    override func loadObject(
        ofClass aClass: NSItemProviderReading.Type,
        completionHandler: @escaping @Sendable (NSItemProviderReading?, Error?) -> Void
    ) -> Progress {
        loadObjectWasCalled = true
        print("[TEST] loadObject called - will FAIL")
        // Fail like Mail does
        DispatchQueue.global().async {
            completionHandler(nil, NSError(
                domain: "CoreTransferable.TransferableSupportError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "The operation couldn't be completed."]
            ))
        }
        return Progress()
    }

    override func loadFileRepresentation(
        forTypeIdentifier typeIdentifier: String,
        completionHandler: @escaping @Sendable (URL?, Error?) -> Void
    ) -> Progress {
        loadFileRepresentationWasCalled = true
        print("[TEST] loadFileRepresentation called for \(typeIdentifier)")
        DispatchQueue.global().async { [self] in
            if let url = tempFileURL {
                completionHandler(url, nil)
            } else {
                completionHandler(nil, NSError(domain: "Test", code: 1))
            }
        }
        return Progress()
    }

    override func hasItemConformingToTypeIdentifier(_ typeIdentifier: String) -> Bool {
        print("[TEST] hasItemConformingToTypeIdentifier called for \(typeIdentifier)")
        return true
    }
}

// MARK: - Email Message Type Mock

/// Simulates Apple Mail providing email as .emailMessage type only (NOT .fileURL).
///
/// This tests the hypothesis that our code fails because we only ask for
/// .fileURL and .item providers, but Apple Mail provides .emailMessage.
///
/// Key behavior:
/// - `canLoadObject(ofClass: URL.self)` returns FALSE (not a file URL)
/// - `hasItemConformingToTypeIdentifier` only returns TRUE for .emailMessage
/// - `loadFileRepresentation` only works for .emailMessage type
final class MailProviderWithEmailMessageTypeOnly: NSItemProvider {
    let emlContent: String

    init(emlContent: String) {
        self.emlContent = emlContent
        super.init()
    }

    // Does NOT conform to URL - this is an email, not a file
    override func canLoadObject(ofClass aClass: NSItemProviderReading.Type) -> Bool {
        print("[TEST-EMAIL-TYPE] canLoadObject called for \(aClass), returning false")
        return false
    }

    override func hasItemConformingToTypeIdentifier(_ typeIdentifier: String) -> Bool {
        // Only conforms to emailMessage, NOT to fileURL or generic item
        let conforms = typeIdentifier == UTType.emailMessage.identifier
        print("[TEST-EMAIL-TYPE] hasItemConformingToTypeIdentifier(\(typeIdentifier)) = \(conforms)")
        return conforms
    }

    override func loadFileRepresentation(
        forTypeIdentifier typeIdentifier: String,
        completionHandler: @escaping @Sendable (URL?, Error?) -> Void
    ) -> Progress {
        print("[TEST-EMAIL-TYPE] loadFileRepresentation called for \(typeIdentifier)")

        guard typeIdentifier == UTType.emailMessage.identifier else {
            print("[TEST-EMAIL-TYPE] Rejecting - not emailMessage type")
            DispatchQueue.global().async {
                completionHandler(nil, NSError(domain: "Test", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Only emailMessage type is supported",
                ]))
            }
            return Progress()
        }

        // Create temp EML file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("email-type-test-\(UUID()).eml")
        try? emlContent.write(to: fileURL, atomically: true, encoding: .utf8)

        print("[TEST-EMAIL-TYPE] Created temp file: \(fileURL.path)")

        DispatchQueue.global().async {
            completionHandler(fileURL, nil)

            // Delete after callback returns (simulating Apple behavior)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                try? FileManager.default.removeItem(at: fileURL)
                print("[TEST-EMAIL-TYPE] Deleted temp file")
            }
        }
        return Progress()
    }
}

// MARK: - Race Condition Mock

/// Simulates Apple Mail's REAL behavior: temp file is deleted after callback returns.
///
/// This reproduces the race condition where:
/// 1. `loadFileRepresentation` provides a temp URL
/// 2. The callback dispatches to main queue async and returns
/// 3. Apple deletes the temp file
/// 4. The main queue block tries to read - FILE NOT FOUND
///
/// The existing `MailProviderWhereLoadObjectFails` keeps the file alive until `deinit`,
/// which hides the race condition. This mock provides a URL to a file that's immediately
/// deleted, simulating Apple's temp file behavior.
final class MailProviderThatDeletesFileImmediately: NSItemProvider {
    let emlContent: String
    /// Semaphore to block the main queue until the file is deleted
    private let deletionComplete = DispatchSemaphore(value: 0)

    init(emlContent: String) {
        self.emlContent = emlContent
        super.init()
    }

    override func canLoadObject(ofClass aClass: NSItemProviderReading.Type) -> Bool {
        true // Mail says "yes I can" but then fails
    }

    override func loadObject(
        ofClass aClass: NSItemProviderReading.Type,
        completionHandler: @escaping @Sendable (NSItemProviderReading?, Error?) -> Void
    ) -> Progress {
        // Fail like Mail does
        DispatchQueue.global().async {
            completionHandler(nil, NSError(domain: "Test", code: 1))
        }
        return Progress()
    }

    override func hasItemConformingToTypeIdentifier(_ typeIdentifier: String) -> Bool {
        true
    }

    override func loadFileRepresentation(
        forTypeIdentifier typeIdentifier: String,
        completionHandler: @escaping @Sendable (URL?, Error?) -> Void
    ) -> Progress {
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("race-condition-\(UUID()).eml")
        try? emlContent.write(to: fileURL, atomically: true, encoding: .utf8)

        print("[TEST-RACE] Created temp file: \(fileURL.path)")
        print("[TEST-RACE] File exists before callback: \(FileManager.default.fileExists(atPath: fileURL.path))")

        DispatchQueue.global().async {
            // Call the callback with a valid URL - file exists NOW
            print("[TEST-RACE] Calling completion handler (file exists)")
            completionHandler(fileURL, nil)

            // AFTER the callback returns, delete the file
            // This simulates Apple's behavior: the file is valid during the callback
            // but deleted immediately after the callback returns
            print("[TEST-RACE] Callback returned, now deleting file (simulating Apple behavior)")
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("[TEST-RACE] Deleted temp file AFTER callback returned")
            } catch {
                print("[TEST-RACE] Failed to delete: \(error)")
            }

            print("[TEST-RACE] File exists after deletion: \(FileManager.default.fileExists(atPath: fileURL.path))")
        }
        return Progress()
    }
}

/// Tests for email drop handling from Apple Mail.
///
/// Apple Mail drag-and-drop provides:
/// 1. File promises for EML content (not direct URLs)
/// 2. UTType.emailMessage content type
///
/// The drop handler needs to:
/// 1. Accept emailMessage UTType
/// 2. Handle file promises asynchronously
/// 3. Parse the EML content
/// 4. Call the appropriate callback with parsed email data
final class EmailDropHandlerTests: XCTestCase {
    // MARK: - UTType Detection Tests

    func testEmailDropHandlerAcceptsEmailMessageType() {
        // EmailDropHandler should accept UTType.emailMessage
        let acceptedTypes = EmailDropHandler.acceptedTypes

        XCTAssertTrue(
            acceptedTypes.contains(.emailMessage),
            "Should accept emailMessage UTType for Mail drops"
        )
    }

    func testEmailDropHandlerAcceptsFileURLType() {
        // Should also accept file URLs for direct EML file drops
        let acceptedTypes = EmailDropHandler.acceptedTypes

        XCTAssertTrue(
            acceptedTypes.contains(.fileURL),
            "Should accept fileURL UTType for direct file drops"
        )
    }

    func testEmailDropHandlerAcceptsEMLFileType() {
        // Should accept .eml file type if available
        let acceptedTypes = EmailDropHandler.acceptedTypes

        // Check for custom EML type
        let emlType = UTType(filenameExtension: "eml")
        if let emlType {
            XCTAssertTrue(
                acceptedTypes.contains(emlType) || acceptedTypes.contains(.data),
                "Should accept EML file type or generic data"
            )
        }
    }

    // MARK: - EML Content Parsing Tests

    func testHandleDropWithEMLContent() async throws {
        let emlContent = """
        Message-ID: <drop-test@example.com>
        Subject: Dropped Email
        From: dropper@example.com
        Date: Mon, 6 Jan 2026 10:00:00 -0500

        Body content
        """

        // Create a mock that simulates what we'd receive
        var receivedEmail: ParsedEmail?
        let handler = EmailDropHandler { email in
            receivedEmail = email
        }

        // Simulate processing EML content
        try handler.processEMLContent(emlContent)

        XCTAssertNotNil(receivedEmail)
        XCTAssertEqual(receivedEmail?.messageId, "<drop-test@example.com>")
        XCTAssertEqual(receivedEmail?.subject, "Dropped Email")
        XCTAssertEqual(receivedEmail?.sender, "dropper@example.com")
    }

    func testHandleDropWithInvalidEMLContent() throws {
        let invalidContent = "Not a valid EML file"

        var receivedEmail: ParsedEmail?
        let handler = EmailDropHandler { email in
            receivedEmail = email
        }

        // Should throw on invalid content
        XCTAssertThrowsError(try handler.processEMLContent(invalidContent)) { error in
            // Should be an EMLParserError
            XCTAssertTrue(error is EMLParserError)
        }

        XCTAssertNil(receivedEmail, "Should not call callback on error")
    }

    // MARK: - File URL Handling Tests

    func testHandleDropWithFileURL() async throws {
        // Create a temporary EML file
        let emlContent = """
        Message-ID: <file-drop@example.com>
        Subject: File Drop Test
        From: file@example.com

        """

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test-drop-\(UUID()).eml")
        try emlContent.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var receivedEmail: ParsedEmail?
        let handler = EmailDropHandler { email in
            receivedEmail = email
        }

        try await handler.processFileURL(fileURL)

        XCTAssertNotNil(receivedEmail)
        XCTAssertEqual(receivedEmail?.messageId, "<file-drop@example.com>")
        XCTAssertEqual(receivedEmail?.subject, "File Drop Test")
    }

    // MARK: - Delegate Callback Tests

    /// Tests that file drops work even when email providers exist but fail to load.
    ///
    /// This reproduces the bug where:
    /// 1. `itemProviders(for: [.emailMessage])` returns providers
    /// 2. But `loadFileRepresentation` fails with "Cannot find representation"
    /// 3. The delegate returns true early, so file drops are never processed
    func testFileDropWorksWhenEmailProviderFailsToLoad() async throws {
        let expectation = XCTestExpectation(description: "File callback should be called")
        var receivedURLs: [URL]?

        // Create a processor that tracks callbacks
        let processor = DropProcessor(
            onFileDropped: { urls in
                receivedURLs = urls
                expectation.fulfill()
            },
            onEmailDropped: { _ in }
        )

        // Create a temp file to simulate a drop
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test-attachment-\(UUID()).pdf")
        try "PDF content".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        // Simulate the case where email loading fails but file URL is valid
        // The processor should still call onFileDropped
        processor.processFileURLs([fileURL])

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertNotNil(receivedURLs, "File callback should have been called")
        XCTAssertEqual(receivedURLs?.count, 1)
        XCTAssertEqual(receivedURLs?.first, fileURL)
    }

    /// Tests that EML files dropped as file URLs are routed to email handler.
    func testEMLFileDropRoutesToEmailHandler() async throws {
        let expectation = XCTestExpectation(description: "Email callback should be called")
        var receivedEmail: ParsedEmail?

        let processor = DropProcessor(
            onFileDropped: { _ in },
            onEmailDropped: { email in
                receivedEmail = email
                expectation.fulfill()
            }
        )

        // Create a temp EML file
        let emlContent = """
        Message-ID: <processor-test@example.com>
        Subject: Processor Test
        From: test@example.com

        """
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test-\(UUID()).eml")
        try emlContent.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        processor.processFileURLs([fileURL])

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertNotNil(receivedEmail, "Email callback should have been called for EML file")
        XCTAssertEqual(receivedEmail?.subject, "Processor Test")
    }

    // MARK: - File Promise Handling (Apple Mail)

    /// Tests that email drops from Apple Mail work via fallback to file promises.
    ///
    /// Apple Mail's NSItemProvider behavior:
    /// 1. `canLoadObject(ofClass: URL.self)` returns TRUE
    /// 2. `loadObject(ofClass: URL.self)` is called but FAILS
    /// 3. Email content IS available via `loadFileRepresentation`
    ///
    /// The handler must detect the `loadObject` failure and fall back to
    /// `loadFileRepresentation` to successfully process the email.
    @MainActor
    func testMailDropFallsBackToFilePromise() async throws {
        let expectation = XCTestExpectation(description: "Email callback should be called")
        var receivedEmail: ParsedEmail?

        let emlContent = """
        Message-ID: <mail-drop@example.com>
        Subject: Mail Drop Test
        From: mail@example.com

        """

        let provider = MailProviderWhereLoadObjectFails(emlContent: emlContent)

        let delegate = AttachmentAndEmailDropDelegate(
            onFileDropped: { _ in },
            onEmailDropped: { email in
                receivedEmail = email
                expectation.fulfill()
            }
        )

        // This calls loadObject which FAILS, then falls back to loadFileRepresentation
        delegate.processProvider(provider)

        await fulfillment(of: [expectation], timeout: 2.0)

        // Keep provider alive until assertions complete
        _ = provider

        // Verify the fallback path was taken
        XCTAssertTrue(provider.loadObjectWasCalled, "loadObject should have been called first")
        XCTAssertTrue(
            provider.loadFileRepresentationWasCalled,
            "loadFileRepresentation should have been called as fallback"
        )
        XCTAssertNotNil(receivedEmail)
        XCTAssertEqual(receivedEmail?.subject, "Mail Drop Test")
    }

    // MARK: - Distinguishing Email vs Attachment Drops

    func testIsEMLFile() {
        // .eml extension should be detected
        let emlURL = URL(fileURLWithPath: "/tmp/test.eml")
        XCTAssertTrue(EmailDropHandler.isEMLFile(emlURL))

        // Other extensions should not be detected as EML
        let pdfURL = URL(fileURLWithPath: "/tmp/test.pdf")
        XCTAssertFalse(EmailDropHandler.isEMLFile(pdfURL))

        let txtURL = URL(fileURLWithPath: "/tmp/test.txt")
        XCTAssertFalse(EmailDropHandler.isEMLFile(txtURL))
    }

    // MARK: - Race Condition Tests

    /// Tests email drop handling when Apple Mail deletes the temp file after callback returns.
    ///
    /// This test simulates Apple Mail's real behavior:
    /// 1. `loadFileRepresentation` provides a valid temp file URL
    /// 2. The callback is invoked - file exists at this point
    /// 3. Callback returns
    /// 4. Apple deletes the temp file immediately
    ///
    /// The implementation MUST read the file synchronously within the callback,
    /// before it returns, to avoid a race condition where the file is deleted
    /// before we can read it.
    @MainActor
    func testMailDropWithDeletedTempFile() async throws {
        let expectation = XCTestExpectation(description: "Email callback should be called")

        var receivedEmail: ParsedEmail?
        var callbackWasCalled = false

        let emlContent = """
        Message-ID: <race-test@example.com>
        Subject: Race Condition Test
        From: race@example.com

        """

        let provider = MailProviderThatDeletesFileImmediately(emlContent: emlContent)

        let delegate = AttachmentAndEmailDropDelegate(
            onFileDropped: { _ in
                print("[TEST-RACE] onFileDropped called (unexpected)")
            },
            onEmailDropped: { email in
                print("[TEST-RACE] onEmailDropped called with: \(email.subject)")
                callbackWasCalled = true
                receivedEmail = email
                expectation.fulfill()
            }
        )

        print("[TEST-RACE] Calling processProvider...")
        delegate.processProvider(provider)

        // Wait for callback - with the bug, it won't come because the file is deleted!
        await fulfillment(of: [expectation], timeout: 2.0)

        // These assertions will FAIL with current implementation
        XCTAssertTrue(callbackWasCalled, "Email callback should have been called")
        XCTAssertNotNil(receivedEmail, "Should have received parsed email")
        XCTAssertEqual(receivedEmail?.subject, "Race Condition Test")
    }

    // MARK: - Email Message Type Tests

    /// Tests that email drops work when provider only conforms to .emailMessage type.
    ///
    /// **HYPOTHESIS:** Apple Mail provides .emailMessage content, but our code only
    /// requests .fileURL and .item providers in `performDrop`. This causes the
    /// email to be silently ignored.
    ///
    /// This test simulates Apple Mail providing email content that:
    /// - Does NOT conform to URL (canLoadObject returns false)
    /// - Only conforms to .emailMessage type
    ///
    /// **If test FAILS:** Confirms hypothesis - code doesn't handle .emailMessage-only
    /// **If test PASSES:** Hypothesis is wrong, issue is elsewhere
    @MainActor
    func testEmailDropWithEmailMessageTypeOnly() async throws {
        let expectation = XCTestExpectation(description: "Email callback should be called")

        var receivedEmail: ParsedEmail?

        let emlContent = """
        Message-ID: <email-type-test@example.com>
        Subject: Email Type Test
        From: test@example.com

        """

        let provider = MailProviderWithEmailMessageTypeOnly(emlContent: emlContent)

        let delegate = AttachmentAndEmailDropDelegate(
            onFileDropped: { _ in
                print("[TEST-EMAIL-TYPE] onFileDropped called (unexpected)")
            },
            onEmailDropped: { email in
                print("[TEST-EMAIL-TYPE] onEmailDropped called with: \(email.subject)")
                receivedEmail = email
                expectation.fulfill()
            }
        )

        print("[TEST-EMAIL-TYPE] Calling processProvider...")
        delegate.processProvider(provider)

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertNotNil(receivedEmail, "Should have received parsed email")
        XCTAssertEqual(receivedEmail?.subject, "Email Type Test")
    }
}
