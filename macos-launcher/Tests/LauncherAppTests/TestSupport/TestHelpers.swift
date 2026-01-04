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
        history: [TaskHistoryDto] = [],
        links: [TaskLinkDto] = [],
        attachments: [TaskAttachmentDto] = []
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
            history: history,
            links: links,
            attachments: attachments
        )
    }

    // MARK: - Task Link Helpers

    /// Create a test TaskLinkDto.
    static func makeTaskLink(
        linkType: LinkType = .blocking,
        targetUuid: String = "target-uuid"
    ) -> TaskLinkDto {
        // We need to create via JSON since TaskLinkDto has no memberwise init
        let json = """
        {
            "link_type": "\(linkType.rawValue)",
            "target_uuid": "\(targetUuid)"
        }
        """
        // Safe to force-unwrap since we control the input format
        do {
            return try decode(TaskLinkDto.self, from: json)
        } catch {
            fatalError("Failed to decode TaskLinkDto: \(error)")
        }
    }

    /// Create task links grouped by type for testing LinkedTasksSection.
    static func makeTaskLinksGrouped(
        _ specs: [(LinkType, String)]
    ) -> (links: [TaskLinkDto], byType: [LinkType: [TaskLinkDto]]) {
        let links = specs.map { makeTaskLink(linkType: $0.0, targetUuid: $0.1) }
        var byType: [LinkType: [TaskLinkDto]] = [:]
        for link in links {
            if let type = link.type {
                byType[type, default: []].append(link)
            }
        }
        return (links, byType)
    }

    // MARK: - Token Helpers

    /// Create a test TokenSpan for syntax highlighting tests.
    static func makeToken(
        type: TokenType,
        literal: String,
        start: Int,
        end: Int
    ) -> TokenSpan {
        TokenSpan(tokenType: type, literal: literal, start: start, end: end)
    }

    /// Sample tokens for "list +work project:api" input.
    static let sampleTokens: [TokenSpan] = [
        TokenSpan(tokenType: .wordString, literal: "list", start: 0, end: 4),
        TokenSpan(tokenType: .blank, literal: " ", start: 4, end: 5),
        TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 5, end: 6),
        TokenSpan(tokenType: .wordString, literal: "work", start: 6, end: 10),
        TokenSpan(tokenType: .blank, literal: " ", start: 10, end: 11),
        TokenSpan(tokenType: .projectPrefix, literal: "project:", start: 11, end: 19),
        TokenSpan(tokenType: .wordString, literal: "api", start: 19, end: 22),
    ]

    // MARK: - Group Helpers

    /// Create a test GroupHeader for grouped list tests.
    static func makeGroupHeader(
        key: String? = "project",
        displayName: String = "Test Project",
        taskCount: Int = 3,
        isCollapsed: Bool = false
    ) -> GroupHeader {
        GroupHeader(key: key, displayName: displayName, taskCount: taskCount, isCollapsed: isCollapsed)
    }

    // MARK: - Criteria Chip Helpers

    /// Create a test CriteriaChip for filter display tests.
    static func makeCriteriaChip(
        kind: CriteriaChipKind = .filter,
        label: String = "status:pending",
        systemImage: String = "line.3.horizontal.decrease.circle",
        tone: CriteriaChipTone = .blue
    ) -> CriteriaChip {
        CriteriaChip(kind: kind, label: label, systemImage: systemImage, tone: tone)
    }

    /// Sample criteria chips for testing criteria strip display.
    static let sampleFilterChips: [CriteriaChip] = [
        CriteriaChip(
            kind: .filter,
            label: "status:pending",
            systemImage: "line.3.horizontal.decrease.circle",
            tone: .blue
        ),
        CriteriaChip(
            kind: .filter,
            label: "+work",
            systemImage: "tag",
            tone: .teal
        ),
    ]

    /// Sample property chips for testing criteria strip display.
    static let samplePropertyChips: [CriteriaChip] = [
        CriteriaChip(
            kind: .property,
            label: "project:api",
            systemImage: "folder",
            tone: .green
        ),
    ]

    // MARK: - Report Helpers

    /// Create a test ReportSummary.
    static func makeReportSummary(
        name: String = "default",
        staticFilters: [String] = [],
        columns: [String] = ["id", "summary"],
        columnNames: [String] = ["ID", "Summary"],
        isDefault: Bool = true,
        isUserReport: Bool = false
    ) -> ReportSummary {
        ReportSummary(
            name: name,
            staticFilters: staticFilters,
            columns: columns,
            columnNames: columnNames,
            isDefault: isDefault,
            isUserReport: isUserReport
        )
    }

    // MARK: - Column Config Helpers

    /// Create ColumnConfig array from column keys.
    /// Useful for tests that previously used [String] for columns.
    static func makeColumnConfigs(from columns: [String]) -> [ColumnConfig] {
        columns.map { key in
            let displayName = ColumnDefinition(rawValue: key)?.displayName ?? key.capitalized
            return ColumnConfig(key: key, displayName: displayName, width: nil)
        }
    }

    /// Standard column configs used in most tests.
    static let standardColumnConfigs: [ColumnConfig] = [
        ColumnConfig(key: "id", displayName: "ID", width: nil),
        ColumnConfig(key: "summary", displayName: "Summary", width: nil),
        ColumnConfig(key: "tags", displayName: "Tags", width: nil),
        ColumnConfig(key: "status", displayName: "Status", width: nil),
    ]

    /// All-columns config for comprehensive tests.
    static let allColumnConfigs: [ColumnConfig] = [
        ColumnConfig(key: "id", displayName: "ID", width: nil),
        ColumnConfig(key: "summary", displayName: "Summary", width: nil),
        ColumnConfig(key: "status", displayName: "Status", width: nil),
        ColumnConfig(key: "project", displayName: "Project", width: nil),
        ColumnConfig(key: "tags", displayName: "Tags", width: nil),
        ColumnConfig(key: "urgency", displayName: "Urgency", width: nil),
    ]

    // MARK: - Settings Service Helpers

    /// Create a MockSettingsService for testing.
    static func makeSettingsService(
        selectedReportName: String = "",
        selectedGroupBy: String? = nil,
        collapsedGroups: [String] = [],
        collapsedNilGroup: Bool = false
    ) -> MockSettingsService {
        let service = MockSettingsService()
        service.selectedReportName = selectedReportName
        service.selectedGroupBy = selectedGroupBy
        service.collapsedGroups = collapsedGroups
        service.collapsedNilGroup = collapsedNilGroup
        return service
    }
}
