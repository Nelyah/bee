use log::{debug, info};
use once_cell::sync::Lazy;
use std::borrow::Cow;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use serde::Deserialize;

use crate::{CoreError, CoreResult};

#[derive(Deserialize, Debug, PartialEq)]
pub struct Config {
    #[serde(default = "default_report_name")]
    pub default_report: String,

    #[serde(default = "default_report_map")]
    #[serde(rename = "report")]
    report_map: HashMap<String, ReportConfig>,

    #[serde(default)]
    #[serde(rename = "coefficients")]
    pub coefficients: Vec<CoeffientField>,

    #[serde(default)]
    pub external_links: ExternalLinksConfig,

    /// Urgency scoring configuration.
    /// Customize weights for different urgency factors.
    #[serde(default)]
    pub urgency: crate::urgency::UrgencyConfig,
}

fn default_report_map() -> HashMap<String, ReportConfig> {
    HashMap::from([(DEFAULT_REPORT_NAME.to_string(), ReportConfig::default())])
}

fn default_report_name() -> String {
    DEFAULT_REPORT_NAME.to_string()
}

impl Default for Config {
    fn default() -> Self {
        Self {
            default_report: default_report_name(),
            report_map: default_report_map(),
            coefficients: Vec::new(),
            external_links: ExternalLinksConfig::default(),
            urgency: crate::urgency::UrgencyConfig::default(),
        }
    }
}

impl Config {
    pub fn get_report(&self, name: &str) -> Option<&ReportConfig> {
        self.report_map.get(name)
    }

    pub fn get_default_report(&self) -> &ReportConfig {
        if let Some(report) = self.get_report(&self.default_report) {
            report
        } else {
            self.get_report(DEFAULT_REPORT_NAME)
                .unwrap_or_else(|| panic!("'{}' report not found.", DEFAULT_REPORT_NAME))
        }
    }

    /// Returns all reports as (name, config) pairs.
    pub fn get_all_reports(&self) -> impl Iterator<Item = (&str, &ReportConfig)> {
        self.report_map.iter().map(|(k, v)| (k.as_str(), v))
    }
}

#[derive(Deserialize, Debug, PartialEq, Default)]
pub struct CoeffientField {
    pub field: String,
    pub value: Option<String>,
    pub coefficient: i64,
}

#[derive(Deserialize, Debug, PartialEq, Clone)]
pub struct ReportConfig {
    pub filters: Vec<String>,
    pub columns: Vec<String>,
    pub column_names: Vec<String>,
    pub default: bool,
}

#[derive(Deserialize, Debug, PartialEq, Clone, Default)]
pub struct ExternalLinksConfig {
    #[serde(default)]
    pub jira: Option<ProviderConfig>,
    #[serde(default)]
    pub gitlab: Option<ProviderConfig>,
}

#[derive(Deserialize, Debug, PartialEq, Clone)]
pub struct ProviderConfig {
    pub base_url: String,
    pub token: TokenConfig,
    #[serde(default = "default_min_delay_ms")]
    pub min_delay_ms: u64,
}

#[derive(Deserialize, Debug, PartialEq, Clone, Default)]
pub struct TokenConfig {
    pub value: Option<String>,
    pub env: Option<String>,
}

fn default_min_delay_ms() -> u64 {
    0
}

impl Default for ReportConfig {
    fn default() -> Self {
        ReportConfig {
            default: true,
            filters: vec!["status:pending or status:active".to_string()],
            columns: ["id", "date_created", "summary", "tags", "urgency"]
                .iter()
                .map(|&s| s.to_string())
                .collect(),
            column_names: ["ID", "Date Created", "Summary", "Tags", "Urgency"]
                .iter()
                .map(|&s| s.to_string())
                .collect(),
        }
    }
}

pub fn get_config() -> &'static Config {
    CONFIG.as_ref().unwrap()
}

// The code is used as soon as it is first acces, thanks to the Lazy library
#[allow(dead_code)]
static CONFIG: Lazy<CoreResult<Config>> = Lazy::new(|| match load_config() {
    Ok(config) => Ok(config),
    Err(e) => Err(e),
});

const DEFAULT_REPORT_NAME: &str = "__default";

pub fn load_config() -> CoreResult<Config> {
    match find_config_file() {
        Some(file) => {
            let content = fs::read_to_string(file)
                .map_err(|e| CoreError::config(format!("Could not read config file: {e}")))?;

            load_config_from_string(&content)
        }
        None => Ok(Config::default()),
    }
}
fn load_config_from_string(content: &str) -> CoreResult<Config> {
    let toml_value: toml::Value = toml::from_str(content)
        .map_err(|e| CoreError::config(format!("Unable to read configuration file: {e}")))?;
    let mut config: Config = if let Some(core_config) = toml_value.get("core") {
        core_config.clone().try_into().map_err(|e| {
            CoreError::config(format!(
                "Unable to parse the [core] section of the configuration. {e}"
            ))
        })?
    } else {
        return Err(CoreError::config(
            "Configuration file found but the [core] section is missing.",
        ));
    };

    for (name, report) in &config.report_map {
        if report.default {
            config.default_report = name.clone();
        }
    }
    if config.get_report(&config.default_report).is_none() {
        config.default_report = DEFAULT_REPORT_NAME.to_string();
        config
            .report_map
            .insert(DEFAULT_REPORT_NAME.to_string(), ReportConfig::default());
    }
    Ok(config)
}

pub fn find_config_file() -> Option<PathBuf> {
    let home_dir = env::var("HOME").unwrap();
    let xdg_config_home =
        env::var("XDG_CONFIG_HOME").unwrap_or_else(|_| format!("{}/.config", home_dir));

    let paths = [
        "bee.toml",
        &format!("{}/bee/config.toml", xdg_config_home),
        &format!("{}/.config/bee/config.toml", home_dir),
        &format!("{}/.bee.toml", home_dir),
    ];

    for path in paths {
        let expanded_path = match shellexpand::tilde(path) {
            Cow::Borrowed(expanded) => expanded.to_owned(),
            Cow::Owned(v) => v.to_string(),
        };

        if let Ok(full_path) = Path::new(&expanded_path).canonicalize()
            && full_path.exists()
        {
            debug!("Found config file {}", expanded_path);
            return Some(full_path);
        }
    }

    info!(
        "Did not find a config file in any of the following locationss: {:?}",
        paths
    );
    None
}

#[cfg(test)]
mod test {
    use all_asserts::assert_true;

    use super::*;

    // Test that this doesn't panic
    #[test]
    fn test_find_config_file() {
        find_config_file();
    }

    #[test]
    fn test_load_config_from_string() {
        // Example TOML content
        let content = r#"
[core]
debug = true

        "#;

        let _result = load_config_from_string(content);
        assert_true!(_result.is_ok());
    }

    #[test]
    fn test_get_default_report_exists() {
        let config = Config::default();
        let report_config = ReportConfig::default();

        let result = config.get_default_report();
        assert_eq!(result, &report_config);
    }
}
