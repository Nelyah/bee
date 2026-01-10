//! Profile management for bee task manager.
//!
//! Profiles allow completely separate databases and configurations for different
//! contexts (e.g., personal vs work). Each profile has its own:
//! - SQLite database file
//! - Configuration file (TOML)
//!
//! Profile selection:
//! - CLI: Uses `BEE_PROFILE` environment variable
//! - API: Profile is specified in the URL path (`/v1/profiles/{name}/...`)

use log::debug;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;

use crate::{CoreError, CoreResult};

const PROFILES_FILENAME: &str = "profiles.toml";

/// A single profile definition.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Profile {
    /// Display name for the profile (e.g., "Personal", "Work")
    pub name: String,

    /// Optional description
    #[serde(default)]
    pub description: String,

    /// Optional custom data directory override
    #[serde(default)]
    pub data_dir: Option<PathBuf>,

    /// Optional custom config directory override
    #[serde(default)]
    pub config_dir: Option<PathBuf>,
}

/// The profiles.toml configuration file structure.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfilesConfig {
    /// Schema version for future compatibility
    pub version: u32,

    /// Map of profile key (lowercase identifier) to profile definition
    #[serde(default)]
    pub profiles: HashMap<String, Profile>,
}

impl Default for ProfilesConfig {
    fn default() -> Self {
        Self {
            version: 1,
            profiles: HashMap::new(),
        }
    }
}

/// Validates a profile name.
///
/// Profile names must be:
/// - Lowercase
/// - Alphanumeric with hyphens allowed
/// - Not empty
/// - Not start or end with a hyphen
pub fn validate_profile_name(name: &str) -> bool {
    if name.is_empty() {
        return false;
    }

    // Must not start or end with hyphen
    if name.starts_with('-') || name.ends_with('-') {
        return false;
    }

    // Must be lowercase alphanumeric with hyphens
    name.chars()
        .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
}

/// Returns the path to the profiles.toml file.
///
/// Follows XDG Base Directory specification:
/// 1. `$XDG_CONFIG_HOME/bee/profiles.toml`
/// 2. `~/.config/bee/profiles.toml`
pub fn get_profiles_config_path() -> PathBuf {
    let home_dir = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    let xdg_config_home =
        env::var("XDG_CONFIG_HOME").unwrap_or_else(|_| format!("{}/.config", home_dir));

    PathBuf::from(xdg_config_home)
        .join("bee")
        .join(PROFILES_FILENAME)
}

/// Loads the profiles configuration from disk.
///
/// Returns `None` if the profiles.toml file doesn't exist (profile system not initialized).
pub fn load_profiles_config() -> Option<ProfilesConfig> {
    let path = get_profiles_config_path();

    if !path.exists() {
        debug!("Profiles config not found at {:?}", path);
        return None;
    }

    match fs::read_to_string(&path) {
        Ok(content) => match toml::from_str(&content) {
            Ok(config) => Some(config),
            Err(e) => {
                log::error!("Failed to parse profiles.toml: {}", e);
                None
            }
        },
        Err(e) => {
            log::error!("Failed to read profiles.toml: {}", e);
            None
        }
    }
}

/// Saves the profiles configuration to disk.
pub fn save_profiles_config(config: &ProfilesConfig) -> CoreResult<()> {
    let path = get_profiles_config_path();

    // Ensure parent directory exists
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    let content = toml::to_string_pretty(config)
        .map_err(|e| CoreError::config(format!("Failed to serialize profiles config: {}", e)))?;

    fs::write(&path, content)?;

    debug!("Saved profiles config to {:?}", path);
    Ok(())
}

/// Checks if a profile exists.
pub fn profile_exists(name: &str) -> bool {
    if let Some(config) = load_profiles_config() {
        config.profiles.contains_key(name)
    } else {
        false
    }
}

/// Gets a profile by name.
pub fn get_profile(name: &str) -> CoreResult<Profile> {
    let config = load_profiles_config().ok_or_else(|| {
        CoreError::config("Profile system not initialized. Run 'bee profile init <name>' first.")
    })?;

    config
        .profiles
        .get(name)
        .cloned()
        .ok_or_else(|| CoreError::not_found(format!("Profile '{}' not found", name)))
}

