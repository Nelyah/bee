import Foundation

/// Serializes async work so only one operation runs at a time.
actor SerialTaskQueue {
    private var lastTask: Task<Void, Never> = Task {}

    func run<T>(_ operation: @Sendable @escaping () async throws -> T) async throws -> T {
        let previous = lastTask
        let current = Task<T, Error> {
            await previous.value
            return try await operation()
        }
        lastTask = Task { _ = await current.result }
        return try await current.value
    }
}
