//
//  AppDelegate.swift
//  Bee
//
//  Handles application lifecycle and window management for the menu-bar-only app.
//

import AppKit
import LauncherAppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: LauncherViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Close the initial window - we'll show it via menu bar or hotkey
        // This gives the user a clean menu-bar-only experience on launch
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.title == "Bee" }) {
                window.close()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop the backend process when the app quits
        BackendManager.shared.stop()
    }

    /// Shows the main window and brings the app to the foreground.
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.title == "Bee" }) {
            window.makeKeyAndOrderFront(nil)
            window.center()
        }
    }

    /// Toggles the main window visibility.
    @objc func toggleMainWindow() {
        if let window = NSApp.windows.first(where: { $0.title == "Bee" }),
           window.isVisible {
            window.close()
        } else {
            showMainWindow()
        }
    }
}
