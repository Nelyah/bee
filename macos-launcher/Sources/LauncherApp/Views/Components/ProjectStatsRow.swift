import SwiftUI

/// A row displaying a project with its statistics and actions.
struct ProjectStatsRow: View {
    let node: ProjectNode
    let isExpanded: Bool
    let indentLevel: Int
    let onToggleExpand: () -> Void
    let onSelect: () -> Void
    let onShowBurndown: () -> Void
    let onUpdateEmoji: (String?) -> Void
    let onUpdateColor: (String?) -> Void

    @State private var isHovered = false
    @State private var isEditingEmoji = false
    @State private var showColorPicker = false
    @State private var selectedColor: Color

    private let indentWidth: CGFloat = 20

    init(
        node: ProjectNode,
        isExpanded: Bool,
        indentLevel: Int,
        onToggleExpand: @escaping () -> Void,
        onSelect: @escaping () -> Void,
        onShowBurndown: @escaping () -> Void,
        onUpdateEmoji: @escaping (String?) -> Void = { _ in },
        onUpdateColor: @escaping (String?) -> Void = { _ in }
    ) {
        self.node = node
        self.isExpanded = isExpanded
        self.indentLevel = indentLevel
        self.onToggleExpand = onToggleExpand
        self.onSelect = onSelect
        self.onShowBurndown = onShowBurndown
        self.onUpdateEmoji = onUpdateEmoji
        self.onUpdateColor = onUpdateColor

        // Initialize color from hex string or default
        if let hex = node.color {
            _selectedColor = State(initialValue: Color(hex: hex))
        } else {
            _selectedColor = State(initialValue: ThemeManager.current.subtext0)
        }
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            // Indentation
            if indentLevel > 0 {
                HStack(spacing: 0) {
                    ForEach(0 ..< indentLevel, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: indentWidth)
                    }
                }
            }

            // Expand/collapse chevron (if has children)
            if node.hasChildren {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: DesignTokens.IconSize.small))
                        .foregroundColor(ThemeManager.current.subtext0)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            } else {
                // Spacer for alignment
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 16, height: 16)
            }

            // Emoji button (shows emoji or placeholder)
            emojiButton

            // Project name with optional color tint
            projectNameText

            Spacer()

            // Color picker (visible on hover or if color is set)
            colorPickerButton

            // Stats pills
            HStack(spacing: DesignTokens.Spacing.extraSmall) {
                if node.stats.pendingCount > 0 {
                    StatsPill(count: node.stats.pendingCount, color: ThemeManager.current.peach)
                }
                if node.stats.activeCount > 0 {
                    StatsPill(count: node.stats.activeCount, color: ThemeManager.current.blue)
                }
                if node.stats.completedCount > 0 {
                    StatsPill(count: node.stats.completedCount, color: ThemeManager.current.green)
                }
                if node.stats.overdueCount > 0 {
                    StatsPill(count: node.stats.overdueCount, color: ThemeManager.current.red)
                }
            }

            // Burndown chart button
            Button(action: onShowBurndown) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: DesignTokens.IconSize.small))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .fill(isHovered ? ThemeManager.current.surface1 : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovered = hovering
        }
        .background(
            // Hidden text field to receive emoji input
            EmojiInputField(
                isActive: $isEditingEmoji,
                onEmojiSelected: { emoji in
                    onUpdateEmoji(emoji)
                    isEditingEmoji = false
                }
            )
            .frame(width: 0, height: 0)
            .opacity(0)
        )
    }

    // MARK: - Emoji Button

    @ViewBuilder
    private var emojiButton: some View {
        Button(action: openEmojiPicker) {
            if let emoji = node.emoji {
                Text(emoji)
                    .font(.system(size: DesignTokens.TypeScale.body))
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: DesignTokens.IconSize.small))
                    .foregroundColor(ThemeManager.current.subtext0)
            }
        }
        .buttonStyle(.plain)
        .opacity(node.emoji != nil || isHovered ? 1 : 0.3)
        .frame(width: 24, height: 24)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered && node.emoji == nil ? ThemeManager.current.surface2.opacity(0.5) : Color.clear)
        )
        .contextMenu {
            if node.emoji != nil {
                Button("Clear Emoji", role: .destructive) {
                    onUpdateEmoji(nil)
                }
            }
        }
    }

    private func openEmojiPicker() {
        isEditingEmoji = true
        // Delay to allow the hidden field to become first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.orderFrontCharacterPalette(nil)
        }
    }

    // MARK: - Project Name

    @ViewBuilder
    private var projectNameText: some View {
        let textColor: Color = if let hex = node.color {
            Color(hex: hex)
        } else {
            ThemeManager.current.text
        }

        Text(node.name)
            .font(.system(size: DesignTokens.TypeScale.body))
            .foregroundColor(textColor)
            .lineLimit(1)
    }

    // MARK: - Color Picker

    @ViewBuilder
    private var colorPickerButton: some View {
        ColorPicker("", selection: $selectedColor, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 24, height: 24)
            .opacity(node.color != nil || isHovered ? 1 : 0.3)
            .onChange(of: selectedColor) { _, newColor in
                if let hex = newColor.hexString {
                    onUpdateColor(hex)
                }
            }
            .contextMenu {
                if node.color != nil {
                    Button("Clear Color", role: .destructive) {
                        selectedColor = ThemeManager.current.subtext0
                        onUpdateColor(nil)
                    }
                }
            }
    }
}

// MARK: - Emoji Input Field

/// A hidden text field that captures emoji input from the Character Palette.
struct EmojiInputField: NSViewRepresentable {
    @Binding var isActive: Bool
    let onEmojiSelected: (String) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBezeled = false
        textField.isEditable = true
        textField.stringValue = ""
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if isActive {
            nsView.stringValue = ""
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: EmojiInputField

        init(parent: EmojiInputField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let text = textField.stringValue

            // Check if the input contains an emoji
            if !text.isEmpty, text.unicodeScalars.first?.properties.isEmoji == true {
                // Extract just the first emoji
                let emoji = String(text.unicodeScalars
                    .prefix(while: { $0.properties.isEmoji || $0.properties.isEmojiPresentation }))
                if !emoji.isEmpty {
                    parent.onEmojiSelected(emoji)
                    textField.stringValue = ""
                }
            }
        }
    }
}

/// A small colored pill showing a count.
struct StatsPill: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, DesignTokens.Spacing.extraSmall)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        ProjectStatsRow(
            node: ProjectNode(
                name: "backend",
                fullPath: "backend",
                emoji: "🔧",
                color: "#4A90D9",
                stats: ProjectStats(
                    name: "backend",
                    pendingCount: 5,
                    activeCount: 3,
                    completedCount: 12,
                    overdueCount: 1,
                    totalCount: 20,
                    emoji: "🔧",
                    color: "#4A90D9"
                ),
                children: []
            ),
            isExpanded: false,
            indentLevel: 0,
            onToggleExpand: {},
            onSelect: {},
            onShowBurndown: {}
        )

        ProjectStatsRow(
            node: ProjectNode(
                name: "api",
                fullPath: "backend.api",
                emoji: nil,
                color: nil,
                stats: ProjectStats(
                    name: "api",
                    pendingCount: 2,
                    activeCount: 1,
                    completedCount: 5,
                    overdueCount: 0,
                    totalCount: 8,
                    emoji: nil,
                    color: nil
                ),
                children: []
            ),
            isExpanded: false,
            indentLevel: 1,
            onToggleExpand: {},
            onSelect: {},
            onShowBurndown: {}
        )
    }
    .padding()
    .background(ThemeManager.current.surface0)
    .frame(width: 400)
}
