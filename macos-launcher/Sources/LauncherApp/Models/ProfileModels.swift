import Foundation

// MARK: - Profile DTOs

/// A profile that provides isolated database and configuration.
public struct ProfileDto: Codable, Sendable, Identifiable, Hashable {
    public var id: String { key }

    /// The unique key for this profile (lowercase, alphanumeric, hyphens).
    public let key: String

    /// Display name for the profile.
    public let name: String

    /// Optional description of the profile.
    public let description: String

    /// Path to the profile's data directory.
    public let dataDir: String

    /// Path to the profile's config directory.
    public let configDir: String

    private enum CodingKeys: String, CodingKey {
        case key
        case name
        case description
        case dataDir = "data_dir"
        case configDir = "config_dir"
    }

    /// Memberwise initializer for testing and previews.
    public init(key: String, name: String, description: String, dataDir: String, configDir: String) {
        self.key = key
        self.name = name
        self.description = description
        self.dataDir = dataDir
        self.configDir = configDir
    }
}

/// Response from GET /v1/profiles
public struct ProfilesListResponse: Codable, Sendable {
    public let profiles: [ProfileDto]

    public init(profiles: [ProfileDto]) {
        self.profiles = profiles
    }
}

/// Request body for POST /v1/profiles
public struct ProfileCreateRequest: Codable, Sendable {
    public let key: String
    public let name: String?
    public let description: String?

    public init(key: String, name: String?, description: String?) {
        self.key = key
        self.name = name
        self.description = description
    }
}

/// Response from POST /v1/profiles (profile created)
public struct ProfileCreateResponse: Codable, Sendable {
    public let profile: ProfileDto

    public init(profile: ProfileDto) {
        self.profile = profile
    }
}