/// Lists all configured profiles.
pub fn list_profiles() -> CoreResult<Vec<(String, Profile)>> {
    let config = load_profiles_config().unwrap_or_default();

    Ok(config.profiles.into_iter().collect())
}

/// Creates a new profile.
///
/// This creates the profile entry in profiles.toml and sets up the directory structure,
/// but does NOT copy any existing data.
pub fn create_profile(name: &str, description: &str) -> CoreResult<()> {
    if !validate_profile_name(name) {
        return Err(CoreError::config(format!(
            "Invalid profile name '{}'. Use lowercase letters, numbers, and hyphens only.",
            name
        )));
    }

    let mut config = load_profiles_config().unwrap_or_default();

    if config.profiles.contains_key(name) {
        return Err(CoreError::config(format!(
            "Profile '{}' already exists",
            name
        )));
    }

    let profile = Profile {
        name: name.to_string(),
        description: description.to_string(),
        data_dir: None,
        config_dir: None,
    };

    config.profiles.insert(name.to_string(), profile);
    save_profiles_config(&config)?;

    // Create profile directories
    let data_dir = get_profile_data_dir(name);
    let config_dir = get_profile_config_dir(name);

    fs::create_dir_all(&data_dir)?;
    fs::create_dir_all(&config_dir)?;

    debug!(
        "Created profile '{}' with data_dir={:?}, config_dir={:?}",
        name, data_dir, config_dir
    );
    Ok(())
}

/// Deletes a profile.
///
/// This removes the profile entry from profiles.toml but does NOT delete the data files.
/// The user should manually delete the data if desired.
pub fn delete_profile(name: &str) -> CoreResult<()> {
    let mut config = load_profiles_config()
        .ok_or_else(|| CoreError::config("Profile system not initialized"))?;

    if !config.profiles.contains_key(name) {
        return Err(CoreError::not_found(format!(
            "Profile '{}' not found",
            name
        )));
    }

    config.profiles.remove(name);
    save_profiles_config(&config)?;

    debug!("Deleted profile '{}'", name);
    Ok(())
}

/// Returns the data directory for a profile.
///
/// Default: `~/.local/share/bee/{profile}/`
/// Can be overridden via the profile's `data_dir` field.
pub fn get_profile_data_dir(profile: &str) -> PathBuf {
    // Check if profile has a custom data_dir
    if let Some(config) = load_profiles_config()
        && let Some(p) = config.profiles.get(profile)
        && let Some(custom_dir) = &p.data_dir
    {
        return custom_dir.clone();
    }

    // Default path
    let home_dir = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    let xdg_data_home =
        env::var("XDG_DATA_HOME").unwrap_or_else(|_| format!("{}/.local/share", home_dir));

    PathBuf::from(xdg_data_home).join("bee").join(profile)
}

/// Returns the config directory for a profile.
///
/// Default: `~/.config/bee/{profile}/`
/// Can be overridden via the profile's `config_dir` field.
pub fn get_profile_config_dir(profile: &str) -> PathBuf {
    // Check if profile has a custom config_dir
    if let Some(config) = load_profiles_config()
        && let Some(p) = config.profiles.get(profile)
        && let Some(custom_dir) = &p.config_dir
    {
        return custom_dir.clone();
    }

    // Default path
    let home_dir = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    let xdg_config_home =
        env::var("XDG_CONFIG_HOME").unwrap_or_else(|_| format!("{}/.config", home_dir));

    PathBuf::from(xdg_config_home).join("bee").join(profile)
}

/// Returns the database path for a profile.
pub fn get_profile_database_path(profile: &str) -> PathBuf {
    get_profile_data_dir(profile).join("bee.sqlite")
}

/// Returns the config file path for a profile.
pub fn get_profile_config_path(profile: &str) -> PathBuf {
    get_profile_config_dir(profile).join("config.toml")
}

/// Gets the active profile from the BEE_PROFILE environment variable.
///
/// Returns `None` if:
/// - The environment variable is not set
/// - The environment variable is empty
pub fn get_active_profile_from_env() -> Option<String> {
    env::var("BEE_PROFILE").ok().filter(|s| !s.is_empty())
}

