use axum::{Json, http::StatusCode, response::IntoResponse};
use bee_actions::ActionError;
use bee_core::{CoreError, ErrorCode, UserFacingError};
use serde::Serialize;
use thiserror::Error;
use utoipa::ToSchema;

#[derive(Debug, Serialize, ToSchema)]
pub struct ApiErrorResponse {
    pub code: String,
    pub user_message: String,
    pub developer_message: String,
}

#[derive(Debug, Error)]
pub enum ApiError {
    #[error("Bad request: {message}")]
    BadRequest { message: String },
    #[error("Not found: {message}")]
    NotFound { message: String },
    #[error("Conflict: {message}")]
    Conflict { message: String },
    #[error("Configuration error: {message}")]
    Config { message: String },
    #[error("External link error: {message}")]
    ExternalLink { message: String },
    #[error("HTTP error: {message}")]
    Http { message: String },
    #[error("Internal error: {message}")]
    Internal { message: String },
    #[error(transparent)]
    Core(#[from] CoreError),
    #[error(transparent)]
    Action(#[from] ActionError),
}

pub type ApiResult<T> = Result<T, ApiError>;

impl ApiError {
    pub fn bad_request(message: impl Into<String>) -> Self {
        Self::BadRequest {
            message: message.into(),
        }
    }

    pub fn not_found(message: impl Into<String>) -> Self {
        Self::NotFound {
            message: message.into(),
        }
    }

    pub fn conflict(message: impl Into<String>) -> Self {
        Self::Conflict {
            message: message.into(),
        }
    }

    pub fn config(message: impl Into<String>) -> Self {
        Self::Config {
            message: message.into(),
        }
    }

    pub fn external_link(message: impl Into<String>) -> Self {
        Self::ExternalLink {
            message: message.into(),
        }
    }

    pub fn http(message: impl Into<String>) -> Self {
        Self::Http {
            message: message.into(),
        }
    }

    pub fn internal(message: impl Into<String>) -> Self {
        Self::Internal {
            message: message.into(),
        }
    }

    pub fn status(&self) -> StatusCode {
        match self {
            ApiError::BadRequest { .. } => StatusCode::BAD_REQUEST,
            ApiError::NotFound { .. } => StatusCode::NOT_FOUND,
            ApiError::Conflict { .. } => StatusCode::CONFLICT,
            ApiError::Config { .. } => StatusCode::INTERNAL_SERVER_ERROR,
            ApiError::ExternalLink { .. } => StatusCode::BAD_REQUEST,
            ApiError::Http { .. } => StatusCode::BAD_GATEWAY,
            ApiError::Internal { .. } => StatusCode::INTERNAL_SERVER_ERROR,
            ApiError::Core(err) => status_from_code(err.code()),
            ApiError::Action(err) => status_from_code(err.code()),
        }
    }
}

fn status_from_code(code: ErrorCode) -> StatusCode {
    match code {
        ErrorCode::InvalidInput | ErrorCode::ParseError => StatusCode::BAD_REQUEST,
        ErrorCode::NotFound => StatusCode::NOT_FOUND,
        _ => StatusCode::INTERNAL_SERVER_ERROR,
    }
}

impl UserFacingError for ApiError {
    fn code(&self) -> ErrorCode {
        match self {
            ApiError::BadRequest { .. } => ErrorCode::ParseError,
            ApiError::NotFound { .. } => ErrorCode::NotFound,
            ApiError::Conflict { .. } => ErrorCode::InvalidInput,
            ApiError::Config { .. } => ErrorCode::ConfigError,
            ApiError::ExternalLink { .. } => ErrorCode::ExternalLinkError,
            ApiError::Http { .. } => ErrorCode::ExternalLinkError,
            ApiError::Internal { .. } => ErrorCode::InternalError,
            ApiError::Core(err) => err.code(),
            ApiError::Action(err) => err.code(),
        }
    }

    fn user_message(&self) -> String {
        match self {
            ApiError::BadRequest { message } => message.to_string(),
            ApiError::NotFound { .. } => "The requested item was not found.".to_string(),
            ApiError::Conflict { message } => message.to_string(),
            ApiError::Config { .. } => "Configuration could not be loaded.".to_string(),
            ApiError::ExternalLink { .. } => "External link operation failed.".to_string(),
            ApiError::Http { .. } => "External service error.".to_string(),
            ApiError::Internal { .. } => "Unexpected error. Please try again.".to_string(),
            ApiError::Core(err) => err.user_message(),
            ApiError::Action(err) => err.user_message(),
        }
    }

    fn developer_message(&self) -> String {
        match self {
            ApiError::Core(err) => err.developer_message(),
            ApiError::Action(err) => err.developer_message(),
            _ => self.to_string(),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        let payload = ApiErrorResponse {
            code: self.code().as_str().to_string(),
            user_message: self.user_message(),
            developer_message: self.developer_message(),
        };
        (self.status(), Json(payload)).into_response()
    }
}
