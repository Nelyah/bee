import AppKit
import SwiftUI

struct ReportMenuButton: View {
    let name: String
    let reports: [ReportSummary]
    @Binding var flash: Bool
    let onSelect: (String) -> Void

    var body: some View {
        ReportMenuButtonRepresentable(name: name, reports: reports, onSelect: onSelect) {
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                flash = false
            }
        }
        .fixedSize()
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .opacity(flash ? 0.6 : 1.0)
        .animation(.easeOut(duration: 0.12), value: flash)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(ThemeManager.current.surface1.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(ThemeManager.current.surface2.opacity(0.5), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }
}

private struct ReportBadgeView: View {
    let name: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text("Report: \(name)")
                .font(.system(size: DesignTokens.TypeScale.label, weight: .semibold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
            Image(systemName: "chevron.down")
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
                .foregroundColor(ThemeManager.current.subtext0)
        }
    }
}

private struct ReportMenuButtonRepresentable: NSViewRepresentable {
    let name: String
    let reports: [ReportSummary]
    let onSelect: (String) -> Void
    let onPress: () -> Void

    /// Creates the AppKit menu button view.
    func makeNSView(context: Context) -> ReportMenuButtonView {
        let view = ReportMenuButtonView(onSelect: onSelect, onPress: onPress)
        view.update(name: name, reports: reports)
        return view
    }

    /// Updates the AppKit menu button view with the latest data.
    func updateNSView(_ nsView: ReportMenuButtonView, context: Context) {
        nsView.onSelect = onSelect
        nsView.onPress = onPress
        nsView.update(name: name, reports: reports)
    }
}

/// AppKit-backed menu view so we can control placement and press feedback.
final class ReportMenuButtonView: NSView {
    private var hostingView: NSHostingView<ReportBadgeView>?
    var onPress: (() -> Void)?
    var onSelect: ((String) -> Void)?

    /// Creates the menu view with selection and press callbacks.
    init(onSelect: @escaping (String) -> Void, onPress: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onPress = onPress
        super.init(frame: .zero)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Provides an intrinsic size so SwiftUI doesn't stretch the control.
    override var intrinsicContentSize: NSSize {
        hostingView?.fittingSize ?? super.intrinsicContentSize
    }

    /// Updates the label and menu items.
    func update(name: String, reports: [ReportSummary]) {
        if let hostingView {
            hostingView.rootView = ReportBadgeView(name: name)
        } else {
            let hostingView = NSHostingView(rootView: ReportBadgeView(name: name))
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            self.hostingView = hostingView
        }
        invalidateIntrinsicContentSize()

        let contextMenu = NSMenu()
        for report in reports {
            let item = NSMenuItem(
                title: report.name,
                action: #selector(handleReportSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = report.name
            if report.name == name {
                item.state = .on
            }
            contextMenu.addItem(item)
        }
        menu = contextMenu
    }

    /// Handles menu item selection and forwards the report name.
    @objc private func handleReportSelection(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        onSelect?(name)
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

#if DEBUG
    /// Exposes menu items for tests.
    var menuItems: [NSMenuItem] {
        menu?.items ?? []
    }
#endif
}
