use bee_core::config::ReportConfig;
use serde::Deserialize;
use std::{
    env, fs,
    path::{Path, PathBuf},
};

const DEFAULT_BIND_ADDR: &str = "127.0.0.1:3000";

/// API server configuration loaded from `bee-api.toml` style files.
#[derive(Debug, Deserialize, Clone)]
pub struct ApiConfig {
    #[serde(default = "default_bind_addr")]
    pub bind_addr: String,
    #[serde(default = "default_undo_count")]
    pub undo_count: usize,
    #[serde(default = "default_allowed_actions")]
    pub allowed_actions: Vec<String>,
    #[serde(default)]
    pub report: ReportConfig,
}

impl Default for ApiConfig {
    fn default() -> Self {
        Self {
            bind_addr: default_bind_addr(),
            undo_count: default_undo_count(),
            allowed_actions: default_allowed_actions(),
            report: ReportConfig::default(),
        }
    }
}

/// Load the API configuration from disk or return defaults.
pub fn load_config() -> Result<ApiConfig, String> {
    match find_config_file() {
        Some(path) => {
            let content = fs::read_to_string(path)
                .map_err(|err| format!("Unable to read API config file: {err}"))?;
            load_config_from_string(&content)
        }
        None => Ok(ApiConfig::default()),
    }
}

fn load_config_from_string(content: &str) -> Result<ApiConfig, String> {
    let toml_value: toml::Value =
        toml::from_str(content).map_err(|err| format!("Invalid API config: {err}"))?;
    let api_section = toml_value
        .get("api")
        .ok_or_else(|| "API config is missing [api] section".to_string())?;
    let api: ApiConfig = api_section
        .clone()
        .try_into()
        .map_err(|err| format!("Invalid [api] config: {err}"))?;
    Ok(api)
}

fn find_config_file() -> Option<PathBuf> {
    if let Ok(path) = env::var("BEE_API_CONFIG") {
        return canonicalize_if_exists(path);
    }

    let home_dir = env::var("HOME").ok();
    let xdg_config_home = env::var("XDG_CONFIG_HOME").ok();

    let mut candidates = Vec::new();
    candidates.push("bee-api.toml".to_string());

    if let Some(xdg) = xdg_config_home {
        candidates.push(format!("{}/bee-api/config.toml", xdg));
    }

    if let Some(home) = home_dir {
        candidates.push(format!("{}/.config/bee-api/config.toml", home));
        candidates.push(format!("{}/.bee-api.toml", home));
    }

    for path in candidates {
        if let Some(p) = canonicalize_if_exists(path) {
            return Some(p);
        }
    }

    None
}

fn canonicalize_if_exists<P: AsRef<Path>>(path: P) -> Option<PathBuf> {
    let path = Path::new(path.as_ref());
    if !path.exists() {
        return None;
    }
    path.canonicalize().ok()
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
"#,
        )
        .expect("config should parse");

        assert_eq!(config.bind_addr, "127.0.0.1:4000");
        assert_eq!(config.undo_count, 2);
        assert_eq!(config.allowed_actions, vec!["add", "list"]);
        assert_eq!(config.report.filters, vec!["status:pending"]);
        assert_eq!(config.report.columns, vec!["id", "summary"]);
        assert_eq!(config.report.column_names, vec!["ID", "Summary"]);
    }

    #[test]
    fn test_default_config() {
        let config = ApiConfig::default();
        assert_eq!(config.undo_count, 1);
        assert_eq!(config.allowed_actions, default_allowed_actions());
        assert_eq!(config.report, ReportConfig::default());
    }
}
