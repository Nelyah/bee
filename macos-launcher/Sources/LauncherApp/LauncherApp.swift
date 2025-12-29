import SwiftUI

@main
struct LauncherApp: App {
    @StateObject private var viewModel = LauncherViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Close Detail") {
                    viewModel.closeDetail()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}
