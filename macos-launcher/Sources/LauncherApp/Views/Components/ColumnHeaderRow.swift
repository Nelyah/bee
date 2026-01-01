import AppKit
import SwiftUI

// MARK: - Layout Constants

private enum ColumnHeaderLayout {
    static let spacing: CGFloat = DesignTokens.Spacing.medium
    static let statusIndicatorWidth: CGFloat = DesignTokens.IconSize.statusIndicator
    static let fontSize: CGFloat = DesignTokens.TypeScale.label
    static let letterSpacing: CGFloat = 1.5
    static let horizontalPadding: CGFloat = DesignTokens.Spacing.medium
    static let sortArrowSize: CGFloat = 9
    static let sortArrowPadding: CGFloat = 2
    static let hoverCornerRadius: CGFloat = DesignTokens.Radius.small
    static let hoverPadding: CGFloat = DesignTokens.Spacing.extraSmall
    static let resizeHandleWidth: CGFloat = 14
    static let resizeHandleHeight: CGFloat = 16
    static let resizeHandleHitboxHeight: CGFloat = 44
    static let resizeHandleVisibleWidth: CGFloat = 2
}

// MARK: - Column Header Row

/// A row of clickable column headers with sort indicators and resize handles.
/// Supports drag-and-drop reordering of columns.
struct ColumnHeaderRow: View {
    let columnConfigs: [ColumnConfig]
    let sortState: ColumnSortState?
    let onSort: (String) -> Void
    var onResize: ((String, CGFloat) -> Void)?
    var onResizeEnd: ((String) -> Void)?
    var onReorder: ((String, Int) -> Void)?

    @State private var draggedColumn: String?
    @State private var dropTargetIndex: Int?

    var body: some View {
        HStack(spacing: ColumnHeaderLayout.spacing) {
            // Status indicator column (fixed width, non-clickable)
            Text("")
                .frame(width: ColumnHeaderLayout.statusIndicatorWidth)

            ForEach(Array(columnConfigs.enumerated()), id: \.element.id) { index, config in
                DraggableColumnHeader(
                    config: config,
                    index: index,
                    totalCount: columnConfigs.count,
                    sortDirection: sortDirection(for: config.key),
                    showResizeHandle: !config.isFlex && index < columnConfigs.count - 1,
                    isDragging: draggedColumn == config.key,
                    isDropTarget: dropTargetIndex == index,
                    onTap: { onSort(config.key) },
                    onResize: { delta in
                        onResize?(config.key, delta)
                    },
                    onResizeEnd: {
                        onResizeEnd?(config.key)
                    },
                    onDragStarted: {
                        draggedColumn = config.key
                    },
                    onDragEnded: {
                        draggedColumn = nil
                        dropTargetIndex = nil
                    },
                    onDropTargeted: { targeted in
                        dropTargetIndex = targeted ? index : nil
                    },
                    onDrop: { fromKey in
                        guard fromKey != config.key else { return }
                        onReorder?(fromKey, index)
                        draggedColumn = nil
                        dropTargetIndex = nil
                    }
                )
                .frame(
                    minWidth: config.isFlex ? nil : config.effectiveWidth,
                    maxWidth: config.isFlex ? .infinity : config.effectiveWidth,
                    alignment: .leading
                )
            }
        }
        .font(.system(size: ColumnHeaderLayout.fontSize, weight: .bold, design: .rounded))
        .foregroundColor(ThemeManager.current.subtext1)
        .tracking(ColumnHeaderLayout.letterSpacing)
        .padding(.horizontal, ColumnHeaderLayout.horizontalPadding)
        .padding(.bottom, DesignTokens.Spacing.small)
    }

    private func sortDirection(for column: String) -> ColumnSortDirection? {
        guard let state = sortState, state.column == column else {
            return nil
        }
        return state.direction
    }
}

// MARK: - Draggable Column Header

/// A column header that can be dragged to reorder columns.
private struct DraggableColumnHeader: View {
    let config: ColumnConfig
    let index: Int
    let totalCount: Int
    let sortDirection: ColumnSortDirection?
    let showResizeHandle: Bool
    let isDragging: Bool
    let isDropTarget: Bool
    let onTap: () -> Void
    let onResize: (CGFloat) -> Void
    var onResizeEnd: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onDropTargeted: ((Bool) -> Void)?
    var onDrop: ((String) -> Void)?

    var body: some View {
        ResizableColumnHeader(
            config: config,
            sortDirection: sortDirection,
            showResizeHandle: showResizeHandle,
            onTap: onTap,
            onResize: onResize,
            onResizeEnd: onResizeEnd
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .overlay(alignment: .leading) {
            // Drop indicator line on the left edge
            if isDropTarget {
                Rectangle()
                    .fill(ThemeManager.current.blue)
                    .frame(width: 2)
                    .transition(.opacity)
            }
        }
        .draggable(config.key) {
            // Drag preview - a simple label
            Text(config.displayName.uppercased())
                .font(.system(size: ColumnHeaderLayout.fontSize, weight: .bold, design: .rounded))
                .foregroundColor(ThemeManager.current.text)
                .padding(.horizontal, DesignTokens.Spacing.small)
                .padding(.vertical, DesignTokens.Spacing.extraSmall)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(ThemeManager.current.surface1)
                )
                .onAppear {
                    onDragStarted?()
                }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let droppedKey = items.first else { return false }
            onDrop?(droppedKey)
            return true
        } isTargeted: { targeted in
            onDropTargeted?(targeted)
        }
        .onDisappear {
            // Clean up if view disappears during drag
            if isDragging {
                onDragEnded?()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
    }
}

// MARK: - Resizable Column Header

/// A column header with an optional resize handle on the right edge.
private struct ResizableColumnHeader: View {
    let config: ColumnConfig
    let sortDirection: ColumnSortDirection?
    let showResizeHandle: Bool
    let onTap: () -> Void
    let onResize: (CGFloat) -> Void
    var onResizeEnd: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            ColumnHeader(
                config: config,
                sortDirection: sortDirection,
                onTap: onTap
            )

            if showResizeHandle {
                Spacer(minLength: 0)
                ResizeHandle(onResize: onResize, onResizeEnd: onResizeEnd)
            }
        }
    }
}