/// Initializes the profile system with an initial profile, migrating existing data.
///
/// This will:
/// 1. Create profiles.toml with the named profile
/// 2. Create profile directories
/// 3. Copy existing bee.sqlite to the profile's data directory (if it exists)
/// 4. Copy existing config to the profile's config directory (if it exists)
pub fn init_profile(name: &str, description: &str) -> CoreResult<()> {
    if !validate_profile_name(name) {
        return Err(CoreError::config(format!(
            "Invalid profile name '{}'. Use lowercase letters, numbers, and hyphens only.",
            name
        )));
    }

    let config_path = get_profiles_config_path();
    if config_path.exists() {
        return Err(CoreError::config(
            "Profile system already initialized. Use 'bee profile create' to add new profiles.",
        ));
    }

    // Create the profile
    create_profile(name, description)?;

    // Find and copy existing database
    let existing_db = find_existing_database();
    if let Some(src) = existing_db {
        let dest = get_profile_database_path(name);
        if src != dest {
            fs::copy(&src, &dest)?;
            log::info!("Copied existing database from {:?} to {:?}", src, dest);
        }
    }

    // Find and copy existing config
    let existing_config = crate::config::find_config_file();
    if let Some(src) = existing_config {
        let dest = get_profile_config_path(name);
        if src != dest {
            fs::copy(&src, &dest)?;
            log::info!("Copied existing config from {:?} to {:?}", src, dest);
        }
    }

    Ok(())
}

