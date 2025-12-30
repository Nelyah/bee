pub mod config;
pub mod external_links;
pub mod filters;
pub mod storage;
pub mod task;

pub mod lexer;
mod parser;

use std::collections::HashMap;

use config::ReportConfig;
use task::Task;

/// Stable error codes for user-facing error responses.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    InvalidInput,
    ParseError,
    ConfigError,
    StorageError,
    NotFound,
    ActionError,
    ExternalLinkError,
    CliError,
    InternalError,
}

impl ErrorCode {
    pub fn as_str(&self) -> &'static str {
        match self {
            ErrorCode::InvalidInput => "invalid_input",
            ErrorCode::ParseError => "parse_error",
            ErrorCode::ConfigError => "config_error",
            ErrorCode::StorageError => "storage_error",
            ErrorCode::NotFound => "not_found",
            ErrorCode::ActionError => "action_error",
            ErrorCode::ExternalLinkError => "external_link_error",
            ErrorCode::CliError => "cli_error",
            ErrorCode::InternalError => "internal_error",
        }
    }
}

/// Shared contract for user-facing errors across crates.
pub trait UserFacingError: std::error::Error + Send + Sync {
    fn code(&self) -> ErrorCode;
    fn user_message(&self) -> String;
    fn developer_message(&self) -> String;
}

/// Core error type for bee-core.
#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("Parse error: {message}")]
    Parse { message: String },
    #[error("Config error: {message}")]
    Config { message: String },
    #[error("Filter error: {message}")]
    Filter { message: String },
    #[error("Task error: {message}")]
    Task { message: String },
    #[error("Storage error: {message}")]
    Storage { message: String },
    #[error("Not found: {message}")]
    NotFound { message: String },
    #[error("External link error: {message}")]
    ExternalLink { message: String },
    #[error("Internal error: {message}")]
    Internal { message: String },
}

pub type CoreResult<T> = Result<T, CoreError>;

impl CoreError {
    pub fn parse(message: impl Into<String>) -> Self {
        Self::Parse {
            message: message.into(),
        }
    }

    pub fn config(message: impl Into<String>) -> Self {
        Self::Config {
            message: message.into(),
        }
    }

    pub fn filter(message: impl Into<String>) -> Self {
        Self::Filter {
            message: message.into(),
        }
    }

    pub fn task(message: impl Into<String>) -> Self {
        Self::Task {
            message: message.into(),
        }
    }

    pub fn storage(message: impl Into<String>) -> Self {
        Self::Storage {
            message: message.into(),
        }
    }

    pub fn not_found(message: impl Into<String>) -> Self {
        Self::NotFound {
            message: message.into(),
        }
    }

    pub fn external_link(message: impl Into<String>) -> Self {
        Self::ExternalLink {
            message: message.into(),
        }
    }

    pub fn internal(message: impl Into<String>) -> Self {
        Self::Internal {
            message: message.into(),
        }
    }
}

impl UserFacingError for CoreError {
    fn code(&self) -> ErrorCode {
        match self {
            CoreError::Parse { .. } => ErrorCode::ParseError,
            CoreError::Config { .. } => ErrorCode::ConfigError,
            CoreError::Filter { .. } => ErrorCode::ParseError,
            CoreError::Task { .. } => ErrorCode::InvalidInput,
            CoreError::Storage { .. } => ErrorCode::StorageError,
            CoreError::NotFound { .. } => ErrorCode::NotFound,
            CoreError::ExternalLink { .. } => ErrorCode::ExternalLinkError,
            CoreError::Internal { .. } => ErrorCode::InternalError,
        }
    }

    fn user_message(&self) -> String {
        match self {
            CoreError::Parse { .. } | CoreError::Filter { .. } => {
                "Couldn't understand that input.".to_string()
            }
            CoreError::Config { .. } => "Configuration could not be loaded.".to_string(),
            CoreError::Task { .. } => "That task operation could not be completed.".to_string(),
            CoreError::Storage { .. } => "Storage error. Please try again.".to_string(),
            CoreError::NotFound { .. } => "The requested item was not found.".to_string(),
            CoreError::ExternalLink { .. } => "External link operation failed.".to_string(),
            CoreError::Internal { .. } => "Unexpected error. Please try again.".to_string(),
        }
    }

    fn developer_message(&self) -> String {
        self.to_string()
    }
}

impl From<sea_orm::DbErr> for CoreError {
    fn from(err: sea_orm::DbErr) -> Self {
        CoreError::storage(err.to_string())
    }
}

impl From<std::io::Error> for CoreError {
    fn from(err: std::io::Error) -> Self {
        CoreError::storage(err.to_string())
    }
}

impl From<chrono::ParseError> for CoreError {
    fn from(err: chrono::ParseError) -> Self {
        CoreError::parse(err.to_string())
    }
}

impl From<uuid::Error> for CoreError {
    fn from(err: uuid::Error) -> Self {
        CoreError::parse(err.to_string())
    }
}

impl From<serde_json::Error> for CoreError {
    fn from(err: serde_json::Error) -> Self {
        CoreError::internal(err.to_string())
    }
}

impl From<toml::de::Error> for CoreError {
    fn from(err: toml::de::Error) -> Self {
        CoreError::config(err.to_string())
    }
}

pub trait Printer {
    fn print_list_of_tasks(&self, tasks: Vec<&Task>, report_kind: &ReportConfig) -> CoreResult<()>;
    fn print_task_info(&self, task: &Task) -> CoreResult<()>;

    /// Print the help for all the possible actions. This can also have a couple more named sections.
    ///
    /// @help_section_description: This is a map containing a mapping of Action name to
    /// action description, as it is implemented by them. It may also contain a section
    /// name to its content.
    fn show_help(&self, help_section_description: &HashMap<String, String>) -> CoreResult<()>;
    fn show_information_message(&self, message: &str);
    fn error(&self, message: &str);

    /// This function is for developer purposes only. It might be used so the program outputs
    /// information to stdout or console.log, depending on the implementation
    fn print_raw(&self, message: &str);
}