// MARK: - Individual Column Header

/// A single clickable column header with optional sort indicator.
struct ColumnHeader: View {
    let config: ColumnConfig
    let sortDirection: ColumnSortDirection?
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ColumnHeaderLayout.sortArrowPadding) {
                Text(config.displayName.uppercased())
                    .lineLimit(1)

                if let direction = sortDirection {
                    Image(systemName: direction == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: ColumnHeaderLayout.sortArrowSize, weight: .semibold))
                        .foregroundColor(ThemeManager.current.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, ColumnHeaderLayout.hoverPadding)
            .padding(.horizontal, ColumnHeaderLayout.hoverPadding)
            .background(
                RoundedRectangle(cornerRadius: ColumnHeaderLayout.hoverCornerRadius)
                    .fill(isHovered ? ThemeManager.current.surfaceHover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeOut(duration: 0.15), value: sortDirection)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Resize Handle

/// A draggable handle for resizing columns.
///
/// Uses a custom NSView wrapper to prevent window dragging when
/// `isMovableByWindowBackground` is enabled on the window.
private struct ResizeHandle: View {
    let onResize: (CGFloat) -> Void
    var onResizeEnd: (() -> Void)?

    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        // Wrap in NonDraggableArea to prevent window drag from capturing our gesture
        NonDraggableArea {
            Rectangle()
                .fill(handleColor)
                .frame(width: ColumnHeaderLayout.resizeHandleVisibleWidth)
                .frame(height: ColumnHeaderLayout.resizeHandleHeight)
                .padding(
                    .horizontal,
                    (ColumnHeaderLayout.resizeHandleWidth - ColumnHeaderLayout.resizeHandleVisibleWidth) / 2
                )
        }
        .frame(width: ColumnHeaderLayout.resizeHandleWidth, height: ColumnHeaderLayout.resizeHandleHitboxHeight)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            updateCursor()
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        updateCursor()
                    }
                    // Disable all animations during resize for maximum responsiveness
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        onResize(value.translation.width)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    onResizeEnd?()
                    updateCursor()
                }
        )
        // Only animate visual color changes, not during active drag
        .animation(isDragging ? nil : .easeInOut(duration: 0.1), value: isHovered)
    }

    /// Updates the cursor based on current hover/drag state.
    /// Uses `set()` instead of push/pop to avoid stack imbalance issues.
    private func updateCursor() {
        if isHovered || isDragging {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private var handleColor: Color {
        if isDragging {
            ThemeManager.current.blue
        } else if isHovered {
            ThemeManager.current.blue.opacity(0.7)
        } else {
            ThemeManager.current.surface1
        }
    }
}

// MARK: - Non-Draggable Area

/// An NSViewRepresentable that prevents window dragging within its bounds.
///
/// When a window has `isMovableByWindowBackground = true`, the entire window
/// becomes draggable. This wrapper creates an NSView subclass that overrides
/// `mouseDownCanMoveWindow` to return `false`, allowing drag gestures to work
/// on child views without triggering window movement.
private struct NonDraggableArea<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NonDraggableNSView {
        let view = NonDraggableNSView()
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        return view
    }

    func updateNSView(_ nsView: NonDraggableNSView, context: Context) {
        // Update the hosted content if needed
        if let hostingView = nsView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

/// Custom NSView that prevents window dragging within its bounds.
private class NonDraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

// MARK: - Previews

#Preview("Default State") {
    let configs = [
        ColumnConfig(key: "id", displayName: "ID", width: nil),
        ColumnConfig(key: "summary", displayName: "Summary", width: nil),
        ColumnConfig(key: "status", displayName: "Status", width: nil),
        ColumnConfig(key: "urgency", displayName: "Urgency", width: nil),
    ]

    return ColumnHeaderRow(
        columnConfigs: configs,
        sortState: nil,
        onSort: { _ in },
        onResize: { _, _ in }
    )
    .padding()
    .background(ThemeManager.current.base)
}

#Preview("With Sort Ascending") {
    let configs = [
        ColumnConfig(key: "id", displayName: "ID", width: nil),
        ColumnConfig(key: "summary", displayName: "Summary", width: nil),
        ColumnConfig(key: "status", displayName: "Status", width: nil),
        ColumnConfig(key: "urgency", displayName: "Urgency", width: nil),
    ]

    return ColumnHeaderRow(
        columnConfigs: configs,
        sortState: .ascending("status"),
        onSort: { _ in },
        onResize: { _, _ in }
    )
    .padding()
    .background(ThemeManager.current.base)
}

#Preview("With Sort Descending") {
    let configs = [
        ColumnConfig(key: "id", displayName: "ID", width: nil),
        ColumnConfig(key: "summary", displayName: "Summary", width: nil),
        ColumnConfig(key: "status", displayName: "Status", width: nil),
        ColumnConfig(key: "urgency", displayName: "Urgency", width: nil),
    ]

    return ColumnHeaderRow(
        columnConfigs: configs,
        sortState: .descending("urgency"),
        onSort: { _ in },
        onResize: { _, _ in }
    )
    .padding()
    .background(ThemeManager.current.base)
}
