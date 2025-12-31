import Foundation
@testable import LauncherApp
import XCTest

/// Shared test utilities to avoid duplication across test files.
enum TestHelpers {
    /// Decode a JSON string into a Decodable type.
    ///
    /// - Parameters:
    ///   - type: The type to decode into
    ///   - json: The JSON string to decode
    /// - Returns: The decoded value
    /// - Throws: If the JSON is invalid or doesn't match the type
    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try JSONDecoder().decode(type, from: data)
    }

    /// Create a test ApiTask with configurable properties.
    ///
    /// All parameters have sensible defaults so you only need to specify
    /// the properties relevant to your test.
    static func makeTask(
        id: String,
        urgency: Int? = nil,
        project: String? = nil,
        tags: [String] = [],
        dateDue: String? = nil,
        status: String = "pending",
        summary: String? = nil,
        dateCreated: String = "2024-01-01T00:00:00Z",
        dateCompleted: String? = nil
    ) -> ApiTask {
        ApiTask(
            dbId: nil,
            uuid: id,
            status: status,
            summary: summary ?? "Task \(id)",
            project: project,
            tags: tags,
            dateCreated: dateCreated,
            dateCompleted: dateCompleted,
            dateDue: dateDue,
            urgency: urgency
        )
    }
}
