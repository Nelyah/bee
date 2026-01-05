import XCTest

@testable import LauncherApp

/// Tests for EML (RFC 2822) email file parsing.
///
/// Apple Mail drag-and-drop provides email data as EML files. These tests
/// verify we can extract the key metadata: Message-ID, Subject, From, Date.
final class EMLParserTests: XCTestCase {
    // MARK: - Message-ID Parsing

    func testParsesMessageId() throws {
        let eml = """
        Message-ID: <CAFxDK+xyz123@mail.gmail.com>
        Subject: Test Email
        From: alice@example.com
        Date: Mon, 6 Jan 2026 10:30:00 -0500

        Body content here.
        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertEqual(parsed.messageId, "<CAFxDK+xyz123@mail.gmail.com>")
    }

    func testParsesMessageIdWithoutAngleBrackets() throws {
        let eml = """
        Message-Id: simple-id@example.com
        Subject: Simple ID Test
        From: bob@example.com

        """

        let parsed = try EMLParser.parse(content: eml)

        // Should preserve whatever format is provided
        XCTAssertEqual(parsed.messageId, "simple-id@example.com")
    }

    // MARK: - Subject Parsing

    func testParsesSimpleSubject() throws {
        let eml = """
        Message-ID: <test@example.com>
        Subject: Meeting Tomorrow at 3pm
        From: alice@example.com

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertEqual(parsed.subject, "Meeting Tomorrow at 3pm")
    }

    func testParsesMultiLineSubject() throws {
        // RFC 2822 allows header folding (continuation on next line with whitespace)
        let eml = """
        Message-ID: <test@example.com>
        Subject: This is a very long subject line that
         continues on the next line with folding
        From: alice@example.com

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertEqual(
            parsed.subject,
            "This is a very long subject line that continues on the next line with folding"
        )
    }

    func testParsesEncodedSubjectBase64() throws {
        // RFC 2047 Base64 encoded subject: "Test =?UTF-8?B?44OG44K544OI?=" = "Test テスト"
        let eml = """
        Message-ID: <encoded@example.com>
        Subject: =?UTF-8?B?44OG44K544OI?=
        From: sender@example.com

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertEqual(parsed.subject, "テスト")
    }

    func testParsesEncodedSubjectQuotedPrintable() throws {
        // RFC 2047 Quoted-Printable: =?UTF-8?Q?Caf=C3=A9?= = "Café"
        let eml = """
        Message-ID: <qp@example.com>
        Subject: =?UTF-8?Q?Caf=C3=A9?=
        From: sender@example.com

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertEqual(parsed.subject, "Café")
    }

    // MARK: - From (Sender) Parsing

    func testParsesSimpleFromAddress() throws {
        let eml = """
        Message-ID: <test@example.com>
        Subject: Test
        From: alice@example.com

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertEqual(parsed.sender, "alice@example.com")
    }

    func testParsesFromWithDisplayName() throws {
        let eml = """
        Message-ID: <test@example.com>
        Subject: Test
        From: Alice Smith <alice@example.com>

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertEqual(parsed.sender, "Alice Smith <alice@example.com>")
    }

    func testParsesFromWithQuotedDisplayName() throws {
        let eml = """
        Message-ID: <test@example.com>
        Subject: Test
        From: "Smith, Alice" <alice@example.com>

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertEqual(parsed.sender, "\"Smith, Alice\" <alice@example.com>")
    }

    // MARK: - Date Parsing

    func testParsesRfc2822Date() throws {
        let eml = """
        Message-ID: <test@example.com>
        Subject: Test
        From: alice@example.com
        Date: Mon, 6 Jan 2026 10:30:00 -0500

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertNotNil(parsed.sentDate)
        // Verify the date components
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            in: TimeZone(secondsFromGMT: -5 * 3600)!,
            from: parsed.sentDate!
        )
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 6)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 30)
    }

    func testHandlesMissingSentDate() throws {
        let eml = """
        Message-ID: <test@example.com>
        Subject: Test
        From: alice@example.com

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertNil(parsed.sentDate)
    }

    // MARK: - Error Cases

    func testThrowsOnMissingMessageId() {
        let eml = """
        Subject: No Message ID
        From: alice@example.com

        """

        XCTAssertThrowsError(try EMLParser.parse(content: eml)) { error in
            guard let emlError = error as? EMLParserError else {
                XCTFail("Expected EMLParserError")
                return
            }
            XCTAssertEqual(emlError, .missingMessageId)
        }
    }

    func testThrowsOnMissingSubject() {
        let eml = """
        Message-ID: <test@example.com>
        From: alice@example.com

        """

        XCTAssertThrowsError(try EMLParser.parse(content: eml)) { error in
            guard let emlError = error as? EMLParserError else {
                XCTFail("Expected EMLParserError")
                return
            }
            XCTAssertEqual(emlError, .missingSubject)
        }
    }

    func testThrowsOnMissingFrom() {
        let eml = """
        Message-ID: <test@example.com>
        Subject: Test

        """

        XCTAssertThrowsError(try EMLParser.parse(content: eml)) { error in
            guard let emlError = error as? EMLParserError else {
                XCTFail("Expected EMLParserError")
                return
            }
            XCTAssertEqual(emlError, .missingSender)
        }
    }

    // MARK: - Header Case Insensitivity

    func testHeaderNamesAreCaseInsensitive() throws {
        let eml = """
        message-id: <lower@example.com>
        SUBJECT: Uppercase Header
        fRoM: mixed@example.com

        """

        let parsed = try EMLParser.parse(content: eml)

        XCTAssertEqual(parsed.messageId, "<lower@example.com>")
        XCTAssertEqual(parsed.subject, "Uppercase Header")
        XCTAssertEqual(parsed.sender, "mixed@example.com")
    }

    // MARK: - File URL Parsing

    func testParsesFromFileURL() throws {
        // Create a temporary EML file
        let content = """
        Message-ID: <file-test@example.com>
        Subject: File Test
        From: file@example.com

        """

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test-\(UUID()).eml")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let parsed = try EMLParser.parse(fileURL: fileURL)

        XCTAssertEqual(parsed.messageId, "<file-test@example.com>")
        XCTAssertEqual(parsed.subject, "File Test")
        XCTAssertEqual(parsed.sender, "file@example.com")
    }
}
