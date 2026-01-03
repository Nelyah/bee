import AppKit

// MARK: - Tag Editing Methods

extension LauncherViewModel {
    /// All available tags for autocomplete.
    var allTagCompletions: [CompletionItem] {
        var items = completion.tagItems.filter { !$0.value.isEmpty }

        // Deduplicate by value while preserving order.
        var seen = Set<String>()
        items = items.filter { seen.insert($0.value).inserted }

        return items
    }

    /// Start editing a specific tag at the given index.
    /// This will remove the old tag and start adding mode with the tag name pre-filled.
    func startEditingTag(at index: Int) {
        guard let task = selectedTask, index < task.tags.count else { return }
        let oldTag = task.tags[index]

        // Remove the old tag first
        removeTag(oldTag)

        // Start adding mode with the old tag name pre-filled for editing
        tagAddQuery = oldTag
        isAddingTag = true
        selectedTagIndex = nil
    }

    /// Set the selected tag index for keyboard navigation.
    func selectTagIndex(_ index: Int?) {
        selectedTagIndex = index
    }

    /// Begin adding a new tag (shows the CompletionField).
    func startAddingTag() {
        tagAddQuery = ""
        isAddingTag = true
        // Clear tag selection when adding
        selectedTagIndex = nil
    }

    /// Cancel adding a tag (hides the CompletionField).
    func cancelAddingTag() {
        isAddingTag = false
        tagAddQuery = ""
    }

    /// Add a tag to the current task.
    func addTag(_ tagName: String) {
        guard let task = selectedTask else { return }
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelAddingTag()
            return
        }

        // Don't add if already exists
        guard !task.tags.contains(trimmed) else {
            cancelAddingTag()
            return
        }

        isSubmittingTag = true

        Task {
            defer {
                isSubmittingTag = false
            }

            do {
                let properties: JSONValue = .object([
                    "tags_add": .array([.string(trimmed)]),
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

                // Success - clear state and update
                isAddingTag = false
                tagAddQuery = ""
                showToast(message: "Tag added: \(trimmed)", icon: .success)

                // Update the task in the local list
                if let idx = tasks.firstIndex(where: { $0.uuid == task.uuid }) {
                    var newTags = task.tags
                    newTags.append(trimmed)
                    tasks[idx] = ApiTask(
                        dbId: task.dbId,
                        uuid: task.uuid,
                        status: task.status,
                        summary: task.summary,
                        project: task.project,
                        tags: newTags,
                        dateCreated: task.dateCreated,
                        dateCompleted: task.dateCompleted,
                        dateDue: task.dateDue,
                        urgency: task.urgency
                    )
                }

                // Rebuild focusable items to include the new tag
                buildDetailFocusableItems()

                // Refresh the detail view
                loadTaskDetail(taskUUID: task.uuid)
            } catch {
                showToast(message: "Failed to add tag", icon: .warning)
            }
        }
    }

    /// Remove a tag from the current task.
    func removeTag(_ tagName: String) {
        guard let task = selectedTask else { return }

        // Verify tag exists
        guard task.tags.contains(tagName) else { return }

        isSubmittingTag = true

        Task {
            defer {
                isSubmittingTag = false
            }

            do {
                let properties: JSONValue = .object([
                    "tags_remove": .array([.string(tagName)]),
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

                // Success - update local state
                showToast(message: "Tag removed: \(tagName)", icon: .success)

                // Update the task in the local list
                if let idx = tasks.firstIndex(where: { $0.uuid == task.uuid }) {
                    var newTags = task.tags
                    newTags.removeAll { $0 == tagName }
                    tasks[idx] = ApiTask(
                        dbId: task.dbId,
                        uuid: task.uuid,
                        status: task.status,
                        summary: task.summary,
                        project: task.project,
                        tags: newTags,
                        dateCreated: task.dateCreated,
                        dateCompleted: task.dateCompleted,
                        dateDue: task.dateDue,
                        urgency: task.urgency
                    )
                }

                // Adjust selection if needed
                if let currentIndex = selectedTagIndex {
                    let newCount = task.tags.count - 1
                    if newCount == 0 {
                        selectedTagIndex = nil
                    } else if currentIndex >= newCount {
                        selectedTagIndex = newCount - 1
                    }
                }

                // Rebuild focusable items after removing the tag
                buildDetailFocusableItems()

                // Refresh the detail view
                loadTaskDetail(taskUUID: task.uuid)
            } catch {
                showToast(message: "Failed to remove tag", icon: .warning)
            }
        }
    }

    /// Select a tag from the autocomplete list and add it immediately.
    func selectTagFromCompletion(_ item: CompletionItem) {
        // Use Task with @MainActor to properly defer state changes
        Task { @MainActor in
            addTag(item.value)
        }
    }
}
