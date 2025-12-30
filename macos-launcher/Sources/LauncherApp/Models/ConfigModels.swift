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
    /// Filter expressions to apply by default.
    let filters: [String]
    /// Field names to display (technical names like "id", "summary").
    let columns: [String]
    /// Display names for columns (human-readable like "ID", "Summary").
    let columnNames: [String]

    enum CodingKeys: String, CodingKey {
        case filters
        case columns
        case columnNames = "column_names"
    }
}

/// Summary of a report for selection in the UI.
struct ReportSummary: Decodable, Identifiable {
    /// Report name (identifier).
    let name: String
    /// Filter expressions to apply by default.
    let filters: [String]
    /// Field names to display (technical names like "id", "summary").
    let columns: [String]
    /// Display names for columns (human-readable like "ID", "Summary").
    let columnNames: [String]
    /// Whether this is the default report.
    let isDefault: Bool

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case filters
        case columns
        case columnNames = "column_names"
        case isDefault = "is_default"
    }
}
