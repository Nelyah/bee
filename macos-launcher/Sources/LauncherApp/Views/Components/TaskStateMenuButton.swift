import AppKit
import SwiftUI

/// A clickable status badge that shows a dropdown menu for task state changes.
/// Used in TaskDetailView header, triggered by mouse click or Cmd+P.
struct TaskStateMenuButton: View {
    let currentStatus: String
    let onSelect: (TaskStateAction) -> Void
    /// Optional trigger provider for programmatic menu display (Cmd+P).
    var triggerProvider: MenuTriggerProvider?

    @State private var isHovering = false
    @State private var flash = false

    var body: some View {
        TaskStateMenuButtonRepresentable(
            currentStatus: currentStatus,
            onSelect: onSelect,
            triggerProvider: triggerProvider
        ) {
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                flash = false
            }
        }
        .fixedSize()
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.extraSmall)
        .opacity(flash ? 0.6 : 1.0)
        .animation(.easeOut(duration: 0.12), value: flash)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .fill(statusColor(currentStatus).opacity(isHovering ? 0.95 : 0.85))
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help("Click to change task state")
        .accessibilityIdentifier("taskStateMenuButton")
        .accessibilityLabel("Status: \(currentStatus)")
    }
}

private struct TaskStateBadgeView: View {
    let status: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            Text(status.uppercased())
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                .foregroundColor(ThemeManager.current.crust)
            Image(systemName: "chevron.down")
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
                .foregroundColor(ThemeManager.current.crust.opacity(0.7))
        }
    }
}

private struct TaskStateMenuButtonRepresentable: NSViewRepresentable {
    let currentStatus: String
    let onSelect: (TaskStateAction) -> Void
    let triggerProvider: MenuTriggerProvider?
    let onPress: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TaskStateMenuButtonView {
        let view = TaskStateMenuButtonView(onSelect: onSelect, onPress: onPress)
        context.coordinator.buttonView = view
        view.update(currentStatus: currentStatus)
        // Set up the trigger provider to call showMenu
        triggerProvider?.trigger = { [weak view] in
            view?.showMenu()
        }
        return view
    }

    func updateNSView(_ nsView: TaskStateMenuButtonView, context: Context) {
        nsView.onSelect = onSelect
        nsView.onPress = onPress
        nsView.update(currentStatus: currentStatus)
        // Update trigger provider reference
        triggerProvider?.trigger = { [weak nsView] in
            nsView?.showMenu()
        }
    }

    class Coordinator {
        var buttonView: TaskStateMenuButtonView?
    }
}

/// AppKit-backed menu view for task state changes.
final class TaskStateMenuButtonView: NSView {
    private var hostingView: NSHostingView<TaskStateBadgeView>?
    var onPress: (() -> Void)?
    var onSelect: ((TaskStateAction) -> Void)?
    private var currentStatus: String = ""

    init(onSelect: @escaping (TaskStateAction) -> Void, onPress: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onPress = onPress
        super.init(frame: .zero)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        hostingView?.fittingSize ?? super.intrinsicContentSize
    }

    func update(currentStatus: String) {
        self.currentStatus = currentStatus

        if let hostingView {
            hostingView.rootView = TaskStateBadgeView(status: currentStatus)
        } else {
            let hostingView = NSHostingView(rootView: TaskStateBadgeView(status: currentStatus))
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            self.hostingView = hostingView
        }
        invalidateIntrinsicContentSize()

        // Build menu with state options
        let contextMenu = NSMenu()

        let actions: [(TaskStateAction, String)] = [
            (.complete, "Completed"),
            (.start, "Active"),
            (.stop, "Pending"),
            (.delete, "Deleted"),
        ]

        for (action, title) in actions {
            let item = NSMenuItem(
                title: title,
                action: #selector(handleSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = action

            // Mark current state with checkmark
            if isCurrentState(action) {
                item.state = .on
            }

            contextMenu.addItem(item)
        }

        menu = contextMenu
    }

    /// Determines if the given action represents the current state.
    private func isCurrentState(_ action: TaskStateAction) -> Bool {
        let status = currentStatus.lowercased()
        switch action {
        case .complete:
            return status == "completed"
        case .start:
            return status == "active"
        case .stop:
            return status == "pending"
        case .delete:
            return status == "deleted"
        }
    }

    @objc private func handleSelection(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? TaskStateAction else { return }
        onSelect?(action)
    }

    override func mouseDown(with event: NSEvent) {
        onPress?()
        guard let contextMenu = menu else {
            super.mouseDown(with: event)
            return
        }
        let origin = NSPoint(x: 0, y: bounds.minY - 6)
        contextMenu.popUp(positioning: nil, at: origin, in: self)
    }

    /// Programmatically shows the menu at the button location.
    /// Used for keyboard shortcut triggers (Cmd+P in detail mode).
    func showMenu() {
        onPress?()
        guard let contextMenu = menu else { return }
        let origin = NSPoint(x: 0, y: bounds.minY - 6)
        contextMenu.popUp(positioning: nil, at: origin, in: self)
    }

    #if DEBUG
        var menuItems: [NSMenuItem] {
            menu?.items ?? []
        }
    #endif
}
