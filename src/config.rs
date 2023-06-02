use once_cell::sync::Lazy;
use std::borrow::Cow;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use toml;

use serde::Deserialize;

#[derive(Deserialize, Debug, PartialEq)]
pub struct Config {
    #[serde(default = "default_debug")]
    pub debug: bool,
    pub server: String,
    #[serde(default = "default_default_view")]
    pub default_view: String,
    #[serde(default = "default_views")]
    pub views: HashMap<String, Vec<String>>,
}

// The code is used as soon as it is first acces, thanks to the Lazy library
#[allow(dead_code)]
pub static CONFIG: Lazy<Config> = Lazy::new(load_config);

fn default_debug() -> bool {
    false
}

fn default_default_view() -> String {
    "pending".to_owned()
}

fn default_views() -> HashMap<String, Vec<String>> {
    HashMap::default()
}

fn load_config() -> Config {
    let config_path: PathBuf = match find_config_file() {
        Some(file) => file,
        None => {
            panic!(
                "Could not find a config file. Searched in:\n\
                    - $XDG_CONFIG_HOME/rusk/config.toml\n\
                    - $HOME/.config/rusk/config.toml\n\
                    - $HOME/.rusk.toml\n"
            );
        }
    };
    let content = match fs::read_to_string(config_path) {
        Ok(content) => content,
        Err(e) => {
            eprintln!("{e}");
            panic!("Error: Could not read the configuration file.")
        }
    };

    load_config_from_string(&content)
}
fn load_config_from_string(content: &str) -> Config {
    let config: Config = match toml::from_str(&content) {
        Ok(value) => value,
        Err(e) => {
            eprintln!("{e}");
            panic!("Error: Could not parse the configuration file.");
        }
    };
    config
}

fn find_config_file() -> Option<PathBuf> {
    let home_dir = env::var("HOME").unwrap();
    let xdg_config_home =
        env::var("XDG_CONFIG_HOME").unwrap_or_else(|_| format!("{}/.config", home_dir));

    let paths = [
        &format!("{}/rusk/config.toml", xdg_config_home),
        &format!("{}/.config/rusk/config.toml", home_dir),
        &format!("{}/.rusk.toml", home_dir),
    ];

    for path in paths {
        let expanded_path = match shellexpand::tilde(path) {
            Cow::Borrowed(expanded) => expanded.to_owned(),
            Cow::Owned(v) => v.to_string(),
        };

        if let Ok(full_path) = Path::new(&expanded_path).canonicalize() {
            if full_path.exists() {
                return Some(full_path);
            }
        }
    }

    None
}

#[cfg(test)]
mod test {
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
            debug = true
            server = "localhost"
            default_view = "pending"
            [views]
            github = ["view1", "view2"]
            travis = ["view3"]
        "#;

        // Expected Config struct instance
        let expected_config = Config {
            debug: true,
            server: "localhost".to_owned(),
            default_view: "pending".to_owned(),
            views: {
                let mut map = HashMap::new();
                map.insert(
                    "github".to_owned(),
                    vec!["view1".to_owned(), "view2".to_owned()],
                );
                map.insert("travis".to_owned(), vec!["view3".to_owned()]);
                map
            },
        };

        // Call the function under test
        let result = load_config_from_string(content);

        // Assert that the result matches the expected Config struct
        assert_eq!(result, expected_config);
    }
}