/// Finds an existing database file using the legacy path resolution.
fn find_existing_database() -> Option<PathBuf> {
    let home_dir = env::var("HOME").ok()?;

    // Check BEE_DATA_HOME
    if let Ok(data_home) = env::var("BEE_DATA_HOME") {
        let path = PathBuf::from(data_home).join("bee.sqlite");
        if path.exists() {
            return Some(path);
        }
    }

    // Check XDG_DATA_HOME
    if let Ok(xdg_data) = env::var("XDG_DATA_HOME") {
        let path = PathBuf::from(xdg_data).join("bee").join("bee.sqlite");
        if path.exists() {
            return Some(path);
        }
    }

    // Check ~/.local/share/bee/bee.sqlite
    let path = PathBuf::from(&home_dir)
        .join(".local")
        .join("share")
        .join("bee")
        .join("bee.sqlite");
    if path.exists() {
        return Some(path);
    }

    // Check ./bee.sqlite
    let path = PathBuf::from("bee.sqlite");
    if path.exists() {
        return Some(path);
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_profile_name_valid() {
        assert!(validate_profile_name("personal"));
        assert!(validate_profile_name("work"));
        assert!(validate_profile_name("my-profile"));
        assert!(validate_profile_name("profile123"));
        assert!(validate_profile_name("test-profile-2"));
    }

    #[test]
    fn test_validate_profile_name_invalid() {
        assert!(!validate_profile_name("")); // Empty
        assert!(!validate_profile_name("-profile")); // Starts with hyphen
        assert!(!validate_profile_name("profile-")); // Ends with hyphen
        assert!(!validate_profile_name("Profile")); // Uppercase
        assert!(!validate_profile_name("my profile")); // Space
        assert!(!validate_profile_name("my_profile")); // Underscore
        assert!(!validate_profile_name("my.profile")); // Dot
    }

    #[test]
    fn test_profiles_config_default() {
        let config = ProfilesConfig::default();
        assert_eq!(config.version, 1);
        assert!(config.profiles.is_empty());
    }

    #[test]
    fn test_profiles_config_serialization() {
        let mut config = ProfilesConfig::default();
        config.profiles.insert(
            "personal".to_string(),
            Profile {
                name: "Personal".to_string(),
                description: "Personal tasks".to_string(),
                data_dir: None,
                config_dir: None,
            },
        );

        let toml_str = toml::to_string_pretty(&config).unwrap();
        assert!(toml_str.contains("[profiles.personal]"));
        assert!(toml_str.contains("name = \"Personal\""));
    }

    #[test]
    fn test_profiles_config_deserialization() {
        let toml_str = r#"
version = 1

[profiles.work]
name = "Work"
description = "Work tasks"
"#;

        let config: ProfilesConfig = toml::from_str(toml_str).unwrap();
        assert_eq!(config.version, 1);
        assert!(config.profiles.contains_key("work"));
        assert_eq!(config.profiles["work"].name, "Work");
    }

    #[test]
    fn test_profiles_config_with_custom_paths() {
        let toml_str = r#"
version = 1

[profiles.custom]
name = "Custom"
description = "Custom profile"
data_dir = "/custom/data"
config_dir = "/custom/config"
"#;

        let config: ProfilesConfig = toml::from_str(toml_str).unwrap();
        let profile = &config.profiles["custom"];
        assert_eq!(
            profile.data_dir.as_ref().unwrap().to_str().unwrap(),
            "/custom/data"
        );
        assert_eq!(
            profile.config_dir.as_ref().unwrap().to_str().unwrap(),
            "/custom/config"
        );
    }

    #[test]
    fn test_profile_database_path() {
        // This tests the path generation logic, not actual file system access
        let path = get_profile_database_path("test-profile");
        assert!(path.ends_with("test-profile/bee.sqlite"));
    }

    #[test]
    fn test_profile_config_path() {
        let path = get_profile_config_path("test-profile");
        assert!(path.ends_with("test-profile/config.toml"));
    }

    #[test]
    fn test_get_active_profile_from_env_not_set() {
        // SAFETY: Single-threaded test environment
        unsafe {
            std::env::remove_var("BEE_PROFILE");
        }
        assert!(get_active_profile_from_env().is_none());
    }

    #[test]
    fn test_get_active_profile_from_env_empty() {
        // SAFETY: Single-threaded test environment
        unsafe {
            std::env::set_var("BEE_PROFILE", "");
        }
        assert!(get_active_profile_from_env().is_none());
        unsafe {
            std::env::remove_var("BEE_PROFILE");
        }
    }

    #[test]
    fn test_get_active_profile_from_env_set() {
        // SAFETY: Single-threaded test environment
        unsafe {
            std::env::set_var("BEE_PROFILE", "test-profile");
        }
        assert_eq!(
            get_active_profile_from_env(),
            Some("test-profile".to_string())
        );
        unsafe {
            std::env::remove_var("BEE_PROFILE");
        }
    }

    #[test]
    fn test_validate_profile_name_edge_cases() {
        // Single character names
        assert!(validate_profile_name("a"));
        assert!(validate_profile_name("1"));

        // Multiple hyphens (consecutive hyphens are allowed)
        assert!(validate_profile_name("my-test-profile"));
        assert!(validate_profile_name("my--profile")); // Double hyphen is valid

        // Mixed alphanumeric
        assert!(validate_profile_name("profile2024"));
        assert!(validate_profile_name("2024profile"));
    }

    #[test]
    fn test_profile_data_isolation_paths() {
        // Verify different profiles get different paths
        let personal_data = get_profile_data_dir("personal");
        let work_data = get_profile_data_dir("work");

        assert_ne!(personal_data, work_data);
        assert!(personal_data.ends_with("personal"));
        assert!(work_data.ends_with("work"));
    }

    #[test]
    fn test_profile_config_isolation_paths() {
        let personal_config = get_profile_config_dir("personal");
        let work_config = get_profile_config_dir("work");

        assert_ne!(personal_config, work_config);
        assert!(personal_config.ends_with("personal"));
        assert!(work_config.ends_with("work"));
    }

    #[test]
    fn test_profiles_config_multiple_profiles() {
        let toml_str = r#"
version = 1

[profiles.personal]
name = "Personal"
description = "Personal tasks"

[profiles.work]
name = "Work"
description = "Work-related tasks"

[profiles.test]
name = "Test"
description = "Testing profile"
"#;

        let config: ProfilesConfig = toml::from_str(toml_str).unwrap();
        assert_eq!(config.profiles.len(), 3);
        assert!(config.profiles.contains_key("personal"));
        assert!(config.profiles.contains_key("work"));
        assert!(config.profiles.contains_key("test"));
    }
}
