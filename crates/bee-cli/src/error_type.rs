use bee_actions::ActionError;
use bee_core::{CoreError, ErrorCode, UserFacingError};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum CliError {
    #[error("Configuration error: {message}")]
    Config { message: String },
    #[error("I/O error: {message}")]
    Io { message: String },
    #[error(transparent)]
    Core(#[from] CoreError),
    #[error(transparent)]
    Action(#[from] ActionError),
}

pub type CliResult<T> = Result<T, CliError>;

impl CliError {
    pub fn config(message: impl Into<String>) -> Self {
        Self::Config {
            message: message.into(),
        }
    }

    pub fn io(message: impl Into<String>) -> Self {
        Self::Io {
            message: message.into(),
        }
    }
}

impl UserFacingError for CliError {
    fn code(&self) -> ErrorCode {
        match self {
            CliError::Config { .. } => ErrorCode::ConfigError,
            CliError::Io { .. } => ErrorCode::StorageError,
            CliError::Core(err) => err.code(),
            CliError::Action(err) => err.code(),
        }
    }

    fn user_message(&self) -> String {
        match self {
            CliError::Config { .. } => "Configuration could not be loaded.".to_string(),
            CliError::Io { .. } => "I/O error. Please try again.".to_string(),
            CliError::Core(err) => err.user_message(),
            CliError::Action(err) => err.user_message(),
        }
    }

    fn developer_message(&self) -> String {
        match self {
            CliError::Core(err) => err.developer_message(),
            CliError::Action(err) => err.developer_message(),
            _ => self.to_string(),
        }
    }
}
