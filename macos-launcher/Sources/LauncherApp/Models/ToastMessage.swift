import Foundation

/// A transient toast notification message.
struct ToastMessage: Identifiable, Equatable {
    let id: UUID
    let message: String
    let createdAt: Date

    init(id: UUID = UUID(), message: String, createdAt: Date = Date()) {
        self.id = id
        self.message = message
        self.createdAt = createdAt
    }
}
