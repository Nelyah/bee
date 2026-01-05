import SwiftUI

/// Displays email links for a task with click-to-open functionality.
///
/// Features:
/// - Compact list layout showing subject and sender
/// - Click to open email in Mail.app via message:// URL
/// - SF Symbol icon for emails
struct EmailLinksSection: View {
    let emailLinks: [EmailLinkDto]
    let onOpen: (EmailLinkDto) -> Void

    var body: some View {
        if !emailLinks.isEmpty {
            DetailSection(title: "Linked Emails") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    ForEach(emailLinks) { link in
                        EmailLinkRow(link: link, onOpen: { onOpen(link) })
                    }
                }
            }
        }
    }
}

/// Displays a single email link with icon, subject, and sender.
struct EmailLinkRow: View {
    let link: EmailLinkDto
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: DesignTokens.Spacing.small) {
                // Email icon
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ThemeManager.current.blue)
                    .frame(width: 20)

                // Subject and sender
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.subject)
                        .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                        .foregroundColor(ThemeManager.current.text)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(link.sender)
                        .font(.system(size: DesignTokens.TypeScale.caption))
                        .foregroundColor(ThemeManager.current.subtext1)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                // Open indicator on hover
                if isHovering {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundColor(ThemeManager.current.subtext0)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? ThemeManager.current.surface1.opacity(0.5) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onReliableHover { isHovering = $0 }
        .help("Click to open in Mail.app")
    }
}

// MARK: - Previews

#Preview("With Email Links") {
    let links = [
        EmailLinkDto(
            id: 1,
            uuid: "link-001",
            messageId: "<test123@example.com>",
            subject: "Meeting notes from yesterday's standup",
            sender: "alice@example.com",
            sentDate: "2024-01-17T14:30:00Z",
            createdAt: "2024-01-17T15:00:00Z",
            mailUrl: "message://%3ctest123%40example.com%3e"
        ),
        EmailLinkDto(
            id: 2,
            uuid: "link-002",
            messageId: "<reply456@example.com>",
            subject: "Re: Project deadline",
            sender: "Bob Smith <bob@example.com>",
            sentDate: nil,
            createdAt: "2024-01-18T10:00:00Z",
            mailUrl: "message://%3creply456%40example.com%3e"
        ),
    ]

    return EmailLinksSection(
        emailLinks: links,
        onOpen: { _ in }
    )
    .padding()
    .frame(width: 400)
    .background(ThemeManager.current.base)
}

#Preview("Empty State") {
    EmailLinksSection(
        emailLinks: [],
        onOpen: { _ in }
    )
    .padding()
    .frame(width: 400)
    .background(ThemeManager.current.base)
}
