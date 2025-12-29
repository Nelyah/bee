import Foundation

/// Response payload from the /v1/config endpoint.
struct ConfigResponse: Decodable {
    let report: ReportConfig
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
