import AppKit
import Foundation

extension LauncherViewModel {
    // MARK: - Email Link Handling

    /// Handles an email dropped from Apple Mail onto the task detail.
    ///
    /// This method is called by `FilePromiseDropNSView` when an EML file
    /// or Mail pasteboard data is dropped onto the attachments section.
    ///
    /// The email is linked to the current task via the `/v1/action` modify endpoint
    /// with `email_link_add` properties.
    @MainActor
    func handleEmailDrop(_ email: ParsedEmail) {
        guard let detail = taskDetailState.detail else {
            showToast(message: "No task selected", icon: .warning)
            return
        }

        Task {
            await addEmailLink(email, taskUUID: detail.uuid)
        }
    }

    /// Links an email to a task via the modify action API.
    @MainActor
    func addEmailLink(_ email: ParsedEmail, taskUUID: String) async {
        do {
            // Build email_link_add properties to match Rust's EmailLinkInput struct
            var emailLinkAdd: [String: JSONValue] = [
                "message_id": .string(email.messageId),
                "subject": .string(email.subject),
                "sender": .string(email.sender),
            ]

            // Add sent_date if available (as ISO 8601 string)
            if let sentDate = email.sentDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                emailLinkAdd["sent_date"] = .string(formatter.string(from: sentDate))
            }

            let properties: JSONValue = .object([
                "email_link_add": .object(emailLinkAdd),
            ])

            // Build filter for this specific task
            let filter: JSONValue = .object([
                "type": .string("UuidFilter"),
                "value": .object(["uuid": .string(taskUUID)]),
            ])

            _ = try await apiClient.runAction(
                action: "modify",
                properties: properties,
                filter: filter
            )

            // Success - show toast and reload detail
            showToast(message: "Linked: \(email.subject)", icon: .success)

            // Refresh to show the new email link
            loadTaskDetail(taskUUID: taskUUID)
        } catch {
            print("[EmailLinks] Failed to add email link: \(error)")
            showToast(message: "Failed to link email", icon: .warning)
        }
    }

    // MARK: - Email Link Actions

    /// Opens an email link in Mail.app using a pre-formatted mail URL.
    ///
    /// The `mailUrl` is provided by the API and includes proper URL encoding
    /// of the Message-ID with angle brackets (e.g., `message://%3cID%3e`).
    @MainActor
    func openEmailLinkUrl(_ mailUrl: String) {
        guard let url = URL(string: mailUrl) else {
            showToast(message: "Invalid email link", icon: .warning)
            return
        }

        NSWorkspace.shared.open(url)
    }

    /// Opens an email link in Mail.app using the message:// URL scheme.
    ///
    /// Use this when you only have the raw Message-ID (not the pre-formatted URL).
    @MainActor
    func openEmailLink(messageId: String) {
        // The message:// URL scheme expects URL-encoded angle brackets around the ID
        let bareId = messageId
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))

        // URL-encode the message ID and wrap in encoded angle brackets
        guard let encodedId = bareId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            showToast(message: "Invalid message ID", icon: .warning)
            return
        }

        guard let url = URL(string: "message://%3C\(encodedId)%3E") else {
            showToast(message: "Invalid message ID", icon: .warning)
            return
        }

        NSWorkspace.shared.open(url)
    }
}
