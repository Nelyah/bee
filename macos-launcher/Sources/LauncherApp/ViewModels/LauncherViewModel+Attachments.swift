import AppKit
import Foundation
import QuickLookUI

extension LauncherViewModel {
    // MARK: - Attachment State

    /// ID of attachment currently showing delete confirmation
    var confirmingDeleteAttachmentId: Int? {
        get { _confirmingDeleteAttachmentId }
        set { _confirmingDeleteAttachmentId = newValue }
    }

    // MARK: - File Picker

    /// Opens a file picker and uploads the selected file as an attachment.
    @MainActor
    func addAttachment() {
        guard let detail = taskDetailState.detail else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select a file to attach"
        panel.prompt = "Attach"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await self?.uploadAttachment(url, taskUUID: detail.uuid)
            }
        }
    }

    /// Uploads a file from a URL to the current task.
    @MainActor
    func uploadAttachment(_ fileURL: URL, taskUUID: String) async {
        do {
            let attachment = try await apiClient.uploadAttachment(taskUUID: taskUUID, fileURL: fileURL)
            // Refresh task detail to show the new attachment
            loadTaskDetail(taskUUID: taskUUID)
            showToast(message: "Attached \(attachment.filename)", icon: .success)
        } catch {
            showToast(message: "Failed to upload: \(error.localizedDescription)", icon: .warning)
        }
    }

    /// Handles drag-and-drop of files onto the attachments section.
    @MainActor
    func handleAttachmentDrop(_ urls: [URL]) {
        guard let detail = taskDetailState.detail, let firstURL = urls.first else { return }
        Task {
            await uploadAttachment(firstURL, taskUUID: detail.uuid)
        }
    }

    // MARK: - Open Attachment

    /// Downloads and opens an attachment in the default application.
    @MainActor
    func openAttachment(_ attachment: TaskAttachmentDto) {
        Task {
            do {
                let data = try await apiClient.downloadAttachment(attachmentId: attachment.id)
                let tempURL = try saveToTempFile(data: data, filename: attachment.filename)
                NSWorkspace.shared.open(tempURL)
            } catch {
                showToast(message: "Failed to open: \(error.localizedDescription)", icon: .warning)
            }
        }
    }

    /// Downloads and shows Quick Look preview for an attachment.
    @MainActor
    func quickLookAttachment(_ attachment: TaskAttachmentDto) {
        Task {
            do {
                let data = try await apiClient.downloadAttachment(attachmentId: attachment.id)
                let tempURL = try saveToTempFile(data: data, filename: attachment.filename)
                _quickLookURL = tempURL
                showQuickLookPanel()
            } catch {
                showToast(message: "Failed to preview: \(error.localizedDescription)", icon: .warning)
            }
        }
    }

    /// Saves data to a temporary file and returns the URL.
    private func saveToTempFile(data: Data, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }

    /// Shows the Quick Look panel for the current preview URL.
    private func showQuickLookPanel() {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Delete Attachment

    /// Starts the delete confirmation flow for an attachment.
    @MainActor
    func startDeleteAttachment(_ attachment: TaskAttachmentDto) {
        _confirmingDeleteAttachmentId = attachment.id
    }

    /// Confirms deletion of an attachment.
    @MainActor
    func confirmDeleteAttachment(_ attachment: TaskAttachmentDto) async {
        guard let detail = taskDetailState.detail else { return }

        do {
            try await apiClient.deleteAttachment(attachmentId: attachment.id)
            _confirmingDeleteAttachmentId = nil
            // Refresh task detail to remove the deleted attachment
            loadTaskDetail(taskUUID: detail.uuid)
            showToast(message: "Deleted \(attachment.filename)", icon: .success)
        } catch {
            showToast(message: "Failed to delete: \(error.localizedDescription)", icon: .warning)
            _confirmingDeleteAttachmentId = nil
        }
    }

    /// Cancels the delete confirmation flow.
    @MainActor
    func cancelDeleteAttachment() {
        _confirmingDeleteAttachmentId = nil
    }

    // MARK: - Keyboard Actions

    /// Handles keyboard actions for the currently focused attachment.
    @MainActor
    func handleAttachmentKeyAction(_ action: AttachmentKeyAction) {
        guard case let .attachment(attachment) = focusedDetailItem else { return }

        switch action {
        case .open:
            openAttachment(attachment)
        case .quickLook:
            quickLookAttachment(attachment)
        case .copyFilename:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(attachment.filename, forType: .string)
            showToast(message: "Copied filename", icon: .success)
        case .delete:
            if _confirmingDeleteAttachmentId == attachment.id {
                // Already confirming, treat as confirm
                Task { await confirmDeleteAttachment(attachment) }
            } else {
                startDeleteAttachment(attachment)
            }
        case .confirmDelete:
            Task { await confirmDeleteAttachment(attachment) }
        case .cancelDelete:
            cancelDeleteAttachment()
        }
    }
}

/// Actions that can be performed on an attachment via keyboard.
enum AttachmentKeyAction {
    case open
    case quickLook
    case copyFilename
    case delete
    case confirmDelete
    case cancelDelete
}
