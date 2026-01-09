import SwiftUI

/// Entry for a single component's coordinates in the navigation system.
struct NavigationCoordinateEntry: Equatable {
    /// The focusable item this entry represents.
    let item: DetailFocusableItem

    /// Frame in the navigation coordinate space.
    let frame: CGRect
}

/// PreferenceKey for collecting navigation target coordinates from child views.
///
/// Child views use `.preference(key: NavigationCoordinatePreferenceKey.self, value: [entry])`
/// to report their coordinates. The parent view aggregates all entries via
/// `.onPreferenceChange` and registers them with the NavigationRegistry.
struct NavigationCoordinatePreferenceKey: PreferenceKey {
    typealias Value = [NavigationCoordinateEntry]

    static var defaultValue: [NavigationCoordinateEntry] = []

    static func reduce(value: inout [NavigationCoordinateEntry], nextValue: () -> [NavigationCoordinateEntry]) {
        value.append(contentsOf: nextValue())
    }
}
