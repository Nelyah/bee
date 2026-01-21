import Foundation

// MARK: - Important Links Methods

extension LauncherViewModel {
    /// Begin adding a new important link (shows the URL input form).
    func startAddingImportantLink() {
        importantLinkUrlInput = ""
        importantLinkTitleInput = ""
        detailEditingState = .addingImportantLink
    }

    /// Cancel adding an important link (hides the form).
    func cancelAddingImportantLink() {
        detailEditingState = .none
        importantLinkUrlInput = ""
        importantLinkTitleInput = ""
    }

    /// Submit the new important link to the API.
    func submitImportantLink() async {
        guard let task = selectedTask else { return }
        let url = importantLinkUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = importantLinkTitleInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // URL is required
        guard !url.isEmpty else {
            cancelAddingImportantLink()
            return
        }

        isSubmittingImportantLink = true
        defer {
            isSubmittingImportantLink = false
        }

        do {
            // Build the important_link_add property object
            var linkObject: [String: JSONValue] = ["url": .string(url)]
            if !title.isEmpty {
                linkObject["title"] = .string(title)
            }

            let properties: JSONValue = .object([
                "important_link_add": .object(linkObject),
            ])
            let filter: JSONValue = .object([
                "type": .string("UuidFilter"),
                "value": .object(["uuid": .string(task.uuid)]),
            ])

            _ = try await apiClient.runAction(
                action: "modify",
                properties: properties,
                filter: filter
            )

            // Success - clear state and reload detail
            detailEditingState = .none
            importantLinkUrlInput = ""
            importantLinkTitleInput = ""
            showToast(message: "Link added", icon: .success)

            // Refresh the detail view to show the new link
            loadTaskDetail(taskUUID: task.uuid)
        } catch {
            showToast(message: "Failed to add link", icon: .warning)
        }
    }

    /// Remove an important link from the current task.
    func removeImportantLink(_ link: ImportantLinkDto) async {
        guard let task = selectedTask else { return }

        isSubmittingImportantLink = true
        defer {
            isSubmittingImportantLink = false
        }

        do {
            let properties: JSONValue = .object([
                "important_link_remove": .object([
                    "url": .string(link.url),
                ]),
            ])
            let filter: JSONValue = .object([
                "type": .string("UuidFilter"),
                "value": .object(["uuid": .string(task.uuid)]),
            ])

            _ = try await apiClient.runAction(
                action: "modify",
                properties: properties,
                filter: filter
            )

            // Success - reload detail
            showToast(message: "Link removed", icon: .success)

            // Refresh the detail view
            loadTaskDetail(taskUUID: task.uuid)
        } catch {
            showToast(message: "Failed to remove link", icon: .warning)
        }
    }
}
