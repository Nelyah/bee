import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var escapeMonitor: Any?
    @State private var normalModeMonitor: Any?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            launcherBackground

            if viewModel.mode == .detail, let task = viewModel.selectedTask {
                TaskDetailView(task: task, onClose: {
                    viewModel.closeDetail()
                })
                    .padding(24)
            } else {
                TaskListView(viewModel: viewModel, completion: viewModel.completion)
                    .padding(20)
            }

            if viewModel.commandPalette.isPresented {
                CommandPaletteView(viewModel: viewModel, commandPalette: viewModel.commandPalette)
            }

            ToastStackView(toasts: viewModel.toasts)
                .padding(.horizontal, 16)
                .padding(.bottom, BottomHintBar.height + DesignTokens.Spacing.xxl)
                .allowsHitTesting(false)
                .zIndex(2)
        }
        .overlay(alignment: .bottom) {
            BottomHintBar(leftHints: viewModel.hintModel.left, rightHints: viewModel.hintModel.right)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .zIndex(1)
        }
        .onExitCommand {
            viewModel.handleEscape()
        }
        .onReceive(viewModel.windowClose) { _ in
            closeWindow()
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ThemeManager.current.surface1.opacity(0.5), lineWidth: 1)
        )
        .frame(minWidth: 680, minHeight: 440)
        .onAppear {
            DispatchQueue.main.async {
                NSApplication.shared.setActivationPolicy(.regular)
                NSApplication.shared.activate(ignoringOtherApps: true)
                configureWindowAppearance()
                installEscapeMonitor()
                installNormalModeMonitor()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            configureWindowAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            configureWindowAppearance()
        }
        .onDisappear {
            removeEscapeMonitor()
            removeNormalModeMonitor()
        }
    }

    private var launcherBackground: some View {
        ThemeManager.current.base
            .ignoresSafeArea()
    }


    /// Apply Raycast-style window appearance (no title bar, clear background).
    private func configureWindowAppearance() {
        let windows = NSApplication.shared.windows
        guard !windows.isEmpty else { return }
        for window in windows {
            // Remove title bar completely
            window.styleMask.remove(.titled)
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = 18
                contentView.layer?.masksToBounds = true
            }
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
    }

    /// Capture Escape at the window level to close detail view or exit insert mode.
    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == KeyCode.escape {
                return viewModel.handleEscape() ? nil : event
            }
            return event
        }
    }

    /// Remove the Escape key monitor.
    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    /// Handle keys in normal mode (when text input is not focused).
    private func installNormalModeMonitor() {
        guard normalModeMonitor == nil else { return }
        normalModeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle keys in normal mode (not insert mode) and in list mode (not detail)
            guard !viewModel.isInsertMode, viewModel.mode == .list else { return event }
            guard let action = KeyHandlingDecider.normalModeAction(for: KeyInput(event: event)) else {
                return event
            }

            return viewModel.handleNormalModeAction(action) ? nil : event
        }
    }

    /// Remove the normal mode key monitor.
    private func removeNormalModeMonitor() {
        if let monitor = normalModeMonitor {
            NSEvent.removeMonitor(monitor)
            normalModeMonitor = nil
        }
    }

    private func closeWindow() {
        let app = NSApplication.shared
        if let window = app.keyWindow ?? app.mainWindow {
            window.close()
            return
        }
        if let window = app.windows.first(where: { $0.isVisible }) ?? app.windows.first {
            window.close()
            return
        }
        _ = app.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
    }
}

#Preview("List Mode") {
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.tasks = MockApiClient.sampleTasks

    return ContentView(viewModel: viewModel)
        .frame(width: 680, height: 440)
}

#Preview("Detail Mode") {
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.tasks = MockApiClient.sampleTasks
    viewModel.selectedIndex = 0
    viewModel.mode = .detail

    return ContentView(viewModel: viewModel)
        .frame(width: 680, height: 440)
}
