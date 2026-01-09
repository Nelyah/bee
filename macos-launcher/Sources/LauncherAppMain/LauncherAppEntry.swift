import LauncherAppKit
import SwiftUI

/// CLI entry point - simpler than the full Xcode app.
/// For the full experience with menu bar, use the Xcode project.
@main
struct LauncherApp: App {
    @StateObject private var viewModel = LauncherViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
