use bee_core::config::find_config_file;
use indexmap::IndexMap;
use once_cell::sync::Lazy;
use serde::de;

use std::{fmt, fs, num::ParseIntError};

use serde::Deserialize;
use serde::Deserializer;

#[derive(Deserialize, Debug, PartialEq)]
pub struct Config {
    #[serde(default = "default_colour_field")]
    #[serde(rename = "colours")]
    pub colour_fields: Vec<ColourField>,

    #[serde(default)]
    pub section: SectionConfig,
}

impl Config {
    fn validate(&self) -> Result<(), String> {
        if let Some(section_type) = &self.section.section_type {
            if section_type == &SectionType::Filters && self.section.filters.is_empty() {
                return Err("Configuration: Section: The section configuration type is \
                               'filters' but no filter was provided."
                    .to_string());
            }
        }

        Ok(())
    }
}

impl Default for Config {
    fn default() -> Self {
        load_config_from_string("").expect("Unable to load config from an empty string")
    }
}

#[derive(Deserialize, Debug, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum SectionType {
    Project,
    Filters,
}

#[derive(Deserialize, Debug, PartialEq, Default)]
pub struct SectionConfig {
    #[serde(default)]
    #[serde(rename = "type")]
    pub section_type: Option<SectionType>,

    /// List of the report names
    #[serde(default)]
    pub filters: IndexMap<String, Vec<String>>,

    #[serde(default = "default_section_colour_palette")]
    #[serde(deserialize_with = "deserialize_colors")]
    pub colour_palette: Vec<(u8, u8, u8)>,

    /// This is the section where tasks that don't fit into any
    /// other section go.
    #[serde(default = "default_section_colour")]
    #[serde(deserialize_with = "deserialize_color")]
    pub default_section_colour: (u8, u8, u8),

    #[serde(default = "default_section_header_bg")]
    #[serde(deserialize_with = "deserialize_color")]
    pub section_header_bg: (u8, u8, u8),
}

fn default_section_header_bg() -> (u8, u8, u8) {
    (26, 26, 26)
}

#[derive(Deserialize, Debug, PartialEq)]
pub struct CoeffientField {
    pub field: String,
    pub value: Option<String>,
    pub coefficient: i64,
}

#[derive(Deserialize, Debug, PartialEq)]
pub struct ColourField {
    pub field: String,
    #[serde(default = "default_colour_value_value")]
    pub value: Option<String>,
    #[serde(default = "default_colour_tuple_value")]
    #[serde(deserialize_with = "deserialize_color_option")]
    pub fg: Option<(u8, u8, u8)>,
    #[serde(default = "default_colour_tuple_value")]
    #[serde(deserialize_with = "deserialize_color_option")]
    pub bg: Option<(u8, u8, u8)>,
}

fn default_section_colour() -> (u8, u8, u8) {
    (153, 153, 153)
}

fn default_colour_tuple_value() -> Option<(u8, u8, u8)> {
    None
}

fn default_section_colour_palette() -> Vec<(u8, u8, u8)> {
    vec![
        (246, 76, 60),
        (133, 153, 199),
        (255, 234, 77),
        (121, 203, 103),
    ]
}

fn default_colour_value_value() -> Option<String> {
    None
}

fn default_colour_field() -> Vec<ColourField> {
    Vec::default()
}

#[derive(Debug)]
enum HexColorError {
    Parse(ParseIntError),
    InvalidLength(String),
}

impl fmt::Display for HexColorError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            HexColorError::Parse(ref e) => write!(f, "Parse error: {}", e),
            HexColorError::InvalidLength(ref s) => write!(f, "{}", s),
        }
    }
}

impl From<ParseIntError> for HexColorError {
    fn from(err: ParseIntError) -> HexColorError {
        HexColorError::Parse(err)
    }
}

fn hex_to_rgb(hex_color: &str) -> Result<(u8, u8, u8), HexColorError> {
    if hex_color.len() != 6 {
        return Err(HexColorError::InvalidLength(
            "Invalid Hex colour length".to_string(),
        ));
    }
    let r = u8::from_str_radix(&hex_color[0..2], 16)?;
    let g = u8::from_str_radix(&hex_color[2..4], 16)?;
    let b = u8::from_str_radix(&hex_color[4..6], 16)?;

    Ok((r, g, b))
}

