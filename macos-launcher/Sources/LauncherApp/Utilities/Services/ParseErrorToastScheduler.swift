import Foundation

@MainActor
final class ParseErrorToastScheduler {
    private let delay: TimeInterval
    private let shouldDefer: () -> Bool
    private let isRequestCurrent: (Int) -> Bool
    private let showToast: (String) -> Void

    private var pendingToastTask: Task<Void, Never>?
    private var pendingMessage: String?
    private var pendingRequestId: Int?

    init(
        delay: TimeInterval,
        shouldDefer: @escaping () -> Bool,
        isRequestCurrent: @escaping (Int) -> Bool,
        showToast: @escaping (String) -> Void
    ) {
        self.delay = delay
        self.shouldDefer = shouldDefer
        self.isRequestCurrent = isRequestCurrent
        self.showToast = showToast
    }

    func cancel() {
        pendingToastTask?.cancel()
        pendingToastTask = nil
        pendingMessage = nil
        pendingRequestId = nil
    }

    func schedule(message: String, requestId: Int) {
        pendingToastTask?.cancel()
        pendingMessage = message
        pendingRequestId = requestId

        if shouldDefer() {
            return
        }

        pendingToastTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(delay))
            guard let pendingRequestId,
                  pendingRequestId == requestId else { return }
            guard isRequestCurrent(requestId) else { return }
            guard let pendingMessage else { return }
            pendingToastTask = nil
            self.pendingMessage = nil
            self.pendingRequestId = nil
            showToast(pendingMessage)
        }
    }

    func scheduleAfterMenuClose() {
        guard !shouldDefer() else { return }
        guard let pendingMessage, let pendingRequestId else { return }
        schedule(message: pendingMessage, requestId: pendingRequestId)
    }
}
