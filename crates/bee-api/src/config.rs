use bee_core::config::ReportConfig;
use serde::Deserialize;
use std::{fs, path::PathBuf};

use crate::error_type::{ApiError, ApiResult};

const DEFAULT_BIND_ADDR: &str = "127.0.0.1:3000";

/// API server configuration loaded from `bee-api.toml` style files.
#[derive(Debug, Deserialize, Clone)]
pub struct ApiConfig {
    #[serde(default = "default_bind_addr")]
    pub bind_addr: String,
    /// Unix socket path. If set, takes precedence over `bind_addr`.
    /// Use `BEE_API_SOCKET` env var to override at runtime.
    #[serde(default)]
    pub socket_path: Option<PathBuf>,
    #[serde(default = "default_undo_count")]
    pub undo_count: usize,
    #[serde(default = "default_allowed_actions")]
    pub allowed_actions: Vec<String>,
    #[serde(default)]
    pub report: ReportConfig,
    #[serde(default)]
    pub external_links: ExternalLinksApiConfig,
}

impl Default for ApiConfig {
    fn default() -> Self {
        Self {
            bind_addr: default_bind_addr(),
            socket_path: None,
            undo_count: default_undo_count(),
            allowed_actions: default_allowed_actions(),
            report: ReportConfig::default(),
            external_links: ExternalLinksApiConfig::default(),
        }
    }
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct ExternalLinksApiConfig {
    #[serde(default)]
    pub sync: SyncConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SyncConfig {
    #[serde(default = "default_stale_after_hours")]
    pub stale_after_hours: i64,
    #[serde(default = "default_batch_size")]
    pub batch_size: usize,
    /// Enable automatic background sync of stale external links.
    #[serde(default = "default_background_enabled")]
    pub background_enabled: bool,
    /// Interval between background sync runs in minutes.
    #[serde(default = "default_background_interval_minutes")]
    pub background_interval_minutes: u64,
}

impl Default for SyncConfig {
    fn default() -> Self {
        Self {
            stale_after_hours: default_stale_after_hours(),
            batch_size: default_batch_size(),
            background_enabled: default_background_enabled(),
            background_interval_minutes: default_background_interval_minutes(),
        }
    }
}

/// Load the API configuration from disk or return defaults.
pub fn load_config() -> ApiResult<ApiConfig> {
    match find_config_file() {
        Some(path) => {
            let content = fs::read_to_string(path).map_err(|err| {
                ApiError::config(format!("Unable to read API config file: {err}"))
            })?;
            load_config_from_string(&content)
        }
        None => Ok(ApiConfig::default()),
    }
}

fn load_config_from_string(content: &str) -> ApiResult<ApiConfig> {
    let toml_value: toml::Value = toml::from_str(content)
        .map_err(|err| ApiError::config(format!("Invalid API config: {err}")))?;
    let api_section = match toml_value.get("api") {
        Some(section) => section.clone(),
        None => return Ok(ApiConfig::default()),
    };
    let api: ApiConfig = api_section
        .try_into()
        .map_err(|err| ApiError::config(format!("Invalid [api] config: {err}")))?;
    Ok(api)
}

fn find_config_file() -> Option<PathBuf> {
    bee_core::config::find_config_file()
}

fn default_bind_addr() -> String {
    DEFAULT_BIND_ADDR.to_string()
}

fn default_undo_count() -> usize {
    1
}

fn default_allowed_actions() -> Vec<String> {
    vec![
        "add".to_string(),
        "list".to_string(),
        "modify".to_string(),
        "done".to_string(),
        "delete".to_string(),
        "start".to_string(),
        "stop".to_string(),
        "annotate".to_string(),
    ]
}

fn default_stale_after_hours() -> i64 {
    24
}

fn default_batch_size() -> usize {
    10
}

fn default_background_enabled() -> bool {
    true
}

fn default_background_interval_minutes() -> u64 {
    15
}

#[cfg(test)]
mod tests {
    use super::{ApiConfig, default_allowed_actions, load_config_from_string};
    use bee_core::config::ReportConfig;

    #[test]
    fn test_load_config_from_string() {
        let config = load_config_from_string(
            r#"
[api]
bind_addr = "127.0.0.1:4000"
undo_count = 2
allowed_actions = ["add", "list"]

[api.report]
filters = ["status:pending"]
columns = ["id", "summary"]
column_names = ["ID", "Summary"]
default = true

[api.external_links.sync]
stale_after_hours = 12
batch_size = 5
"#,
        )
        .expect("config should parse");

        assert_eq!(config.bind_addr, "127.0.0.1:4000");
        assert_eq!(config.undo_count, 2);
        assert_eq!(config.allowed_actions, vec!["add", "list"]);
        assert_eq!(config.report.filters, vec!["status:pending"]);
        assert_eq!(config.report.columns, vec!["id", "summary"]);
        assert_eq!(config.report.column_names, vec!["ID", "Summary"]);
        assert_eq!(config.external_links.sync.stale_after_hours, 12);
        assert_eq!(config.external_links.sync.batch_size, 5);
    }

    #[test]
    fn test_default_config() {
        let config = ApiConfig::default();
        assert_eq!(config.undo_count, 1);
        assert_eq!(config.allowed_actions, default_allowed_actions());
        assert_eq!(config.report, ReportConfig::default());
        assert_eq!(config.external_links.sync.stale_after_hours, 24);
        assert_eq!(config.external_links.sync.batch_size, 10);
    }
}
