import AppKit
import Foundation

// MARK: - Detail Focus Navigation

extension LauncherViewModel {
    /// Builds the list of focusable items for the current detail view.
    /// Order: Task Name → UUID → Project → Tags → Add Tag → Due Date → Attachments → Add Attachment → Linked Tasks →
    /// GitLab MRs → Jira Issues
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
        }

        // 8. Linked tasks (from task detail)
        if let detail = taskDetailState.detail {
            for link in detail.links {
                items.append(.linkedTask(link))
            }
        }

        // 9. GitLab MRs
        let gitlabLinks = externalLinksState.links.filter {
            $0.provider.lowercased() == ExternalLinkProvider.gitlab.rawValue
        }
        for link in gitlabLinks {
            items.append(.gitlabMR(link))
        }

        // 10. Jira issues
        let jiraLinks = externalLinksState.links.filter {
            $0.provider.lowercased() == ExternalLinkProvider.jira.rawValue
        }
        for link in jiraLinks {
            items.append(.jiraIssue(link))
        }

        detailFocusableItems = items

        // Keep focus within bounds
        if detailFocusedIndex >= items.count {
            detailFocusedIndex = max(0, items.count - 1)
        }
    }

    /// The currently focused item in detail view.
    /// Returns nil if keyboard navigation is not active (focus ring is lazy).
    var focusedDetailItem: DetailFocusableItem? {
        // Focus ring only shows after user engages with hjkl navigation
        guard detailKeyboardNavigationActive else {
            return nil
        }
        guard detailFocusedIndex >= 0, detailFocusedIndex < detailFocusableItems.count else {
            return nil
        }
        return detailFocusableItems[detailFocusedIndex]
    }

    /// Index of the first external link in the focusable items list.
    /// Returns the count if no external links are present.
    private var firstExternalLinkIndex: Int {
        detailFocusableItems.firstIndex {
            if case .gitlabMR = $0 { return true }
            if case .jiraIssue = $0 { return true }
            return false
        } ?? detailFocusableItems.count
    }

    /// Handle a detail mode keyboard action.
    @discardableResult
    func handleDetailModeAction(_ action: DetailModeAction) -> Bool {
        // Track if navigation was just activated (for navigation actions only)
        let wasInactive = !detailKeyboardNavigationActive
        let isNavigationAction: Bool

        // Activate keyboard navigation on any navigation action
        switch action {
        case .moveFocus, .moveFocusLeft, .moveFocusRight, .selectFirst, .selectLast:
            detailKeyboardNavigationActive = true
            isNavigationAction = true
        default:
            isNavigationAction = false
        }

        // On first activation of navigation, just show focus at current index (don't move)
        // This ensures the first press of j/k shows focus ring without moving
        if wasInactive, isNavigationAction {
            return true
        }

        switch action {
        case let .moveFocus(delta):
            moveDetailFocus(delta: delta)
            return true
        case .moveFocusLeft:
            return handleMoveFocusLeft()
        case .moveFocusRight:
            return handleMoveFocusRight()
        case .openFocused:
            return openFocusedDetailItem()
        case .copyFocused:
            return copyFocusedDetailItem()
        case .selectFirst:
            detailFocusedIndex = 0
            return true
        case .selectLast:
            detailFocusedIndex = max(0, detailFocusableItems.count - 1)
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

    private func moveDetailFocus(delta: Int) {
        guard !detailFocusableItems.isEmpty else { return }
        let newIndex = detailFocusedIndex + delta
        detailFocusedIndex = max(0, min(newIndex, detailFocusableItems.count - 1))
    }

    /// Handle h key: navigate left within tags, or switch from links column to metadata column.
    private func handleMoveFocusLeft() -> Bool {
        // When on a tag or add button, h navigates to previous item (like k)
        if let item = focusedDetailItem {
            if case .tag = item {
                moveDetailFocus(delta: -1)
                return true
            }
            if case .addTagButton = item {
                moveDetailFocus(delta: -1)
                return true
            }
        }
        // If on right column (links), move to first metadata item
        if detailFocusedIndex >= firstExternalLinkIndex {
            detailFocusedIndex = 0
        }
        return true
    }

    /// Handle l key: navigate right within tags, or switch from metadata column to links column.
    private func handleMoveFocusRight() -> Bool {
        // When on a tag, l navigates to next item (like j)
        if let item = focusedDetailItem {
            if case .tag = item {
                moveDetailFocus(delta: 1)
                return true
            }
            if case .addTagButton = item {
                // From add button, l moves to external links (if any)
                if detailFocusableItems.count > firstExternalLinkIndex {
                    detailFocusedIndex = firstExternalLinkIndex
                }
                return true
            }
        }
        // If on left column (metadata + tags), move to first link if available
        if detailFocusedIndex < firstExternalLinkIndex {
            if detailFocusableItems.count > firstExternalLinkIndex {
                detailFocusedIndex = firstExternalLinkIndex
            }
            return true
        }
        // Already in right column (links) - open the focused item
        return openFocusedDetailItem()
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

        // Links: open URL in browser
        guard let url = item.openURL else { return false }
        NSWorkspace.shared.open(url)
        return true
    }

    /// Navigate to a linked task by UUID.
    func navigateToTask(uuid: String) {
        guard let index = tasks.firstIndex(where: { $0.uuid == uuid }) else {
            showToast(message: "Task not in current view", icon: .warning)
            return
        }
        selectedIndex = index
        loadTaskDetail(taskUUID: uuid)
        loadExternalLinks(taskUUID: uuid)
        buildDetailFocusableItems()
        detailFocusedIndex = 0 // Reset focus to top
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
