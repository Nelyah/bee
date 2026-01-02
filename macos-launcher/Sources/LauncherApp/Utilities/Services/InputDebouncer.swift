import Foundation

/// Debounces input changes to prevent excessive API calls during typing.
///
/// The debouncer delays action execution by a configurable amount, canceling
/// any pending action when a new one is scheduled. This prevents API calls
/// on every keystroke while maintaining responsiveness.
@MainActor
final class InputDebouncer {
    private let delay: TimeInterval
    private var pendingTask: Task<Void, Never>?
    private var currentRequestId: Int = 0

    /// Initialize with a delay in seconds.
    /// - Parameter delay: Time to wait after the last input before executing. Default 50ms.
    init(delay: TimeInterval = 0.05) {
        self.delay = delay
    }

    /// Schedule a debounced action.
    ///
    /// If called again before the delay expires, the previous action is canceled
    /// and the timer resets. Only the last action in a rapid sequence will execute.
    ///
    /// - Parameters:
    ///   - requestId: Identifier to validate the action is still current when it fires.
    ///   - action: The async action to execute after the debounce delay.
    func debounce(requestId: Int, action: @escaping () async -> Void) {
        pendingTask?.cancel()
        currentRequestId = requestId

        pendingTask = Task { [weak self, requestId] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, currentRequestId == requestId else { return }
            await action()
        }
    }

    /// Cancel any pending debounced action.
    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
