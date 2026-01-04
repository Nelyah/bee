import SwiftUI

@main
struct LauncherApp: App {
    @StateObject private var viewModel = LauncherViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Close Detail") {
                    viewModel.closeDetail()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Command Palette") {
                    viewModel.openCommandPalette()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Link to Task...") {
                    viewModel.openLinkPalette()
                }
                .keyboardShortcut("l", modifiers: [.command])

                Button("Contextual Menu") {
                    viewModel.handleContextualMenu()
                }
                .keyboardShortcut("p", modifiers: [.command])
            }
        }
    }
}
