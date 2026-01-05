import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// An AppKit view that handles email drops from Apple Mail.
///
/// Apple Mail provides emails as file promises, but these get cancelled when the drag
/// session ends (before the promise can be fulfilled). Instead, we extract email metadata
/// directly from the pasteboard which contains:
/// - `public.url`: The message:// URL with the Message-ID
/// - `public.url-name`: The email subject
final class FilePromiseDropNSView: NSView {
    var onFileDropped: (([URL]) -> Void)?
    var onEmailDropped: ((ParsedEmail) -> Void)?

    private var hasFilePromiseReceiver = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDropTarget()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDropTarget()
    }

    private func setupDropTarget() {
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("com.apple.mail.email"),
            NSPasteboard.PasteboardType(UTType.emailMessage.identifier),
            NSPasteboard.PasteboardType("public.url"),
            // Note: .filePromise is deprecated; we handle file promises via NSFilePromiseReceiver
        ])
    }

    // MARK: - Mouse Event Passthrough

    /// Allow mouse events to pass through to underlying SwiftUI views.
    ///
    /// This view is used as an overlay for drag-and-drop support. Without this override,
    /// NSView intercepts all mouse events (clicks, hovers) and blocks them from reaching
    /// the SwiftUI views underneath. By returning nil, we make this view "transparent"
    /// to regular mouse events while still receiving drag events via registerForDraggedTypes.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard

        // Check for file promise (Apple Mail)
        if pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil) {
            hasFilePromiseReceiver = true
            return .copy
        }

        // Check for direct file URLs (Finder)
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
            return .copy
        }

        // Check for message URL (alternate Mail format)
        if pasteboard.string(forType: .init("public.url"))?.hasPrefix("message:") == true {
            return .copy
        }

        return []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if hasFilePromiseReceiver { return .copy }
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) { return .copy }
        if pasteboard.string(forType: .init("public.url"))?.hasPrefix("message:") == true { return .copy }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        hasFilePromiseReceiver = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        // Try to extract email info directly from pasteboard (works for Apple Mail)
        if let email = extractEmailFromPasteboard(pasteboard) {
            DispatchQueue.main.async { [weak self] in
                self?.onEmailDropped?(email)
            }
            hasFilePromiseReceiver = false
            return true
        }

        // Handle direct file URLs (Finder drops, .eml files)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            var regularFiles: [URL] = []

            for url in urls {
                if EmailDropHandler.isEMLFile(url) {
                    do {
                        let parsed = try EMLParser.parse(fileURL: url)
                        DispatchQueue.main.async { [weak self] in
                            self?.onEmailDropped?(parsed)
                        }
                    } catch {
                        print("[FilePromiseDrop] Error parsing EML file: \(error)")
                    }
                } else {
                    regularFiles.append(url)
                }
            }

            if !regularFiles.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.onFileDropped?(regularFiles)
                }
            }

            return true
        }

        return false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        hasFilePromiseReceiver = false
    }

    // MARK: - Pasteboard Extraction

    /// Extract email info directly from the pasteboard.
    ///
    /// Apple Mail puts useful data in the pasteboard:
    /// - `public.url`: The message:// URL containing the Message-ID
    /// - `public.url-name`: The email subject
    private func extractEmailFromPasteboard(_ pasteboard: NSPasteboard) -> ParsedEmail? {
        // Get the message URL (contains Message-ID)
        guard let urlString = pasteboard.string(forType: .init("public.url")),
              urlString.hasPrefix("message:") else {
            return nil
        }

        // URL decode and extract Message-ID
        // Format can be:
        //   - message:%3CMessage-ID%3E (URL-encoded angle brackets)
        //   - message://%3CMessage-ID%3E (with path separator)
        //   - message://Message-ID (no angle brackets - rare)
        var encodedPart = String(urlString.dropFirst("message:".count))

        // Remove leading slashes if present (standard URL format)
        while encodedPart.hasPrefix("/") {
            encodedPart = String(encodedPart.dropFirst())
        }

        guard let decodedPart = encodedPart.removingPercentEncoding else {
            return nil
        }

        // Ensure Message-ID has angle brackets (required by RFC 5322)
        let messageId: String = if decodedPart.hasPrefix("<"), decodedPart.hasSuffix(">") {
            decodedPart
        } else {
            // Add angle brackets if missing
            "<\(decodedPart)>"
        }

        // Get the subject from public.url-name
        let subject = pasteboard.string(forType: .init("public.url-name"))
            ?? pasteboard.string(forType: .init("public.utf8-plain-text"))
            ?? "Unknown Subject"

        // Note: The sender is not available in the pasteboard data
        let sender = "Unknown Sender"

        return ParsedEmail(
            messageId: messageId,
            subject: subject,
            sender: sender,
            sentDate: nil
        )
    }
}

// MARK: - SwiftUI Wrapper

struct FilePromiseDropOverlay: NSViewRepresentable {
    let onFileDropped: ([URL]) -> Void
    let onEmailDropped: (ParsedEmail) -> Void

    func makeNSView(context: Context) -> FilePromiseDropNSView {
        let view = FilePromiseDropNSView()
        view.onFileDropped = onFileDropped
        view.onEmailDropped = onEmailDropped
        return view
    }

    func updateNSView(_ nsView: FilePromiseDropNSView, context: Context) {
        nsView.onFileDropped = onFileDropped
        nsView.onEmailDropped = onEmailDropped
    }
}

// MARK: - View Modifier

extension View {
    /// Adds file promise drop support for Apple Mail emails.
    ///
    /// Uses an AppKit NSView overlay for drag-and-drop because Apple Mail provides
    /// emails as file promises that require `NSDraggingDestination` to handle properly.
    /// The overlay is made non-interactive for regular mouse events (hover, click)
    /// so they pass through to the SwiftUI content underneath.
    func onFilePromiseDrop(
        onFileDropped: @escaping ([URL]) -> Void,
        onEmailDropped: @escaping (ParsedEmail) -> Void
    ) -> some View {
        overlay {
            FilePromiseDropOverlay(
                onFileDropped: onFileDropped,
                onEmailDropped: onEmailDropped
            )
            // Allow hover and click events to pass through to SwiftUI content.
            // Drag-and-drop still works because NSDraggingDestination uses a
            // separate event delivery system independent of hit-testing.
            .allowsHitTesting(false)
        }
    }
}