fn deserialize_colors<'de, D>(deserializer: D) -> Result<Vec<(u8, u8, u8)>, D::Error>
where
    D: Deserializer<'de>,
{
    let colours: Vec<String> = Vec::deserialize(deserializer)?;
    if colours.is_empty() {
        return Ok(vec![]);
    }

    let mut result = Vec::new();

    for s in &colours {
        let parsed_tuple = match s {
            s if s.starts_with('#') => match hex_to_rgb(&s[1..]) {
                Ok(colour) => colour,
                Err(e) => {
                    return Err(de::Error::custom(e.to_string()));
                }
            },
            _ => {
                return Err(de::Error::custom("Error parsing colour value".to_string()));
            }
        };
        result.push(parsed_tuple);
    }
    Ok(result)
}

fn deserialize_color<'de, D>(deserializer: D) -> Result<(u8, u8, u8), D::Error>
where
    D: Deserializer<'de>,
{
    let s: String = String::deserialize(deserializer)?;
    match s {
        s if s.starts_with('#') => match hex_to_rgb(&s[1..]) {
            Ok(colour) => Ok(colour),
            Err(e) => Err(de::Error::custom(e.to_string())),
        },
        _ => Err(de::Error::custom("Error parsing colour value".to_string())),
    }
}

fn deserialize_color_option<'de, D>(deserializer: D) -> Result<Option<(u8, u8, u8)>, D::Error>
where
    D: Deserializer<'de>,
{
    let s: Option<String> = Option::deserialize(deserializer)?;
    match s {
        Some(s) if s.starts_with('#') => match hex_to_rgb(&s[1..]) {
            Ok(colour) => Ok(Some(colour)),
            Err(e) => Err(de::Error::custom(e.to_string())),
        },
        _ => Err(de::Error::custom("Error parsing colour value".to_string())),
    }
}

impl Config {
    pub fn get_primary_colour_fg(&self) -> (u8, u8, u8) {
        for c in &self.colour_fields {
            if c.field == "primary_colour" && c.fg.is_some() {
                return c.fg.unwrap();
            }
        }
        (220, 220, 220)
    }

    pub fn get_primary_colour_bg(&self) -> (u8, u8, u8) {
        for c in &self.colour_fields {
            if c.field == "primary_colour" && c.bg.is_some() {
                return c.bg.unwrap();
            }
        }
        (89, 89, 89)
    }

    pub fn get_secondary_colour_fg(&self) -> (u8, u8, u8) {
        for c in &self.colour_fields {
            if c.field == "secondary_colour" && c.fg.is_some() {
                return c.fg.unwrap();
            }
        }
        (220, 220, 220)
    }

    pub fn get_secondary_colour_bg(&self) -> (u8, u8, u8) {
        for c in &self.colour_fields {
            if c.field == "secondary_colour" && c.bg.is_some() {
                return c.bg.unwrap();
            }
        }
        (38, 38, 38)
    }
}

pub fn get_cli_config() -> &'static Config {
    CONFIG.as_ref().unwrap()
}

// The code is used as soon as it is first acces, thanks to the Lazy library
#[allow(dead_code)]
static CONFIG: Lazy<Result<Config, String>> = Lazy::new(|| match load_config() {
    Ok(config) => Ok(config),
    Err(e) => Err(e),
});

pub fn load_config() -> Result<Config, String> {
    match find_config_file() {
        Some(file) => {
            let content = match fs::read_to_string(file) {
                Ok(content) => content,
                Err(e) => {
                    eprintln!("{e}");
                    panic!("Error: Could not read the configuration file.")
                }
            };

            load_config_from_string(&content)
        }
        None => Ok(Config::default()),
    }
}
fn load_config_from_string(content: &str) -> Result<Config, String> {
    let toml_value: toml::Value =
        toml::from_str(content).map_err(|e| format!("Unable to read configuration file: {}", e))?;
    let config: Config = if let Some(cli_config) = toml_value.get("cli") {
        cli_config.clone().try_into().map_err(|e| {
            format!(
                "Unable to parse the [cli] section of the configuration. {}",
                e
            )
        })?
    } else {
        toml::from_str("").map_err(|e| {
            format!("Unable to read an empty string as valid TOML! err={}", e).to_string()
        })?
    };

    config.validate()?;
    Ok(config)
}

#[cfg(test)]
mod test {
    use super::*;
    use all_asserts::assert_true;

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

        let _result = load_config_from_string(content);
        assert_true!(_result.is_ok());
    }

    #[test]
    fn test_parse_colours() {
        let content = r###"
            field = "tag"
            value = "bar"
            fg = "#0000ff"
            bg = "#123456"
        "###;
        let result = toml::from_str::<ColourField>(content);
        assert!(result.is_ok(), "Failed to parse: {:?}", result.unwrap_err());

        let content = r###"
            field = "tag"
            fg = "#0000ff"
            bg = "#123456"
        "###;

        let result = toml::from_str::<ColourField>(content);
        assert!(result.is_ok(), "Failed to parse: {:?}", result.unwrap_err());
    }
}
