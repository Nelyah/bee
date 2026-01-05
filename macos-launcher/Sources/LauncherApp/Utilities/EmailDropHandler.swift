import Foundation
import UniformTypeIdentifiers

/// Handles email drops from Apple Mail and EML files.
///
/// Apple Mail drag-and-drop provides:
/// - UTType.emailMessage for email content
/// - File promises that resolve to .eml files
///
/// This handler processes both direct file drops and Mail-specific drops.
final class EmailDropHandler {
    /// The types of content this handler can accept.
    static let acceptedTypes: [UTType] = [
        .emailMessage,
        .fileURL,
        UTType(filenameExtension: "eml") ?? .data,
    ]

    /// Callback when an email is successfully parsed.
    private let onEmailParsed: (ParsedEmail) -> Void

    init(onEmailParsed: @escaping (ParsedEmail) -> Void) {
        self.onEmailParsed = onEmailParsed
    }

    // MARK: - Processing Methods

    /// Process raw EML content string.
    func processEMLContent(_ content: String) throws {
        let parsed = try EMLParser.parse(content: content)
        onEmailParsed(parsed)
    }

    /// Process a file URL (either .eml file or file promise result).
    func processFileURL(_ url: URL) async throws {
        let parsed = try EMLParser.parse(fileURL: url)
        onEmailParsed(parsed)
    }

    // MARK: - Detection Helpers

    /// Check if a URL points to an EML file.
    static func isEMLFile(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "eml"
    }

    /// Check if this URL should be treated as an email drop.
    static func isEmailDrop(_ url: URL) -> Bool {
        isEMLFile(url)
    }
}

// MARK: - SwiftUI DropDelegate Integration

import SwiftUI

// MARK: - Drop Processor

/// Processes file URLs and routes them to appropriate handlers.
///
/// This is the core logic extracted for testability. It handles:
/// - Regular files → `onFileDropped` callback
/// - EML files → parsed and sent to `onEmailDropped` callback
struct DropProcessor {
    let onFileDropped: ([URL]) -> Void
    let onEmailDropped: (ParsedEmail) -> Void

    /// Process file URLs, routing EML files to email handler and others to file handler.
    func processFileURLs(_ urls: [URL]) {
        var regularFiles: [URL] = []

        for url in urls {
            if EmailDropHandler.isEMLFile(url) {
                // Parse EML and route to email handler
                do {
                    let parsed = try EMLParser.parse(fileURL: url)
                    onEmailDropped(parsed)
                } catch {
                    print("Error parsing EML file: \(error)")
                }
            } else {
                regularFiles.append(url)
            }
        }

        // Send regular files to file handler
        if !regularFiles.isEmpty {
            onFileDropped(regularFiles)
        }
    }
}

// MARK: - File Promise Processor

/// Processes resolved file promise URLs (used by Apple Mail).
///
/// Apple Mail provides emails as file promises that resolve to .eml files.
/// This processor handles the resolved URLs and routes them appropriately.
struct FilePromiseProcessor {
    let onFileDropped: ([URL]) -> Void
    let onEmailDropped: (ParsedEmail) -> Void

    /// Process a single resolved file promise URL.
    func processResolvedFilePromise(_ url: URL) {
        if EmailDropHandler.isEMLFile(url) {
            do {
                let parsed = try EMLParser.parse(fileURL: url)
                onEmailDropped(parsed)
            } catch {
                print("Error parsing EML from file promise: \(error)")
            }
        } else {
            onFileDropped([url])
        }
    }
}

/// A drop delegate that handles both file attachments and email drops.
///
/// This delegate:
/// 1. Routes .eml files to the email handler
/// 2. Routes other files to the attachment handler
/// 3. Handles Mail's file promises for email content
///
/// **Important:** Apple Mail provides file promises, not direct URLs.
/// We try `loadObject(ofClass: URL.self)` first for Finder drops,
/// then fall back to `loadFileRepresentation` for Mail drops.
struct AttachmentAndEmailDropDelegate: DropDelegate {
    let onFileDropped: ([URL]) -> Void
    let onEmailDropped: (ParsedEmail) -> Void

    private var promiseProcessor: FilePromiseProcessor {
        FilePromiseProcessor(onFileDropped: onFileDropped, onEmailDropped: onEmailDropped)
    }

    private var dropProcessor: DropProcessor {
        DropProcessor(onFileDropped: onFileDropped, onEmailDropped: onEmailDropped)
    }

    func validateDrop(info: DropInfo) -> Bool {
        // Accept file URLs or email messages (for file promises)
        info.hasItemsConforming(to: [.fileURL, .emailMessage, .item])
    }

