import Foundation

// MARK: - Column Sort State

/// Sort direction for a column.
enum ColumnSortDirection: String, Codable, Equatable {
    case ascending
    case descending

    /// Toggle to the opposite direction.
    var toggled: ColumnSortDirection {
        self == .ascending ? .descending : .ascending
    }
}

/// Represents active sort state for the task list.
/// When nil, the default sort is by urgency (descending).
struct ColumnSortState: Codable, Equatable {
    /// The column key to sort by (e.g., "urgency", "date_created").
    let column: String
    /// Sort direction (ascending or descending).
    let direction: ColumnSortDirection

    /// Create a new sort state for ascending sort on a column.
    static func ascending(_ column: String) -> ColumnSortState {
        ColumnSortState(column: column, direction: .ascending)
    }

    /// Create a new sort state for descending sort on a column.
    static func descending(_ column: String) -> ColumnSortState {
        ColumnSortState(column: column, direction: .descending)
    }
}

// MARK: - Column Configuration

/// Configuration for a single column including width.
struct ColumnConfig: Codable, Identifiable, Equatable {
    /// Technical name: "id", "summary", "status", etc.
    let key: String
    /// Human-readable display name: "ID", "Summary", "Status", etc.
    let displayName: String
    /// Custom width in pixels. nil = use default width.
    var width: CGFloat?

    var id: String { key }

    /// Whether this column should flex (take remaining space).
    var isFlex: Bool { key == "summary" }

    /// Default widths per column type.
    static func defaultWidth(for key: String) -> CGFloat {
        switch key {
        case "id": 30
        case "uuid": 60
        case "status": 80
        case "tags": 80
        case "project": 100
        case "date_created", "date_completed", "date_due": 80
        case "urgency": 50
        case "summary": 0 // Flex column - uses remaining space
        default: 60
        }
    }

    /// Minimum allowed width for resizing.
    static func minimumWidth(for key: String) -> CGFloat {
        switch key {
        case "id": 24
        case "summary": 120
        default: 60
        }
    }

    /// The effective width to use (custom or default).
    var effectiveWidth: CGFloat {
        width ?? Self.defaultWidth(for: key)
    }
}

// MARK: - Column Definition

/// All available column types that can be added to a report.
enum ColumnDefinition: String, CaseIterable, Identifiable {
    case id
    case uuid
    case status
    case summary
    case project
    case tags
    case dateCreated = "date_created"
    case dateCompleted = "date_completed"
    case dateDue = "date_due"
    case urgency

    var id: String { rawValue }

    /// Human-readable display name for the column.
    var displayName: String {
        switch self {
        case .id: "ID"
        case .uuid: "UUID"
        case .status: "Status"
        case .summary: "Summary"
        case .project: "Project"
        case .tags: "Tags"
        case .dateCreated: "Created"
        case .dateCompleted: "Completed"
        case .dateDue: "Due"
        case .urgency: "Urgency"
        }
    }

    /// SF Symbol icon for the column (used in Command Palette).
    var icon: String {
        switch self {
        case .id: "number"
        case .uuid: "barcode"
        case .status: "circle.fill"
        case .summary: "text.alignleft"
        case .project: "folder"
        case .tags: "tag"
        case .dateCreated: "calendar.badge.plus"
        case .dateCompleted: "checkmark.circle"
        case .dateDue: "calendar.badge.clock"
        case .urgency: "flame"
        }
    }

    /// Whether this column can be removed from the report.
    /// Summary is always required.
    var isRemovable: Bool { self != .summary }

    /// Whether this column supports sorting.
    var isSortable: Bool { true }

    /// Create a ColumnConfig from this definition.
    func toConfig() -> ColumnConfig {
        ColumnConfig(key: rawValue, displayName: displayName, width: nil)
    }
}
