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
    @StateObject private var backendManager = BackendManager.shared
    @State private var viewModel: LauncherViewModel?
    @State private var startupError: String?

    var body: some Scene {
        // Main window (hidden by default, shown via menu bar)
        Window("Bee", id: "main") {
            Group {
                if let viewModel {
                    ContentView(viewModel: viewModel)
                        .onAppear {
                            appDelegate.viewModel = viewModel
                        }
                } else if let error = startupError {
                    StartupErrorView(error: error) {
                        // Retry
                        startupError = nil
                        Task { await startBackend() }
                    }
                } else {
                    StartupView()
                        .task { await startBackend() }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Close Detail") {
                    viewModel?.closeDetail()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Command Palette") {
                    viewModel?.openCommandPalette()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Link to Task...") {
                    viewModel?.openLinkPalette()
                }
                .keyboardShortcut("l", modifiers: [.command])

                Button("Contextual Menu") {
                    viewModel?.handleContextualMenu()
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

    private func startBackend() async {
        do {
            try await backendManager.start()
            guard let socketPath = backendManager.socketPath else {
                throw BackendError.notStarted
            }
            // Create ApiClient using Unix socket transport
            let apiClient = ApiClient.unixSocket(path: socketPath)
            await MainActor.run {
                viewModel = LauncherViewModel(apiClient: apiClient)
            }
        } catch {
            await MainActor.run {
                startupError = error.localizedDescription
            }
        }
    }
}

// MARK: - Startup Views

/// Loading view shown while backend is starting.
struct StartupView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Starting Bee...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// Error view shown when backend fails to start.
struct StartupErrorView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to start backend")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .padding()
    }
}
