import Foundation

/// UserDefaults-backed implementation of SettingsServiceProtocol.
///
/// This is the production implementation that persists settings to UserDefaults.
/// For testing, use `MockSettingsService` or inject a dedicated `UserDefaults` suite.
final class UserDefaultsSettingsService: SettingsServiceProtocol {
    private let defaults: UserDefaults

    /// Creates a settings service backed by the specified UserDefaults.
    /// - Parameter defaults: The UserDefaults instance to use. Defaults to `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Report Selection

    var selectedReportName: String {
        get { defaults.string(forKey: UserDefaultsKeys.selectedReportName) ?? "" }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.selectedReportName) }
    }

    // MARK: - Grouping Preferences

    var selectedGroupBy: String? {
        get { defaults.string(forKey: UserDefaultsKeys.selectedGroupBy) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: UserDefaultsKeys.selectedGroupBy)
            } else {
                defaults.removeObject(forKey: UserDefaultsKeys.selectedGroupBy)
            }
        }
    }

    var collapsedGroups: [String] {
        get { defaults.stringArray(forKey: UserDefaultsKeys.collapsedGroups) ?? [] }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.collapsedGroups) }
    }

    var collapsedNilGroup: Bool {
        get { defaults.bool(forKey: UserDefaultsKeys.collapsedNilGroup) }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.collapsedNilGroup) }
    }

    // MARK: - Bulk Operations

    func clearCollapsedState() {
        defaults.set([String](), forKey: UserDefaultsKeys.collapsedGroups)
        defaults.set(false, forKey: UserDefaultsKeys.collapsedNilGroup)
    }
}
