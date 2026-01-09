//
//  MenuBarMenu.swift
//  Bee
//
//  The dropdown menu that appears when clicking the menu bar icon.
//

import LauncherAppKit
import ServiceManagement
import SwiftUI

struct MenuBarMenu: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Button("Show Bee") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        .keyboardShortcut("b", modifiers: [.command, .shift])

        Divider()

        Toggle("Launch at Login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { _, newValue in
                updateLaunchAtLogin(enabled: newValue)
            }

        Divider()

        Button("Quit Bee") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
            // Revert the toggle on failure
            launchAtLogin = !enabled
        }
    }
}
