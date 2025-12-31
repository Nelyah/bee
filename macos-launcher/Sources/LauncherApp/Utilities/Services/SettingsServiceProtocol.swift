import Foundation

/// Protocol for settings/preferences storage, enabling dependency injection and testability.
///
/// This abstracts UserDefaults access from ViewModels, following the same pattern as
/// `ApiClientProtocol`. Implementations include `UserDefaultsSettingsService` for production
/// and `MockSettingsService` for tests and SwiftUI previews.
protocol SettingsServiceProtocol: AnyObject {
    // MARK: - Report Selection

    /// The currently selected report name. Empty string means use default report.
    var selectedReportName: String { get set }

    // MARK: - Grouping Preferences

    /// The raw value of the selected GroupByOption. Nil means use default (.project).
    var selectedGroupBy: String? { get set }

    /// Array of collapsed group keys (non-nil groups only).
    var collapsedGroups: [String] { get set }

    /// Whether the nil group (e.g., "No Project") is collapsed.
    var collapsedNilGroup: Bool { get set }

    // MARK: - Bulk Operations

    /// Clears the collapsed groups state (both collapsedGroups and collapsedNilGroup).
    /// Called when the grouping strategy changes since old keys won't apply.
    func clearCollapsedState()
}
