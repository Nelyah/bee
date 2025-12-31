import Foundation

/// Response payload from the /v1/config endpoint.
struct ConfigResponse: Decodable {
    /// Default report configuration (for backwards compatibility).
    let report: ReportConfig
    /// All available reports.
    let reports: [ReportSummary]
}

/// Report configuration defining columns and default filters.
struct ReportConfig: Decodable {
    /// Filter expressions for static reports (from config file).
    let staticFilters: [String]
    /// Serialized filter JSON for user reports (from parse API).
    /// Takes precedence over `staticFilters` when present.
    let userFilter: JSONValue?
    /// Field names to display (technical names like "id", "summary").
    let columns: [String]
    /// Display names for columns (human-readable like "ID", "Summary").
    let columnNames: [String]

    enum CodingKeys: String, CodingKey {
        case staticFilters = "filters"
        case userFilter = "filter"
        case columns
        case columnNames = "column_names"
    }

    /// Memberwise initializer for creating config from a ReportSummary.
    init(staticFilters: [String], userFilter: JSONValue? = nil, columns: [String], columnNames: [String]) {
        self.staticFilters = staticFilters
        self.userFilter = userFilter
        self.columns = columns
        self.columnNames = columnNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        staticFilters = try container.decodeIfPresent([String].self, forKey: .staticFilters) ?? []
        userFilter = try container.decodeIfPresent(JSONValue.self, forKey: .userFilter)
        columns = try container.decode([String].self, forKey: .columns)
        columnNames = try container.decode([String].self, forKey: .columnNames)
    }
}

/// Summary of a report for selection in the UI.
struct ReportSummary: Decodable, Identifiable {
    /// Report name (identifier).
    let name: String
    /// Filter expressions for static reports (from config).
    /// Empty for user reports - use `userFilter` instead.
    let staticFilters: [String]
    /// Serialized filter JSON for user reports (from parse API).
    /// This avoids re-parsing filter strings on reload.
    let userFilter: JSONValue?
    /// Field names to display (technical names like "id", "summary").
    let columns: [String]
    /// Display names for columns (human-readable like "ID", "Summary").
    let columnNames: [String]
    /// Whether this is the default report.
    let isDefault: Bool
    /// Whether this is a user-created report (vs. static from config).
    let isUserReport: Bool

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case staticFilters = "filters"
        case userFilter = "filter"
        case columns
        case columnNames = "column_names"
        case isDefault = "is_default"
        case isUserReport = "is_user_report"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        // Static reports have staticFilters; user reports may have empty array
        staticFilters = try container.decodeIfPresent([String].self, forKey: .staticFilters) ?? []
        // User reports have userFilter JSON; static reports have nil
        userFilter = try container.decodeIfPresent(JSONValue.self, forKey: .userFilter)
        columns = try container.decode([String].self, forKey: .columns)
        columnNames = try container.decode([String].self, forKey: .columnNames)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        // API only sends is_user_report when true, so default to false
        isUserReport = try container.decodeIfPresent(Bool.self, forKey: .isUserReport) ?? false
    }

    /// Memberwise initializer for tests and mocks.
    init(
        name: String,
        staticFilters: [String] = [],
        userFilter: JSONValue? = nil,
        columns: [String],
        columnNames: [String],
        isDefault: Bool,
        isUserReport: Bool = false
    ) {
        self.name = name
        self.staticFilters = staticFilters
        self.userFilter = userFilter
        self.columns = columns
        self.columnNames = columnNames
        self.isDefault = isDefault
        self.isUserReport = isUserReport
    }
}

// MARK: - User Reports DTOs

/// Request payload for creating or updating a user report.
struct UserReportRequest: Encodable {
    let name: String
    /// Serialized filter JSON from parse API.
    let filter: JSONValue?
    let columns: [String]
    let columnNames: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case filter
        case columns
        case columnNames = "column_names"
    }
}

/// Response payload for user report operations.
struct UserReportDto: Decodable {
    let name: String
    /// Serialized filter JSON.
    let filter: JSONValue?
    let columns: [String]
    let columnNames: [String]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case name
        case filter
        case columns
        case columnNames = "column_names"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Response payload for listing user reports.
struct UserReportsListResponse: Decodable {
    let reports: [UserReportDto]
}
