import Foundation

// MARK: - Project Statistics Models

/// Statistics breakdown for a single project.
struct ProjectStats: Codable, Equatable {
    let name: String
    let pendingCount: Int
    let activeCount: Int
    let completedCount: Int
    let overdueCount: Int
    let totalCount: Int
    /// Optional emoji for visual identification (single emoji character).
    let emoji: String?
    /// Optional hex color for project theming (e.g., "#FF5733").
    let color: String?

    enum CodingKeys: String, CodingKey {
        case name
        case pendingCount = "pending_count"
        case activeCount = "active_count"
        case completedCount = "completed_count"
        case overdueCount = "overdue_count"
        case totalCount = "total_count"
        case emoji
        case color
    }
}

/// Hierarchical project node with nested children.
struct ProjectNode: Codable, Identifiable, Equatable {
    /// Display name (leaf name, e.g., "api").
    let name: String
    /// Full path with dot notation (e.g., "backend.api").
    let fullPath: String
    /// Optional emoji for visual identification (single emoji character).
    let emoji: String?
    /// Optional hex color for project theming (e.g., "#FF5733").
    let color: String?
    /// Statistics for this project (including children aggregated).
    let stats: ProjectStats
    /// Child projects.
    let children: [ProjectNode]

    var id: String { fullPath }

    /// Whether this node has any children.
    var hasChildren: Bool { !children.isEmpty }

    enum CodingKeys: String, CodingKey {
        case name
        case fullPath = "full_path"
        case emoji
        case color
        case stats
        case children
    }
}

/// Response from GET /v1/projects.
struct ProjectsResponse: Codable {
    let projects: [ProjectNode]
}

// MARK: - Burndown Chart Models

/// Single data point for burndown chart.
struct BurndownDataPoint: Codable, Identifiable, Equatable {
    /// Date in YYYY-MM-DD format.
    let date: String
    /// Cumulative completed tasks up to this date.
    let completedCumulative: Int
    /// Remaining tasks (total - completed cumulative).
    let remaining: Int

    var id: String { date }

    /// Parse date string to Date.
    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case date
        case completedCumulative = "completed_cumulative"
        case remaining
    }
}

/// Response from GET /v1/projects/{name}/burndown.
struct ProjectBurndownResponse: Codable, Equatable {
    /// Project name (full path).
    let project: String
    /// Data points for the burndown chart (sorted by date ascending).
    let dataPoints: [BurndownDataPoint]
    /// Total tasks in this project (historical max).
    let totalTasks: Int
    /// Total completed tasks.
    let totalCompleted: Int

    enum CodingKeys: String, CodingKey {
        case project
        case dataPoints = "data_points"
        case totalTasks = "total_tasks"
        case totalCompleted = "total_completed"
    }
}

// MARK: - Project Update Models

/// Request payload for PATCH /v1/projects/{name}.
struct UpdateProjectRequest: Encodable {
    /// Optional emoji for visual identification. Set to explicit nil to clear.
    let emoji: String??
    /// Optional hex color for project theming. Set to explicit nil to clear.
    let color: String??

    init(emoji: String?? = .none, color: String?? = .none) {
        self.emoji = emoji
        self.color = color
    }
}

/// Response payload for PATCH /v1/projects/{name}.
struct UpdateProjectResponse: Codable {
    /// Project name (full path).
    let name: String
    /// Updated emoji (if set).
    let emoji: String?
    /// Updated color (if set).
    let color: String?
}
