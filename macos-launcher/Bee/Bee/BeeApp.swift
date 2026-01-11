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
    @StateObject private var profileManager = ProfileManager.shared
    @State private var viewModel: LauncherViewModel?
    @State private var startupError: String?
    @State private var transport: ApiTransport?
    @State private var didStartBackend = false

    /// Window title including the selected profile name.
    private var windowTitle: String {
        if let profile = profileManager.selectedProfile {
            return "Bee - \(profile.name)"
        }
        return "Bee"
    }

    var body: some Scene {
        // Main window (hidden by default, shown via menu bar)
        Window(windowTitle, id: "main") {
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
                } else if transport == nil || profileManager.isLoading {
                    StartupView()
                } else if profileManager.profiles.isEmpty, !profileManager.isLoading {
                    // No profiles available yet - show profile setup
                    NoProfilesView(profileManager: profileManager, transport: transport) {
                        Task { await createViewModelForProfile() }
                    }
                } else {
                    StartupView()
                }
            }
            .onChange(of: profileManager.selectedProfileKey) { _, _ in
                // Recreate view model when profile changes
                Task { await createViewModelForProfile() }
            }
            .task {
                await startBackendIfNeeded()
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
            MenuBarMenu(viewModel: viewModel, profileManager: profileManager, transport: transport)
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

            // Store the transport for profile operations
            let socketTransport = UnixSocketTransport(socketPath: socketPath)
            await MainActor.run {
                transport = socketTransport
            }

            // Load available profiles
            await profileManager.loadProfiles(transport: socketTransport)

            // Create view model for selected profile
            await createViewModelForProfile()
        } catch {
            await MainActor.run {
                startupError = error.localizedDescription
            }
        }
    }

    private func startBackendIfNeeded() async {
        let shouldStart = await MainActor.run { () -> Bool in
            if didStartBackend {
                return false
            }
            didStartBackend = true
            return true
        }
        guard shouldStart else { return }
        await startBackend()
    }

    /// Create a view model for the currently selected profile.
    private func createViewModelForProfile() async {
        guard let transport else { return }
        guard let apiClient = profileManager.createApiClient(transport: transport) else {
            // No profile selected - will show NoProfilesView
            return
        }
        await MainActor.run {
            viewModel = LauncherViewModel(apiClient: apiClient)
        }
    }
}

// MARK: - No Profiles View

/// View shown when no profiles exist yet.
struct NoProfilesView: View {
    @ObservedObject var profileManager: ProfileManager
    let transport: ApiTransport?
    let onProfileCreated: () -> Void

    @State private var profileKey = ""
    @State private var profileName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Welcome to Bee!")
                .font(.title)
                .fontWeight(.semibold)

            Text("Create your first profile to get started.\nProfiles keep your tasks separate for different contexts.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Profile key (e.g., personal, work)", text: $profileKey)
                    .textFieldStyle(.roundedBorder)

                TextField("Display name (optional)", text: $profileName)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 300)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: createProfile) {
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Create Profile")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(profileKey.isEmpty || isCreating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .padding()
    }

    private func createProfile() {
        guard let transport else { return }
        isCreating = true
        errorMessage = nil

        Task {
            do {
                try await profileManager.createProfile(
                    key: profileKey.lowercased(),
                    name: profileName.isEmpty ? nil : profileName,
                    description: nil,
                    transport: transport
                )
                profileManager.selectedProfileKey = profileKey.lowercased()
                onProfileCreated()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
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
