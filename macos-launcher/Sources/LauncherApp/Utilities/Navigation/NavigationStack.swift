import Combine
import Foundation

/// Manages navigation history as a stack.
/// The root entry (taskList) is always at the bottom and cannot be popped.
/// Named ViewNavigationStack to avoid conflict with SwiftUI's NavigationStack.
final class ViewNavigationStack: ObservableObject {
    /// Maximum stack depth to prevent memory issues
    static let maxDepth = 20

    /// The navigation entries. First element is always taskList (root).
    @Published private(set) var entries: [NavigationEntry] = [.taskList]

    /// The current (topmost) entry
    var current: NavigationEntry {
        entries.last ?? .taskList
    }

    /// Current mode derived from the top entry
    var currentMode: LauncherMode {
        current.mode
    }

    /// Whether we can navigate back (more than just root)
    var canGoBack: Bool {
        entries.count > 1
    }

    /// The number of entries (for debugging/display)
    var depth: Int {
        entries.count
    }

    /// Push a new entry onto the stack
    /// - Parameter entry: The entry to push
    func push(_ entry: NavigationEntry) {
        // Don't push duplicate consecutive entries
        if entries.last == entry {
            return
        }

        entries.append(entry)

        // Enforce max depth by removing oldest non-root entries
        while entries.count > Self.maxDepth {
            entries.remove(at: 1) // Keep root at index 0
        }
    }

    /// Pop the top entry and return it
    /// - Returns: The popped entry, or nil if at root
    @discardableResult
    func pop() -> NavigationEntry? {
        guard canGoBack else { return nil }
        return entries.removeLast()
    }

    /// Pop entries until reaching a specific condition
    /// - Parameter predicate: Return true to stop popping
    /// - Returns: The final entry after popping
    @discardableResult
    func popUntil(_ predicate: (NavigationEntry) -> Bool) -> NavigationEntry {
        while canGoBack, !predicate(current) {
            entries.removeLast()
        }
        return current
    }

    /// Reset to root (taskList only)
    func reset() {
        entries = [.taskList]
    }

    /// Remove entries referencing a specific task UUID.
    /// Call this when a task is deleted or no longer accessible.
    func removeEntriesForTask(uuid: String) {
        entries.removeAll { entry in
            entry.isDetailFor(uuid: uuid)
        }

        // Ensure at least root remains
        if entries.isEmpty {
            entries = [.taskList]
        }
    }
}
