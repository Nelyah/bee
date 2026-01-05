import Foundation
import UniformTypeIdentifiers

/// Utilities for handling email drops from Apple Mail and EML files.
///
/// The actual drop handling is done by `FilePromiseDropNSView` (AppKit-based)
/// because Apple Mail's file promises don't work reliably with SwiftUI's DropDelegate.
/// This enum provides utility functions used by that implementation.
enum EmailDropHandler {
    /// The types of content that can be accepted for email drops.
    static let acceptedTypes: [UTType] = [
        .emailMessage,
        .fileURL,
        UTType(filenameExtension: "eml") ?? .data,
    ]

    /// Check if a URL points to an EML file.
    static func isEMLFile(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "eml"
    }
}
