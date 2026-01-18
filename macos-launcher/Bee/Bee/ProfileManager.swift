//
//  ProfileManager.swift
//  Bee
//
//  Manages profile selection and state for the app.
//

import Combine
import Foundation
import LauncherAppKit
import OSLog

/// Manages profile selection and provides profile-aware API clients.
@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    private let logger = Logger(subsystem: "bee.macos-launcher", category: "profiles")

    /// Available profiles fetched from the API.
    @Published private(set) var profiles: [ProfileDto] = []

    /// The currently selected profile key.
    @Published var selectedProfileKey: String? {
        didSet {
            if let key = selectedProfileKey {
                UserDefaults.standard.set(key, forKey: "selectedProfile")
                logger.info("Profile changed to: \(key, privacy: .public)")
            }
        }
    }

    /// Whether profiles are currently being loaded.
    @Published private(set) var isLoading = false

    /// Error message if profile loading failed.
    @Published private(set) var loadError: String?

    /// The currently selected profile, if any.
    var selectedProfile: ProfileDto? {
        profiles.first { $0.key == selectedProfileKey }
    }

    private init() {
        // Restore previously selected profile
        selectedProfileKey = UserDefaults.standard.string(forKey: "selectedProfile")
    }

    /// Fetch available profiles from the API.
    ///
    /// - Parameter transport: The transport to use for API calls.
    func loadProfiles(transport: ApiTransport) async {
        isLoading = true
        loadError = nil

        do {
            // Use a non-profile-scoped client to list profiles
            let client = ApiClient(transport: transport, profile: nil)
            let response = try await client.listProfiles()
            profiles = response.profiles

            // If no profile is selected but profiles exist, select the first one
            if selectedProfileKey == nil, let first = profiles.first {
                selectedProfileKey = first.key
            }

            // If selected profile no longer exists, clear selection
            if let selected = selectedProfileKey,
               !profiles.contains(where: { $0.key == selected }) {
                selectedProfileKey = profiles.first?.key
            }

            logger.info("Loaded \(self.profiles.count) profiles")
        } catch {
            loadError = error.localizedDescription
            logger.error("Failed to load profiles: \(error.localizedDescription, privacy: .public)")
        }

        isLoading = false
    }

    /// Create an API client for the currently selected profile.
    ///
    /// - Parameter transport: The transport to use for API calls.
    /// - Returns: A profile-scoped API client, or nil if no profile is selected.
    func createApiClient(transport: ApiTransport) -> ApiClient? {
        guard let profile = selectedProfileKey else {
            logger.warning("No profile selected, cannot create API client")
            return nil
        }
        return ApiClient(transport: transport, profile: profile)
    }

    /// Create a new profile.
    ///
    /// - Parameters:
    ///   - key: The profile key (lowercase, alphanumeric, hyphens).
    ///   - name: Optional display name.
    ///   - description: Optional description.
    ///   - transport: The transport to use for API calls.
    func createProfile(
        key: String,
        name: String?,
        description: String?,
        transport: ApiTransport
    ) async throws {
        let client = ApiClient(transport: transport, profile: nil)
        let response = try await client.createProfile(key: key, name: name, description: description)
        profiles.append(response.profile)
        logger.info("Created profile: \(key, privacy: .public)")
    }

    /// Delete a profile.
    ///
    /// - Parameters:
    ///   - key: The profile key to delete.
    ///   - transport: The transport to use for API calls.
    func deleteProfile(key: String, transport: ApiTransport) async throws {
        let client = ApiClient(transport: transport, profile: nil)
        try await client.deleteProfile(key: key)
        profiles.removeAll { $0.key == key }

        // If the deleted profile was selected, switch to another
        if selectedProfileKey == key {
            selectedProfileKey = profiles.first?.key
        }

        logger.info("Deleted profile: \(key, privacy: .public)")
    }
}
