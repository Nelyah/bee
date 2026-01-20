import SwiftUI

/// Displays important links for a task with add/remove functionality.
///
/// Features:
/// - Compact list layout showing title and URL
/// - Click to open URL in default browser
/// - Remove button on hover
/// - Add link form with URL and optional title
struct ImportantLinksSection: View {
    let importantLinks: [ImportantLinkDto]
    let focusedItem: DetailFocusableItem?
    let onOpen: (ImportantLinkDto) -> Void
    let onRemove: (ImportantLinkDto) -> Void
    let onStartAdding: () -> Void
    var isAdding: Bool
    @Binding var urlInput: String
    @Binding var titleInput: String
    var isSubmitting: Bool
    var onSubmit: () -> Void
    var onCancelAdding: () -> Void

    @FocusState private var isUrlFieldFocused: Bool

    // MARK: - Focus Helpers

    private func isLinkFocused(_ link: ImportantLinkDto) -> Bool {
        if case let .importantLink(focusedLink) = focusedItem {
            return focusedLink.id == link.id
        }
        return false
    }

    private var isAddButtonFocused: Bool {
        if case .addImportantLinkButton = focusedItem {
            return true
        }
        return false
    }

    var body: some View {
        DetailSection(title: "Important Links") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                // Existing links
                ForEach(importantLinks) { link in
                    ImportantLinkRow(
                        link: link,
                        isFocused: isLinkFocused(link),
                        onOpen: { onOpen(link) },
                        onRemove: { onRemove(link) },
                        isSubmitting: isSubmitting
                    )
                    .navigationRegistrable(.importantLink(link))
                }

                // Add link form or button
                if isAdding {
                    addLinkForm
                } else {
                    addLinkButton
                }
            }
        }
    }

    /// Form for entering a new important link.
    private var addLinkForm: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            // URL field (required)
            HStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundColor(ThemeManager.current.subtext0)
                    .frame(width: 20)

                TextField("URL", text: $urlInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: DesignTokens.TypeScale.bodySm))
                    .foregroundColor(ThemeManager.current.text)
                    .focused($isUrlFieldFocused)
                    .onAppear {
                        // Auto-focus URL field when form appears
                        isUrlFieldFocused = true
                    }
                    .onSubmit {
                        if !urlInput.isEmpty {
                            onSubmit()
                        }
                    }
            }
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeManager.current.surface0)
            )

            // Title field (optional)
            HStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14))
                    .foregroundColor(ThemeManager.current.subtext0)
                    .frame(width: 20)

                TextField("Title (optional)", text: $titleInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: DesignTokens.TypeScale.bodySm))
                    .foregroundColor(ThemeManager.current.text)
                    .onSubmit {
                        if !urlInput.isEmpty {
                            onSubmit()
                        }
                    }
            }
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeManager.current.surface0)
            )

            // Action buttons
            HStack(spacing: DesignTokens.Spacing.small) {
                Button(action: onCancelAdding) {
                    Text("Cancel")
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        .foregroundColor(ThemeManager.current.subtext1)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onSubmit) {
                    HStack(spacing: 4) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        }
                        Text(isSubmitting ? "Adding..." : "Add Link")
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                    }
                    .foregroundColor(urlInput.isEmpty ? ThemeManager.current.subtext0 : ThemeManager.current.green)
                }
                .buttonStyle(.plain)
                .disabled(urlInput.isEmpty || isSubmitting)
            }
            .padding(.top, DesignTokens.Spacing.extraSmall)
        }
    }

    /// Button to start adding a new link.
    private var addLinkButton: some View {
        Button(action: onStartAdding) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundColor(ThemeManager.current.subtext0)
                    .frame(width: 20)

                Text("Add link")
                    .font(.system(size: DesignTokens.TypeScale.bodySm))
                    .foregroundColor(ThemeManager.current.subtext0)

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .modifier(DetailFocusRing(isFocused: isAddButtonFocused))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .navigationRegistrable(.addImportantLinkButton)
    }
}

/// Displays a single important link with icon, title, URL, and remove button.
struct ImportantLinkRow: View {
    let link: ImportantLinkDto
    var isFocused: Bool = false
    let onOpen: () -> Void
    let onRemove: () -> Void
    var isSubmitting: Bool = false

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            // Main button (opens link)
            Button(action: onOpen) {
                HStack(spacing: DesignTokens.Spacing.small) {
                    // Link icon
                    Image(systemName: "link")
                        .font(.system(size: 14))
                        .foregroundColor(ThemeManager.current.green)
                        .frame(width: 20)

                    // Title and URL
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.title)
                            .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                            .foregroundColor(ThemeManager.current.text)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(link.url)
                            .font(.system(size: DesignTokens.TypeScale.caption))
                            .foregroundColor(ThemeManager.current.subtext1)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Remove button (visible on hover)
            if isHovering, !isSubmitting {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ThemeManager.current.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Remove link")
            } else if isHovering {
                // Open indicator when hovering but not showing remove
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
        .modifier(DetailFocusRing(isFocused: isFocused))
        .contentShape(Rectangle())
        .onReliableHover { isHovering = $0 }
        .help("Click to open in browser")
    }
}

// MARK: - Previews

#Preview("With Important Links") {
    struct PreviewWrapper: View {
        @State private var urlInput = ""
        @State private var titleInput = ""

        var body: some View {
            let links = [
                ImportantLinkDto(
                    id: 1,
                    uuid: "link-001",
                    url: "https://github.com/example/project/issues/123",
                    title: "GitHub Issue #123",
                    createdAt: "2024-01-17T15:00:00Z"
                ),
                ImportantLinkDto(
                    id: 2,
                    uuid: "link-002",
                    url: "https://docs.example.com/api/reference",
                    title: "API Documentation",
                    createdAt: "2024-01-18T10:00:00Z"
                ),
            ]

            ImportantLinksSection(
                importantLinks: links,
                focusedItem: nil,
                onOpen: { _ in },
                onRemove: { _ in },
                onStartAdding: {},
                isAdding: false,
                urlInput: $urlInput,
                titleInput: $titleInput,
                isSubmitting: false,
                onSubmit: {},
                onCancelAdding: {}
            )
            .padding()
            .frame(width: 400)
            .background(ThemeManager.current.base)
        }
    }
    return PreviewWrapper()
}

#Preview("Adding Link") {
    struct PreviewWrapper: View {
        @State private var urlInput = "https://example.com"
        @State private var titleInput = "Example"

        var body: some View {
            ImportantLinksSection(
                importantLinks: [],
                focusedItem: nil,
                onOpen: { _ in },
                onRemove: { _ in },
                onStartAdding: {},
                isAdding: true,
                urlInput: $urlInput,
                titleInput: $titleInput,
                isSubmitting: false,
                onSubmit: {},
                onCancelAdding: {}
            )
            .padding()
            .frame(width: 400)
            .background(ThemeManager.current.base)
        }
    }
    return PreviewWrapper()
}

#Preview("Empty State") {
    struct PreviewWrapper: View {
        @State private var urlInput = ""
        @State private var titleInput = ""

        var body: some View {
            ImportantLinksSection(
                importantLinks: [],
                focusedItem: nil,
                onOpen: { _ in },
                onRemove: { _ in },
                onStartAdding: {},
                isAdding: false,
                urlInput: $urlInput,
                titleInput: $titleInput,
                isSubmitting: false,
                onSubmit: {},
                onCancelAdding: {}
            )
            .padding()
            .frame(width: 400)
            .background(ThemeManager.current.base)
        }
    }
    return PreviewWrapper()
}
