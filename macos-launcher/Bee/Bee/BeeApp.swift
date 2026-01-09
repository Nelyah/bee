//
//  BeeApp.swift
//  Bee
//
//  Created by Chloé Dequeker on 2026-01-09.
//

import LauncherAppKit
import SwiftUI

@main
struct BeeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = LauncherViewModel()

    var body: some Scene {
        // Main window (hidden by default, shown via menu bar)
        Window("Bee", id: "main") {
            ContentView(viewModel: viewModel)
                .onAppear {
                    appDelegate.viewModel = viewModel
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
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

        // Menu bar icon - uses SF Symbol (can be replaced with custom image later)
        MenuBarExtra {
            MenuBarMenu(viewModel: viewModel)
        } label: {
            Image(systemName: "checklist")
        }
        .menuBarExtraStyle(.menu)
    }
}
