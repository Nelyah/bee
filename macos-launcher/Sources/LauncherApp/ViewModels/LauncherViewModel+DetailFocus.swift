import AppKit
import Foundation

// MARK: - Detail Focus Navigation

extension LauncherViewModel {
    /// Builds the list of focusable items for the current detail view.
    /// Order: Task Name → UUID → Project → Tags → Add Tag → Due Date → Attachments → Add Attachment → Annotations →
    /// Linked Tasks → GitLab MRs → Jira Issues
    func buildDetailFocusableItems() {
        var items: [DetailFocusableItem] = []

        if let task = selectedTask {
            // 1. Task name is first (at the top of the detail view)
            items.append(.taskName(task.summary))

            // 2. UUID (first row in Overview section)
            items.append(.uuid(task.uuid))

            // 3. Project (second row in Overview section)
            items.append(.project(task.project ?? ""))

            // 4. Tags (after project, before external links)
            for (index, tag) in task.tags.enumerated() {
                items.append(.tag(tag, index: index))
            }

            // 5. Add tag button (after tags, before due date)
            // Only include when not currently adding a tag
            if !isAddingTag {
                items.append(.addTagButton)
            }

            // 6. Due date (in the Dates section)
            items.append(.dueDate(task.dateDue))
        }

        // 7. Attachments (from task detail)
        if let detail = taskDetailState.detail {
            for attachment in detail.attachments {
                items.append(.attachment(attachment))
            }
            // Add attachment button is always available after attachments
            items.append(.addAttachmentButton)

            // 8. Annotations (from task detail)
            for annotation in detail.annotations {
                items.append(.annotation(annotation))
            }
        }

        // 9. Linked tasks (from task detail)
        if let detail = taskDetailState.detail {
            for link in detail.links {
                items.append(.linkedTask(link))
            }
        }

        // 10. GitLab MRs
        let gitlabLinks = externalLinksState.links.filter {
            $0.provider.lowercased() == ExternalLinkProvider.gitlab.rawValue
        }
        for link in gitlabLinks {
            items.append(.gitlabMR(link))
        }

        // 11. Jira issues
        let jiraLinks = externalLinksState.links.filter {
            $0.provider.lowercased() == ExternalLinkProvider.jira.rawValue
        }
        for link in jiraLinks {
            items.append(.jiraIssue(link))
        }

        detailFocusableItems = items
    }

    /// The currently focused item in detail view.
    /// Returns nil if keyboard navigation is not active (focus ring is lazy).
    var focusedDetailItem: DetailFocusableItem? {
        // Uses the new coordinate-based navigation registry
        navigationRegistry.focusedItem
    }

    /// Clears the current focus in detail view.
    /// Call this when user clicks outside of a focused item.
    func clearDetailFocus() {
        navigationRegistry.deactivateNavigation()
    }

    /// Handle a detail mode keyboard action.
    @discardableResult
    func handleDetailModeAction(_ action: DetailModeAction) -> Bool {
        switch action {
        case let .navigate(direction):
            // Use coordinate-based navigation
            return navigationRegistry.navigate(direction)
        case .openFocused:
            return openFocusedDetailItem()
        case .copyFocused:
            return copyFocusedDetailItem()
        case .selectFirst:
            navigationRegistry.focusFirst()
            return true
        case .selectLast:
            navigationRegistry.focusLast()
            return true
        case .addAnnotation:
            startAddingAnnotation()
            return true
        case .deleteFocused:
            return deleteFocusedDetailItem()
        case .addTag:
            startAddingTag()
            return true
        case .quickLookFocused:
            return quickLookFocusedDetailItem()
        case .cancelDelete:
            return cancelFocusedAttachmentDelete()
        }
    }

    func openFocusedDetailItem() -> Bool {
        guard let item = focusedDetailItem else { return false }

        // Task name: Enter triggers editing instead of opening URL
        if case .taskName = item {
            startEditingTaskName()
            return true
        }

        // Project: Enter triggers editing instead of opening URL
        if case .project = item {
            startEditingProject()
            return true
        }

        // Tag: Enter triggers editing that tag
        if case let .tag(_, index) = item {
            startEditingTag(at: index)
            return true
        }

        // Add tag button: Enter starts adding a new tag
        if case .addTagButton = item {
            startAddingTag()
            return true
        }

        // Due date: Enter triggers editing
        if case .dueDate = item {
            startEditingDueDate()
            return true
        }

        // Linked task: navigate to the target task
        if case let .linkedTask(link) = item {
            navigateToTask(uuid: link.targetUuid)
            return true
        }

        // Attachment: download and open in default app
        if case let .attachment(attachment) = item {
            openAttachment(attachment)
            return true
        }

        // Add attachment button: open file picker
        if case .addAttachmentButton = item {
            addAttachment()
            return true
        }

        // Annotation: Enter triggers editing
        if case let .annotation(annotation) = item {
            startEditingAnnotation(withId: annotation.id)
            return true
        }

        // Links: open URL in browser
        guard let url = item.openURL else { return false }
        NSWorkspace.shared.open(url)
        return true
    }

    /// Navigate to a linked task by UUID.
    /// Pushes the task detail onto the navigation stack for back navigation.
    func navigateToTask(uuid: String) {
        guard tasks.contains(where: { $0.uuid == uuid }) else {
            showToast(message: "Task not in current view", icon: .warning)
            return
        }
        pushTaskDetail(uuid: uuid)
    }

    func copyFocusedDetailItem() -> Bool {
        guard let item = focusedDetailItem else { return false }

        // Special case: y on an attachment in confirming mode confirms delete
        if case let .attachment(attachment) = item,
           _confirmingDeleteAttachmentId == attachment.id {
            handleAttachmentKeyAction(.confirmDelete)
            return true
        }

        let value = item.copyValue
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)

        // Show toast with appropriate label
        showToast(message: "\(item.copyLabel) copied", icon: .success)
        return true
    }

    func deleteFocusedDetailItem() -> Bool {
        guard let item = focusedDetailItem else { return false }

        // Tags can be deleted with x
        if case let .tag(tagName, _) = item {
            removeTag(tagName)
            return true
        }

        // Attachments can be deleted with x (triggers confirmation flow)
        if case .attachment = item {
            handleAttachmentKeyAction(.delete)
            return true
        }

        return false
    }

    func quickLookFocusedDetailItem() -> Bool {
        guard let item = focusedDetailItem else { return false }

        // Only attachments support Quick Look
        if case let .attachment(attachment) = item {
            quickLookAttachment(attachment)
            return true
        }

        return false
    }

    func cancelFocusedAttachmentDelete() -> Bool {
        guard let item = focusedDetailItem else { return false }

        // n cancels deletion when focused on an attachment that's confirming
        if case let .attachment(attachment) = item,
           _confirmingDeleteAttachmentId == attachment.id {
            handleAttachmentKeyAction(.cancelDelete)
            return true
        }

        // n does nothing if not confirming
        return false
    }
}
