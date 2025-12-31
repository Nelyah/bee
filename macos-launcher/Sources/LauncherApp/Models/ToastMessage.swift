import Foundation

/// A transient toast notification message.
struct ToastMessage: Identifiable, Equatable {
    let id: UUID
    let message: String
    let createdAt: Date
    let icon: ToastIcon

    init(
        id: UUID = UUID(),
        message: String,
        icon: ToastIcon = .warning,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.message = message
        self.icon = icon
        self.createdAt = createdAt
    }
}

enum ToastIcon: Equatable {
    case success
    case warning
    case gitlab
}
