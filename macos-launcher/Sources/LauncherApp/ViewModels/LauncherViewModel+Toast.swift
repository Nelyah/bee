import AppKit
import Foundation
import SwiftUI

// MARK: - Toast & Notifications

extension LauncherViewModel {
    private enum ToastConstants {
        static let defaultToastDuration: TimeInterval = 10
        static let toastAnimationDuration: TimeInterval = 0.2
    }

    /// Present a toast message that auto-dismisses after a duration.
    @discardableResult
    func showToast(
        message: String,
        icon: ToastIcon = .warning,
        duration: TimeInterval = ToastConstants.defaultToastDuration
    ) -> UUID {
        let toast = ToastMessage(message: message, icon: icon)
        withAnimation(.easeInOut(duration: ToastConstants.toastAnimationDuration)) {
            toasts.append(toast)
        }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                withAnimation(.easeInOut(duration: ToastConstants.toastAnimationDuration)) {
                    toasts.removeAll { $0.id == toast.id }
                }
            }
        }
        return toast.id
    }

    func removeToast(id: UUID) {
        withAnimation(.easeInOut(duration: ToastConstants.toastAnimationDuration)) {
            toasts.removeAll { $0.id == id }
        }
    }

    func copyBranchNameToClipboard(_ branch: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(branch, forType: .string)
        showToast(message: "Branch copied", icon: .success)
    }

    func copyLinkToClipboard(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        showToast(message: "Link copied", icon: .success)
    }

    func copyUUIDToClipboard(_ uuid: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(uuid, forType: .string)
        showToast(message: "UUID copied", icon: .success)
    }
}
