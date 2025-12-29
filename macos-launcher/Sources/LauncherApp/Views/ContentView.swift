import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var escapeMonitor: Any?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            launcherBackground

            if viewModel.mode == .detail, let task = viewModel.selectedTask {
                TaskDetailView(task: task, onClose: {
                    viewModel.closeDetail()
                })
                    .padding(24)
            } else {
                TaskListView(viewModel: viewModel)
                    .padding(20)
            }

            ToastStackView(toasts: viewModel.toasts)
                .padding(16)
                .allowsHitTesting(false)
        }
        .onExitCommand {
            viewModel.closeDetail()
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CatppuccinTheme.surface1.opacity(0.5), lineWidth: 1)
        )
        .frame(minWidth: 680, minHeight: 440)
        .onAppear {
            DispatchQueue.main.async {
                NSApplication.shared.setActivationPolicy(.regular)
                NSApplication.shared.activate(ignoringOtherApps: true)
                configureWindowAppearance()
                installEscapeMonitor()
            }
        }
        .onDisappear {
            removeEscapeMonitor()
        }
    }

    private var launcherBackground: some View {
        LinearGradient(
            colors: [
                CatppuccinTheme.base,
                CatppuccinTheme.mantle
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    /// Apply Raycast-style window appearance (no title bar, clear background).
    private func configureWindowAppearance() {
        guard let window = NSApplication.shared.windows.first else { return }
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

    /// Capture Escape at the window level to close detail view.
    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                viewModel.closeDetail()
                return nil
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
