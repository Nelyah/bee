# Error Handling

**Read this when:** Working with errors, adding new error types, or understanding the error hierarchy.

## Error Hierarchy

```
CoreError (bee-core)
    │
    ├── ActionError (bee-actions)
    │       │
    │       └── CliError (bee-cli)
    │
    └── ApiError (bee-api)
            │
            └── HTTP Status Codes
```

## CoreError

The foundation error type in `bee-core`:

```rust
// crates/bee-core/src/lib.rs

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
```

## UserFacingError Trait

All error types implement this trait for consistent user-facing messages:

```rust
pub trait UserFacingError {
    /// Stable machine-readable code
    fn code(&self) -> ErrorCode;

    /// Human-friendly message for users
    fn user_message(&self) -> String;

    /// Technical details for developers
    fn developer_message(&self) -> String;
}
```

### ErrorCode Enum

```rust
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
```

### Implementation Example

```rust
impl UserFacingError for CoreError {
    fn code(&self) -> ErrorCode {
        match self {
            Self::Parse { .. } => ErrorCode::ParseError,
            Self::NotFound { .. } => ErrorCode::NotFound,
            Self::Storage { .. } => ErrorCode::StorageError,
            // ...
        }
    }

    fn user_message(&self) -> String {
        match self {
            Self::NotFound { message } => format!("Could not find: {}", message),
            Self::Parse { message } => format!("Invalid input: {}", message),
            // ...
        }
    }

    fn developer_message(&self) -> String {
        // Full technical details
        format!("{:?}", self)
    }
}
```

## ActionError

Wraps CoreError for the action layer:

```rust
// crates/bee-actions/src/lib.rs

#[derive(Debug, thiserror::Error)]
pub enum ActionError {
    #[error("Input error: {0}")]
    Input(#[from] CoreError),

    #[error("Execution error: {message}")]
    Execution { message: String },
}

impl UserFacingError for ActionError {
    fn code(&self) -> ErrorCode {
        match self {
            Self::Input(core) => core.code(),
            Self::Execution { .. } => ErrorCode::ActionError,
        }
    }
    // ...
}
```

## CliError

CLI-specific errors:

```rust
// crates/bee-cli/src/error_type.rs

#[derive(Debug, thiserror::Error)]
pub enum CliError {
    #[error("Config error: {0}")]
    Config(#[from] CoreError),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Action error: {0}")]
    Action(#[from] ActionError),
}
```

## ApiError

Maps errors to HTTP status codes:

```rust
// crates/bee-api/src/error_type.rs

#[derive(Debug, thiserror::Error)]
pub enum ApiError {
    #[error("Bad request: {message}")]
    BadRequest { message: String },

    #[error("Not found: {message}")]
    NotFound { message: String },

    #[error("Conflict: {message}")]
    Conflict { message: String },

    #[error("Internal error: {message}")]
    Internal { message: String },
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let status = match &self {
            Self::BadRequest { .. } => StatusCode::BAD_REQUEST,
            Self::NotFound { .. } => StatusCode::NOT_FOUND,
            Self::Conflict { .. } => StatusCode::CONFLICT,
            Self::Internal { .. } => StatusCode::INTERNAL_SERVER_ERROR,
        };

        let body = Json(ErrorResponse {
            code: self.code().to_string(),
            message: self.user_message(),
        });

        (status, body).into_response()
    }
}
```

## Error Propagation

Use `?` operator for propagation:

```rust
// In bee-core
fn load_config() -> Result<Config, CoreError> {
    let content = std::fs::read_to_string(&path)
        .map_err(|e| CoreError::Config {
            message: format!("Failed to read config: {}", e)
        })?;

    let config: Config = toml::from_str(&content)
        .map_err(|e| CoreError::Config {
            message: format!("Invalid config format: {}", e)
        })?;

    Ok(config)
}

// In bee-actions
fn do_action(&self) -> Result<(), ActionError> {
    let config = load_config()?;  // CoreError auto-converts to ActionError
    // ...
}

// In bee-cli
fn main() -> Result<(), CliError> {
    let result = action.do_action()?;  // ActionError auto-converts to CliError
    // ...
}
```

## Creating New Error Types

### Step 1: Add Variant to Appropriate Enum

```rust
// In CoreError
#[error("New error type: {message}")]
NewError { message: String, code: i32 },
```

### Step 2: Implement UserFacingError

```rust
fn code(&self) -> ErrorCode {
    match self {
        Self::NewError { .. } => ErrorCode::NewErrorCode,
        // ...
    }
}

fn user_message(&self) -> String {
    match self {
        Self::NewError { message, .. } => {
            format!("Something went wrong: {}", message)
        }
        // ...
    }
}
```

### Step 3: Add ErrorCode (if needed)

```rust
pub enum ErrorCode {
    // ...
    NewErrorCode,
}
```

## Best Practices

### Do

```rust
// Provide context in error messages
CoreError::NotFound {
    message: format!("Task with UUID {} not found", uuid)
}

// Use specific error variants
CoreError::Parse { message: "Invalid date format".into() }

// Convert errors at layer boundaries
impl From<SeaOrm::DbErr> for CoreError {
    fn from(err: DbErr) -> Self {
        CoreError::Storage { message: err.to_string() }
    }
}
```

### Don't

```rust
// Don't use generic errors
CoreError::Internal { message: "Error".into() }  // Too vague

// Don't panic in library code
unwrap();  // Use ? instead

// Don't lose error context
.map_err(|_| CoreError::Internal { message: "Failed".into() })  // Lost original error
```

## Testing Errors

```rust
#[test]
fn test_error_handling() {
    let result = some_function_that_fails();

    assert!(result.is_err());
    let err = result.unwrap_err();

    assert_eq!(err.code(), ErrorCode::NotFound);
    assert!(err.user_message().contains("not found"));
}

#[test]
fn test_error_conversion() {
    let core_err = CoreError::NotFound { message: "test".into() };
    let action_err: ActionError = core_err.into();

    assert_eq!(action_err.code(), ErrorCode::NotFound);
}
```
