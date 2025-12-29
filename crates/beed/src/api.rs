use crate::{
    dto::{ActionRequest, ActionResponse, ApiTask, ParseRequest, ParseResponse},
    parse::{parse_input, tokenize_with_spans},
    printer::JsonPrinter,
};
use axum::{
    Json, Router,
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
};
use bee_actions::{ActionRegistry, command_parser::ParsedCommand};
use bee_core::{
    config::ReportConfig, filters::Filter, storage::AsyncStore, storage::db::DbStore,
    task::TaskProperties,
};
use serde::Serialize;
use serde_json::Value;
use std::collections::HashSet;

#[derive(Clone)]
pub struct AppState {
    undo_count: usize,
    report: ReportConfig,
}

impl AppState {
    /// Build API state with default report and undo configuration.
    pub fn new() -> Self {
        Self {
            undo_count: 1,
            report: ReportConfig::default(),
        }
    }
}

#[derive(Debug)]
struct ApiError {
    status: StatusCode,
    message: String,
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    error: String,
}

impl ApiError {
    fn bad_request(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_REQUEST,
            message: message.into(),
        }
    }

    fn internal(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::INTERNAL_SERVER_ERROR,
            message: message.into(),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        let payload = ErrorResponse {
            error: self.message,
        };
        (self.status, Json(payload)).into_response()
    }
}

/// Build the router for the beed API service.
pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/api/health", get(health_handler))
        .route("/api/action", post(action_handler))
        .route("/api/parse", post(parse_handler))
        .with_state(state)
}

async fn health_handler() -> &'static str {
    "ok"
}

async fn parse_handler(Json(payload): Json<ParseRequest>) -> Result<Json<ParseResponse>, ApiError> {
    let parsed = parse_input(&payload.input).map_err(ApiError::bad_request)?;
    let tokens = tokenize_with_spans(&payload.input).map_err(ApiError::bad_request)?;
    let properties_value = serialize_properties(parsed.properties)?;
    let filter_value = serialize_filter(parsed.filter)?;

    Ok(Json(ParseResponse {
        action: parsed.action,
        properties: properties_value,
        filter: filter_value,
        tokens,
    }))
}

async fn action_handler(
    State(state): State<AppState>,
    Json(payload): Json<ActionRequest>,
) -> Result<Json<ActionResponse>, ApiError> {
    let action_name = payload.action.trim();
    if action_name.is_empty() {
        return Err(ApiError::bad_request("action name is required"));
    }

    let valid_actions = valid_action_names();
    if !valid_actions.contains(action_name) {
        return Err(ApiError::bad_request(format!(
            "unknown action '{}'",
            action_name
        )));
    }

    if !is_api_action_allowed(action_name) {
        return Err(ApiError::bad_request(format!(
            "action '{}' is not enabled for the API",
            action_name
        )));
    }

    let properties = deserialize_properties(payload.properties)?;
    let props_for_load = properties.clone();
    let filter_for_load = deserialize_filter(payload.filter)?;

    let undos = DbStore::load_undos(state.undo_count)
        .await
        .map_err(|err| ApiError::internal(format!("Failed to load undos: {err}")))?;

    let mut tasks = DbStore::load_tasks(filter_for_load, props_for_load)
        .await
        .map_err(|err| ApiError::internal(format!("Failed to load tasks: {err}")))?;

    for undo_action in &undos {
        tasks.set_undos(&undo_action.tasks);
    }

    let mut action = ActionRegistry::get_action_from_command_parser(&ParsedCommand {
        command: action_name.to_string(),
        report_kind: state.report.clone(),
        ..Default::default()
    });

    if let Some(properties) = properties {
        action.set_properties(properties);
    }

    action.set_tasks(tasks);
    action.set_undos(undos);

    let printer = JsonPrinter::new();
    action.do_action(&printer).map_err(ApiError::bad_request)?;

    DbStore::write_tasks(action.get_tasks())
        .await
        .map_err(|err| ApiError::internal(format!("Failed to write tasks: {err}")))?;

    DbStore::log_undo(state.undo_count, action.get_undos().to_owned())
        .await
        .map_err(|err| ApiError::internal(format!("Failed to log undo: {err}")))?;

    let tasks = action.get_tasks().to_vec();
    let tasks = tasks.into_iter().map(ApiTask::from_task).collect();

    Ok(Json(ActionResponse {
        action: action_name.to_string(),
        tasks,
        events: printer.take_events(),
    }))
}

fn valid_action_names() -> HashSet<String> {
    ActionRegistry::get_parsed_commands()
        .into_iter()
        .map(|cmd| cmd.command)
        .collect()
}

fn is_api_action_allowed(action: &str) -> bool {
    matches!(
        action,
        "add" | "list" | "modify" | "done" | "delete" | "start" | "stop" | "annotate"
    )
}

fn deserialize_filter(filter: Option<Value>) -> Result<Option<Box<dyn Filter>>, ApiError> {
    match filter {
        Some(value) => serde_json::from_value(value)
            .map(Some)
            .map_err(|err| ApiError::bad_request(format!("invalid filter: {err}"))),
        None => Ok(None),
    }
}

fn serialize_filter(filter: Option<Box<dyn Filter>>) -> Result<Option<Value>, ApiError> {
    match filter {
        Some(filter) => serde_json::to_value(filter)
            .map(Some)
            .map_err(|err| ApiError::internal(format!("failed to serialize filter: {err}"))),
        None => Ok(None),
    }
}

fn deserialize_properties(properties: Option<Value>) -> Result<Option<TaskProperties>, ApiError> {
    match properties {
        Some(value) => serde_json::from_value(value)
            .map(Some)
            .map_err(|err| ApiError::bad_request(format!("invalid properties: {err}"))),
        None => Ok(None),
    }
}

fn serialize_properties(properties: Option<TaskProperties>) -> Result<Option<Value>, ApiError> {
    match properties {
        Some(properties) => serde_json::to_value(properties)
            .map(Some)
            .map_err(|err| ApiError::internal(format!("failed to serialize properties: {err}"))),
        None => Ok(None),
    }
}
