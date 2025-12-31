import Foundation

/// Mock settings service for SwiftUI previews and unit tests.
///
/// Uses simple stored properties instead of UserDefaults, making it easy to
/// set up specific test scenarios without affecting system state.
final class MockSettingsService: SettingsServiceProtocol {
    // MARK: - Properties

    var selectedReportName: String = ""
    var selectedGroupBy: String?
    var collapsedGroups: [String] = []
    var collapsedNilGroup: Bool = false

    // MARK: - Call Tracking

    /// Tracks whether `clearCollapsedState()` was called.
    private(set) var clearCollapsedStateCalled = false

    // MARK: - Bulk Operations

    func clearCollapsedState() {
        collapsedGroups = []
        collapsedNilGroup = false
        clearCollapsedStateCalled = true
    }

    // MARK: - Test Helpers

    /// Resets all properties and call tracking to defaults.
    func reset() {
        selectedReportName = ""
        selectedGroupBy = nil
        collapsedGroups = []
        collapsedNilGroup = false
        clearCollapsedStateCalled = false
    }
}
