import Combine
import Foundation

/// Navigation direction for hjkl keys.
enum NavigationDirection: Equatable {
    case left // h: strictly lesser X
    case right // l: strictly greater X
    case up // k: strictly lesser Y
    case down // j: strictly greater Y
}

/// Registry holding all registered navigation targets for coordinate-based focus navigation.
///
/// Components register themselves with their coordinates via `register(_:frame:)`.
/// Navigation uses strictly greater/lesser coordinate comparisons to find targets.
final class NavigationRegistry: ObservableObject {
    /// Tolerance in points for considering targets "aligned" on perpendicular axis.
    /// Targets within this tolerance are preferred over distant but valid targets.
    private static let alignmentTolerance: CGFloat = 20

    // MARK: - Published State

    /// All registered targets, keyed by their ID for O(1) lookup.
    @Published private(set) var targets: [String: NavigationTarget] = [:]

    /// Currently focused target ID (nil = no focus).
    @Published var focusedId: String?

    /// Whether keyboard navigation is active (lazy focus ring).
    /// When false, no focus ring is shown even if focusedId is set.
    @Published var isNavigationActive: Bool = false

    // MARK: - Registration

    /// Register or update a target's frame.
    ///
    /// Called by views via the `NavigationRegistrable` modifier when their
    /// geometry changes.
    func register(_ item: DetailFocusableItem, frame: CGRect) {
        let target = NavigationTarget(id: item.id, item: item, frame: frame)
        targets[item.id] = target
    }

    /// Unregister a target (e.g., when view disappears).
    func unregister(id: String) {
        targets.removeValue(forKey: id)
        // If we just removed the focused target, clear focus
        if focusedId == id {
            focusedId = nil
        }
    }

    /// Clear all targets (e.g., when navigating away from detail view).
    func clearAll() {
        targets.removeAll()
        focusedId = nil
        isNavigationActive = false
    }

    // MARK: - Focus Access

    /// The currently focused target, if any.
    var focusedTarget: NavigationTarget? {
        guard isNavigationActive, let id = focusedId else { return nil }
        return targets[id]
    }

    /// The currently focused item, if any.
    var focusedItem: DetailFocusableItem? {
        focusedTarget?.item
    }

    // MARK: - Navigation

    /// Activate navigation and focus the first target if none focused.
    ///
    /// Called on first hjkl press to show the focus ring.
    func activateNavigation() {
        guard !isNavigationActive else { return }
        isNavigationActive = true
        if focusedId == nil {
            focusFirst()
        }
    }

    /// Deactivate navigation (hides focus ring).
    func deactivateNavigation() {
        isNavigationActive = false
    }

    /// Navigate in direction. Returns true if moved or activated, false if stayed.
    ///
    /// - Parameter direction: The direction to navigate (left/right/up/down)
    /// - Returns: `true` if navigation was handled (even if we stayed in place)
    @discardableResult
    func navigate(_ direction: NavigationDirection) -> Bool {
        // First activation just shows focus ring
        if !isNavigationActive {
            activateNavigation()
            return true
        }

        guard let target = findTarget(in: direction) else {
            // No valid target in that direction - stay on current
            return true
        }

        focusedId = target.id
        return true
    }

    /// Focus the first target (topmost, then leftmost).
    func focusFirst() {
        guard !targets.isEmpty else { return }

        // Sort by Y (top), then X (left)
        let sorted = targets.values.sorted { a, b in
            if abs(a.center.y - b.center.y) < 1 {
                return a.center.x < b.center.x
            }
            return a.center.y < b.center.y
        }

        focusedId = sorted.first?.id
        if !isNavigationActive {
            isNavigationActive = true
        }
    }

    /// Focus the last target (bottommost, then rightmost).
    func focusLast() {
        guard !targets.isEmpty else { return }

        // Sort by Y (bottom), then X (right)
        let sorted = targets.values.sorted { a, b in
            if abs(a.center.y - b.center.y) < 1 {
                return a.center.x > b.center.x
            }
            return a.center.y > b.center.y
        }

        focusedId = sorted.first?.id
        if !isNavigationActive {
            isNavigationActive = true
        }
    }

    /// Focus on a specific item by looking up its ID.
    /// Activates navigation if not already active.
    func focusOn(_ item: DetailFocusableItem) {
        guard targets[item.id] != nil else { return }
        focusedId = item.id
        if !isNavigationActive {
            isNavigationActive = true
        }
    }

    // MARK: - Target Finding

    /// Find the best target in the given direction from current focus.
    /// Returns nil if no valid target exists.
    private func findTarget(in direction: NavigationDirection) -> NavigationTarget? {
        guard let current = focusedTarget else {
            return nil
        }

        let candidates = targets.values.filter { target in
            guard target.id != current.id else { return false }
            return isValid(target, from: current, direction: direction)
        }

        guard !candidates.isEmpty else { return nil }

        return selectBest(from: Array(candidates), current: current, direction: direction)
    }

    /// Check if target is in valid direction from current using STRICT inequality.
    private func isValid(
        _ target: NavigationTarget,
        from current: NavigationTarget,
        direction: NavigationDirection
    ) -> Bool {
        switch direction {
        case .left:
            target.center.x < current.center.x
        case .right:
            target.center.x > current.center.x
        case .up:
            target.center.y < current.center.y
        case .down:
            target.center.y > current.center.y
        }
    }

    /// Select the best candidate from valid targets.
    ///
    /// Uses axis-aligned priority with distance as tiebreaker:
    /// 1. Prefer targets aligned on perpendicular axis (within tolerance)
    /// 2. Among aligned targets, prefer the closest one on movement axis
    private func selectBest(
        from candidates: [NavigationTarget],
        current: NavigationTarget,
        direction: NavigationDirection
    ) -> NavigationTarget {
        let sorted = candidates.sorted { a, b in
            let alignmentA = perpendicularDistance(from: current, to: a, direction: direction)
            let alignmentB = perpendicularDistance(from: current, to: b, direction: direction)

            // If similarly aligned (within tolerance), prefer closer on movement axis
            if abs(alignmentA - alignmentB) < Self.alignmentTolerance {
                return movementDistance(from: current, to: a, direction: direction)
                    < movementDistance(from: current, to: b, direction: direction)
            }

            // Otherwise prefer better aligned (smaller perpendicular distance)
            return alignmentA < alignmentB
        }

        // Safe to force unwrap - we know candidates is non-empty
        return sorted.first!
    }

    /// Distance on perpendicular axis (for alignment scoring).
    ///
    /// For horizontal movement (left/right), returns vertical distance.
    /// For vertical movement (up/down), returns horizontal distance.
    private func perpendicularDistance(
        from: NavigationTarget,
        to: NavigationTarget,
        direction: NavigationDirection
    ) -> CGFloat {
        switch direction {
        case .left, .right:
            abs(to.center.y - from.center.y)
        case .up, .down:
            abs(to.center.x - from.center.x)
        }
    }

    /// Distance on movement axis.
    private func movementDistance(
        from: NavigationTarget,
        to: NavigationTarget,
        direction: NavigationDirection
    ) -> CGFloat {
        switch direction {
        case .left, .right:
            abs(to.center.x - from.center.x)
        case .up, .down:
            abs(to.center.y - from.center.y)
        }
    }
}
