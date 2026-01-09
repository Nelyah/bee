import Foundation

/// A registered navigation target with its screen coordinates and identity.
///
/// NavigationTarget wraps a `DetailFocusableItem` with its frame in the navigation
/// coordinate space, enabling coordinate-based navigation via hjkl keys.
struct NavigationTarget: Identifiable, Equatable {
    /// Unique identifier matching `DetailFocusableItem.id`.
    let id: String

    /// The focusable item this target represents.
    let item: DetailFocusableItem

    /// Frame in the navigation coordinate space (set by the scroll content's coordinate space).
    var frame: CGRect

    /// Center point used for navigation calculations.
    var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}
