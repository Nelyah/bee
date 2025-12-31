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

    // MARK: - External Link Helpers

    /// Create a test ExternalLinkDto with configurable properties.
    ///
    /// Defaults create a GitLab merge request link with no cached data.
    static func makeExternalLink(
        id: Int = 1,
        provider: String = "gitlab",
        url: String = "https://gitlab.com/org/repo/-/merge_requests/123",
        externalKey: String = "org/repo!123",
        cachedResponse: String? = nil,
        lastSyncedAt: String? = nil,
        syncError: String? = nil
    ) -> ExternalLinkDto {
        ExternalLinkDto(
            id: id,
            provider: provider,
            url: url,
            externalKey: externalKey,
            cachedResponse: cachedResponse,
            lastSyncedAt: lastSyncedAt,
            syncError: syncError
        )
    }

    /// Create a GitLab MR link with cached summary data.
    static func makeGitLabMRLink(
        id: Int = 1,
        iid: Int = 123,
        title: String = "Add new feature",
        state: String = "opened",
        comments: Int = 5,
        pipelineStatus: String? = "success",
        approved: Bool = false,
        sourceBranch: String = "feature/new-feature",
        lastSyncedAt: String = "2024-01-15T10:30:00Z"
    ) -> ExternalLinkDto {
        let cachedJson = """
        {
            "iid": \(iid),
            "title": "\(title)",
            "state": "\(state)",
            "user_notes_count": \(comments),
            "source_branch": "\(sourceBranch)"
            \(pipelineStatus.map { ", \"head_pipeline\": {\"status\": \"\($0)\"}" } ?? "")
        }
        """
        return ExternalLinkDto(
            id: id,
            provider: "gitlab",
            url: "https://gitlab.com/org/repo/-/merge_requests/\(iid)",
            externalKey: "org/repo!\(iid)",
            cachedResponse: cachedJson,
            lastSyncedAt: lastSyncedAt,
            syncError: nil
        )
    }

    // MARK: - Annotation Helpers

    /// Create a test TaskAnnotationDto.
    static func makeAnnotation(
        value: String = "Test annotation",
        time: String = "2024-01-15T10:30:00Z"
    ) -> TaskAnnotationDto {
        TaskAnnotationDto(value: value, time: time)
    }

    // MARK: - Command Palette Helpers

    /// Create a test CommandPaletteSection with items.
    static func makeCommandPaletteSection(
        id: String = "test-section",
        title: String? = "Test Section",
        items: [CommandPaletteItem] = []
    ) -> CommandPaletteSection {
        CommandPaletteSection(id: id, title: title, items: items)
    }

    /// Create a simple action item for the command palette.
    static func makeCommandPaletteActionItem(
        id: String = "test-action",
        title: String = "Test Action",
        subtitle: String? = nil,
        icon: CommandPaletteIcon? = .system("star"),
        shortcut: String? = nil,
        handler: @escaping () -> Void = {}
    ) -> CommandPaletteItem {
        .action(CommandPaletteActionItem(
            id: id,
            title: title,
            subtitle: subtitle,
            icon: icon,
            shortcut: shortcut,
            requiresSelectedTask: false,
            handler: handler
        ))
    }

    /// Create a submenu item for the command palette.
    static func makeCommandPaletteSubmenuItem(
        id: String = "test-submenu",
        title: String = "Test Submenu",
        subtitle: String? = nil,
        icon: CommandPaletteIcon? = .system("folder"),
        menuBuilder: @escaping @MainActor () -> CommandPaletteMenu = { CommandPaletteMenu(
            title: "Test Menu",
            sections: []
        ) }
    ) -> CommandPaletteItem {
        .submenu(CommandPaletteSubmenuItem(
            id: id,
            title: title,
            subtitle: subtitle,
            icon: icon,
            menuBuilder: menuBuilder
        ))
    }

    // MARK: - Completion Menu Helpers

    /// Create a test CompletionItem.
    static func makeCompletionItem(
        value: String = "test-value",
        count: Int? = nil
    ) -> CompletionItem {
        CompletionItem(value: value, count: count)
    }

    /// Create multiple completion items for testing.
    static func makeCompletionItems(_ values: [String]) -> [CompletionItem] {
        values.map { CompletionItem(value: $0, count: nil) }
    }

    /// Create a test CommandPaletteMenu with sections.
    static func makeCommandPaletteMenu(
        id: String = "test-menu",
        title: String = "Test Menu",
        sections: [CommandPaletteSection] = []
    ) -> CommandPaletteMenu {
        CommandPaletteMenu(id: id, title: title, sections: sections)
    }

    // MARK: - Task Detail Helpers

    /// Create a test ApiTaskDetail with annotations and history.
    static func makeTaskDetail(
        id: String = "test-uuid",
        summary: String = "Test Task",
        project: String? = "TestProject",
        tags: [String] = [],
        status: String = "pending",
        annotations: [TaskAnnotationDto] = [],
        history: [TaskHistoryDto] = []
    ) -> ApiTaskDetail {
        ApiTaskDetail(
            dbId: 1,
            uuid: id,
            status: status,
            summary: summary,
            project: project,
            tags: tags,
            dateCreated: "2024-01-01T00:00:00Z",
            dateCompleted: nil,
            dateDue: nil,
            urgency: nil,
            annotations: annotations,
            history: history
        )
    }
}