    func performDrop(info: DropInfo) -> Bool {
        // Get all providers - try emailMessage first, then fall back to fileURL/item
        var providers = info.itemProviders(for: [.emailMessage])
        if providers.isEmpty {
            providers = info.itemProviders(for: [.fileURL, .item])
        }

        guard !providers.isEmpty else { return false }

        for provider in providers {
            processProvider(provider)
        }
        return true
    }

    /// Process a single NSItemProvider, handling both direct URLs and file promises.
    ///
    /// Strategy:
    /// 1. Try loadObject first (fast path for Finder drops)
    /// 2. If that fails, fall back to loadFileRepresentation (for Mail file promises)
    ///
    /// **Important:** Apple Mail claims to support URL loading (`canLoadObject` returns true)
    /// but `loadObject` fails. We must fall back to `loadFileRepresentation` in that case.
    func processProvider(_ provider: NSItemProvider) {
        if provider.canLoadObject(ofClass: URL.self) {
            // Try fast path first: direct URL (Finder drops)
            _ = provider.loadObject(ofClass: URL.self) { [dropProcessor, promiseProcessor] url, error in
                if let url, error == nil {
                    DispatchQueue.main.async {
                        dropProcessor.processFileURLs([url])
                    }
                } else {
                    // Fallback: try file promise (for Mail, which claims URL support but fails)
                    Self.tryFilePromiseFallback(provider: provider, promiseProcessor: promiseProcessor)
                }
            }
        } else {
            // Slow path: file promise (Mail drops where canLoadObject is false)
            Self.tryFilePromiseFallback(provider: provider, promiseProcessor: promiseProcessor)
        }
    }

    /// Try loading content via file representation (file promises).
    ///
    /// This is used for Apple Mail drops where content is provided as file promises
    /// rather than direct URLs.
    ///
    /// **IMPORTANT:** Apple's `loadFileRepresentation` provides a temporary file that is
    /// deleted when the callback returns. We MUST read the file content synchronously
    /// within the callback, before it returns. Then we can safely dispatch parsing to
    /// the main queue with the content (not the URL).
    private static func tryFilePromiseFallback(provider: NSItemProvider, promiseProcessor: FilePromiseProcessor) {
        // IMPORTANT: Use the provider's ACTUAL registered type, not our assumed types.
        // hasItemConformingToTypeIdentifier checks UTType hierarchy conformance, but
        // loadFileRepresentation may require the exact registered type identifier.
        let emailTypes = ["com.apple.mail.email", "public.email-message", "public.eml"]
        let actualEmailType = provider.registeredTypeIdentifiers.first { typeId in
            emailTypes.contains(typeId) || typeId.contains("mail") || typeId.contains("email")
        }

        // Fall back to checking our known types if no email type found
        let fallbackTypes = [
            UTType.emailMessage.identifier,
            UTType.data.identifier,
            "com.apple.mail.email",
            "public.eml",
        ]

        let typeIdToUse: String
        if let actualType = actualEmailType {
            typeIdToUse = actualType
        } else {
            // Fall back to first matching type from our list
            guard let firstMatch = fallbackTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                return
            }
            typeIdToUse = firstMatch
        }

        // Try loadDataRepresentation first - this loads raw bytes directly
        // which may work better than file promises for Apple Mail.
        provider.loadDataRepresentation(forTypeIdentifier: typeIdToUse) { data, error in
            if error != nil {
                // Fall back to file representation
                Self.tryLoadFileRepresentation(
                    provider: provider,
                    typeIdToUse: typeIdToUse,
                    promiseProcessor: promiseProcessor
                )
                return
            }
            guard let data,
                  let content = String(data: data, encoding: .utf8) else {
                Self.tryLoadFileRepresentation(
                    provider: provider,
                    typeIdToUse: typeIdToUse,
                    promiseProcessor: promiseProcessor
                )
                return
            }

            DispatchQueue.main.async {
                if let parsed = try? EMLParser.parse(content: content) {
                    promiseProcessor.onEmailDropped(parsed)
                }
            }
        }
    }

    /// Fallback: Try loading via file representation (for file promises).
    private static func tryLoadFileRepresentation(
        provider: NSItemProvider,
        typeIdToUse: String,
        promiseProcessor: FilePromiseProcessor
    ) {
        provider.loadFileRepresentation(forTypeIdentifier: typeIdToUse) { url, error in
            guard error == nil, let url else { return }

            // CRITICAL: Read file content SYNCHRONOUSLY before callback returns.
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

            DispatchQueue.main.async {
                if let parsed = try? EMLParser.parse(content: content) {
                    promiseProcessor.onEmailDropped(parsed)
                }
            }
        }
    }
}
