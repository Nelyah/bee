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
    var viewModel: LauncherViewModel?
    @ObservedObject var profileManager: ProfileManager
    let transport: ApiTransport?
    @Environment(\.openWindow) private var openWindow
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Button("Show Bee") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        .keyboardShortcut("b", modifiers: [.command, .shift])

        Divider()

        // Profile selection submenu
        if !profileManager.profiles.isEmpty {
            Menu("Profile") {
                ForEach(profileManager.profiles) { profile in
                    Button {
                        profileManager.selectedProfileKey = profile.key
                    } label: {
                        HStack {
                            Text(profile.name)
                            if profile.key == profileManager.selectedProfileKey {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button("Refresh Profiles") {
                    Task {
                        if let transport {
                            await profileManager.loadProfiles(transport: transport)
                        }
                    }
                }
            }

            Divider()
        }

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

// MARK: - Legacy Initializer

extension MenuBarMenu {
    /// Legacy initializer for backwards compatibility.
    init(viewModel: LauncherViewModel?) {
        self.viewModel = viewModel
        profileManager = ProfileManager.shared
        transport = nil
    }
}
