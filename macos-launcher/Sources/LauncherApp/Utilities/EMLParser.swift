import Foundation

/// Parsed email metadata from an EML file.
///
/// Contains the key fields needed to create an email link:
/// - Message-ID for unique identification
/// - Subject for display
/// - Sender for attribution
/// - Sent date for sorting
struct ParsedEmail: Equatable {
    let messageId: String
    let subject: String
    let sender: String
    let sentDate: Date?
}

/// Errors that can occur during EML parsing.
enum EMLParserError: Error, Equatable {
    case missingMessageId
    case missingSubject
    case missingSender
    case invalidFileContent
    case fileReadError(String)
}

/// Parser for EML (RFC 2822) email files.
///
/// Apple Mail drag-and-drop provides email data as EML files. This parser
/// extracts the key metadata needed to create email links.
enum EMLParser {
    /// Parse an EML file from a URL.
    static func parse(fileURL: URL) throws -> ParsedEmail {
        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw EMLParserError.fileReadError(error.localizedDescription)
        }
        return try parse(content: content)
    }

    /// Parse EML content from a string.
    static func parse(content: String) throws -> ParsedEmail {
        let headers = parseHeaders(content)

        guard let messageId = headers["message-id"] else {
            throw EMLParserError.missingMessageId
        }

        guard let subject = headers["subject"] else {
            throw EMLParserError.missingSubject
        }

        guard let sender = headers["from"] else {
            throw EMLParserError.missingSender
        }

        let sentDate = headers["date"].flatMap { parseRfc2822Date($0) }

        return ParsedEmail(
            messageId: messageId,
            subject: decodeRfc2047(subject),
            sender: sender,
            sentDate: sentDate
        )
    }

    // MARK: - Private Helpers

    /// Parse email headers from content, handling line folding.
    private static func parseHeaders(_ content: String) -> [String: String] {
        var headers: [String: String] = [:]
        var currentHeader: String?
        var currentValue: String?

        // Split by lines and process
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            // Empty line marks end of headers
            if line.isEmpty {
                break
            }

            // Check if this is a continuation line (starts with whitespace)
            if line.first?.isWhitespace == true, let header = currentHeader {
                // Unfold: append to current value with single space
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                currentValue = (currentValue ?? "") + " " + trimmed
                headers[header] = currentValue
            } else if let colonIndex = line.firstIndex(of: ":") {
                // New header
                let headerName = String(line[..<colonIndex]).lowercased()
                let headerValue = String(line[line.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)

                headers[headerName] = headerValue
                currentHeader = headerName
                currentValue = headerValue
            }
        }

        return headers
    }

    /// Parse RFC 2822 date format (e.g., "Mon, 6 Jan 2026 10:30:00 -0500").
    private static func parseRfc2822Date(_ dateString: String) -> Date? {
        let formatters = [
            // Standard RFC 2822 with day name
            "EEE, d MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss z",
            // Without day name
            "d MMM yyyy HH:mm:ss Z",
            "d MMM yyyy HH:mm:ss z",
            // With timezone name
            "EEE, d MMM yyyy HH:mm:ss zzz",
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    /// Decode RFC 2047 encoded words (e.g., "=?UTF-8?B?...?=" or "=?UTF-8?Q?...?=").
    private static func decodeRfc2047(_ input: String) -> String {
        // Pattern: =?charset?encoding?encoded_text?=
        let pattern = #"=\?([^?]+)\?([BbQq])\?([^?]+)\?="#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return input
        }

        var result = input
        let nsString = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: nsString.length))

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard match.numberOfRanges == 4 else { continue }

            let charsetRange = match.range(at: 1)
            let encodingRange = match.range(at: 2)
            let textRange = match.range(at: 3)

            let charset = nsString.substring(with: charsetRange)
            let encoding = nsString.substring(with: encodingRange).uppercased()
            let encodedText = nsString.substring(with: textRange)

            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
            let stringEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)

            var decoded: String?

            if encoding == "B" {
                // Base64
                if let data = Data(base64Encoded: encodedText) {
                    decoded = String(data: data, encoding: String.Encoding(rawValue: stringEncoding))
                }
            } else if encoding == "Q" {
                // Quoted-Printable
                decoded = decodeQuotedPrintable(encodedText, encoding: stringEncoding)
            }

            if let decodedString = decoded {
                let fullMatchRange = match.range(at: 0)
                result = (result as NSString).replacingCharacters(in: fullMatchRange, with: decodedString)
            }
        }

        return result
    }

    /// Decode quoted-printable encoding.
    private static func decodeQuotedPrintable(_ input: String, encoding: UInt) -> String? {
        var bytes: [UInt8] = []
        var i = input.startIndex

        while i < input.endIndex {
            let char = input[i]

            if char == "=" {
                // Get next two hex characters
                let nextIndex = input.index(after: i)
                guard nextIndex < input.endIndex else { break }
                let thirdIndex = input.index(after: nextIndex)
                guard thirdIndex < input.endIndex else { break }
                let fourthIndex = input.index(after: thirdIndex)

                let hexString = String(input[nextIndex ..< fourthIndex])
                if let byte = UInt8(hexString, radix: 16) {
                    bytes.append(byte)
                    i = fourthIndex
                    continue
                }
            } else if char == "_" {
                // Underscore represents space in Q encoding
                bytes.append(0x20)
            } else {
                bytes.append(UInt8(char.asciiValue ?? 0))
            }

            i = input.index(after: i)
        }

        return String(data: Data(bytes), encoding: String.Encoding(rawValue: encoding))
    }
}
