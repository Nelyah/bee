import SwiftUI
import UniformTypeIdentifiers

/// Displays file attachments for a task with keyboard navigation and actions.
///
/// Features:
/// - Compact list layout for keyboard-first navigation
/// - MIME-type icons, filename, size display
/// - Inline delete confirmation ("Delete? y/n")
/// - Add button + "a" keyboard shortcut
///
/// Note: Drag-and-drop is handled at the TaskDetailView level for the entire view.
struct AttachmentsSection: View {
    let attachments: [TaskAttachmentDto]
    let focusedItem: DetailFocusableItem?
    let confirmingDeleteId: Int?
    let onAdd: () -> Void
    let onSelect: (TaskAttachmentDto) -> Void
    let onOpen: (TaskAttachmentDto) -> Void
    let onDelete: (TaskAttachmentDto) -> Void
    let onConfirmDelete: (TaskAttachmentDto) -> Void
    let onCancelDelete: () -> Void

    var body: some View {
        DetailSectionWithAction(
            title: "Attachments",
            actionLabel: "Add",
            actionIcon: "plus",
            onAction: onAdd
        ) {
            if attachments.isEmpty {
                emptyState
            } else {
                attachmentsList
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text("No attachments")
                .font(.system(size: DesignTokens.TypeScale.bodySm))
                .foregroundColor(ThemeManager.current.subtext0)
            Text("Press 'a' to add or drag files anywhere")
                .font(.system(size: DesignTokens.TypeScale.caption))
                .foregroundColor(ThemeManager.current.subtext1)
        }
        .padding(.vertical, DesignTokens.Spacing.small)
        .modifier(DetailFocusRing(isFocused: isAddButtonFocused))
    }

    @ViewBuilder
    private var attachmentsList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            ForEach(attachments) { attachment in
                AttachmentRow(
                    attachment: attachment,
                    isFocused: isAttachmentFocused(attachment),
                    isConfirmingDelete: confirmingDeleteId == attachment.id,
                    onSelect: { onSelect(attachment) },
                    onOpen: { onOpen(attachment) },
                    onDelete: { onDelete(attachment) },
                    onConfirmDelete: { onConfirmDelete(attachment) },
                    onCancelDelete: onCancelDelete
                )
                .navigationRegistrable(.attachment(attachment))
            }

            // Add button row (focusable via keyboard)
            addButtonRow
                .navigationRegistrable(.addAttachmentButton)
        }
    }

    @ViewBuilder
    private var addButtonRow: some View {
        Button(action: onAdd) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ThemeManager.current.subtext0)
                Text("Add attachment")
                    .font(.system(size: DesignTokens.TypeScale.bodySm))
                    .foregroundColor(ThemeManager.current.subtext0)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .modifier(DetailFocusRing(isFocused: isAddButtonFocused))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Focus Helpers

    private func isAttachmentFocused(_ attachment: TaskAttachmentDto) -> Bool {
        if case let .attachment(focusedAttachment) = focusedItem {
            return focusedAttachment.id == attachment.id
        }
        return false
    }

    private var isAddButtonFocused: Bool {
        if case .addAttachmentButton = focusedItem {
            return true
        }
        return false
    }
}

/// Displays a single attachment with icon, filename, size, and actions.
struct AttachmentRow: View {
    let attachment: TaskAttachmentDto
    let isFocused: Bool
    let isConfirmingDelete: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onConfirmDelete: () -> Void
    let onCancelDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            // MIME type icon
            Image(systemName: attachment.iconName)
                .font(.system(size: 14))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 20)

            // Filename
            Text(attachment.filename)
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                .foregroundColor(ThemeManager.current.text)
                .lineLimit(1)
                .truncationMode(.middle)

            // File size
            Text(attachment.formattedSize)
                .font(.system(size: DesignTokens.TypeScale.caption))
                .foregroundColor(ThemeManager.current.subtext1)

            Spacer()

            // Delete button or confirmation
            if isConfirmingDelete {
                deleteConfirmation
            } else if isHovering || isFocused {
                deleteButton
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.small)
        .padding(.vertical, DesignTokens.Spacing.extraSmall)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering ? ThemeManager.current.surface1.opacity(0.5) : Color.clear)
        )
        .contentShape(Rectangle())
        .onReliableHover { isHovering = $0 }
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onOpen() }
        .modifier(DetailFocusRing(isFocused: isFocused))
        .help(isFocused ? "Enter: Open • Space: Quick Look • y: Copy filename • x: Delete" : "Double-click to open")
    }

    @ViewBuilder
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(ThemeManager.current.subtext0)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var deleteConfirmation: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            Text("Delete?")
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                .foregroundColor(ThemeManager.current.red)

            Button("y") { onConfirmDelete() }
                .buttonStyle(.plain)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .bold))
                .foregroundColor(ThemeManager.current.red)

            Text("/")
                .font(.system(size: DesignTokens.TypeScale.caption))
                .foregroundColor(ThemeManager.current.subtext0)

            Button("n") { onCancelDelete() }
                .buttonStyle(.plain)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .bold))
                .foregroundColor(ThemeManager.current.subtext0)
        }
    }
}

// MARK: - Previews

#Preview("With Attachments") {
    let attachments = [
        TaskAttachmentDto(
            id: 1,
            uuid: "attach-001",
            filename: "design-spec.pdf",
            mimeType: "application/pdf",
            sizeBytes: 245_760,
            createdAt: "2024-01-17T14:30:00Z"
        ),
        TaskAttachmentDto(
            id: 2,
            uuid: "attach-002",
            filename: "screenshot.png",
            mimeType: "image/png",
            sizeBytes: 1_048_576,
            createdAt: "2024-01-18T10:00:00Z"
        ),
        TaskAttachmentDto(
            id: 3,
            uuid: "attach-003",
            filename: "very-long-filename-that-should-be-truncated.docx",
            mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            sizeBytes: 52428,
            createdAt: "2024-01-19T08:15:00Z"
        ),
    ]

    return AttachmentsSection(
        attachments: attachments,
        focusedItem: .attachment(attachments[0]),
        confirmingDeleteId: nil,
        onAdd: {},
        onSelect: { _ in },
        onOpen: { _ in },
        onDelete: { _ in },
        onConfirmDelete: { _ in },
        onCancelDelete: {}
    )
    .padding()
    .frame(width: 400)
    .background(ThemeManager.current.base)
}

#Preview("Empty State") {
    AttachmentsSection(
        attachments: [],
        focusedItem: .addAttachmentButton,
        confirmingDeleteId: nil,
        onAdd: {},
        onSelect: { _ in },
        onOpen: { _ in },
        onDelete: { _ in },
        onConfirmDelete: { _ in },
        onCancelDelete: {}
    )
    .padding()
    .frame(width: 400)
    .background(ThemeManager.current.base)
}

#Preview("Delete Confirmation") {
    let attachment = TaskAttachmentDto(
        id: 1,
        uuid: "attach-001",
        filename: "design-spec.pdf",
        mimeType: "application/pdf",
        sizeBytes: 245_760,
        createdAt: "2024-01-17T14:30:00Z"
    )

    return AttachmentsSection(
        attachments: [attachment],
        focusedItem: .attachment(attachment),
        confirmingDeleteId: 1,
        onAdd: {},
        onSelect: { _ in },
        onOpen: { _ in },
        onDelete: { _ in },
        onConfirmDelete: { _ in },
        onCancelDelete: {}
    )
    .padding()
    .frame(width: 400)
    .background(ThemeManager.current.base)
}
