use crate::{
    config::ApiConfig,
    dto::{
        ActionRequest, ActionResponse, ApiEvent, ApiTask, ConfigResponse, ParseRequest,
        ParseResponse, ReportConfigDto, TokenSpan,
    },
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
use std::{collections::HashSet, time::Duration};
use tower_http::trace::TraceLayer;
use tracing::Span;
use utoipa::{OpenApi, ToSchema};
use utoipa_swagger_ui::SwaggerUi;

/// Shared application state for request handlers.
#[derive(Clone)]
pub struct AppState {
    undo_count: usize,
    report: ReportConfig,
    allowed_actions: HashSet<String>,
}

impl AppState {
    /// Build API state from configuration.
    pub fn from_config(config: ApiConfig) -> Self {
        Self {
            undo_count: config.undo_count,
            report: config.report,
            allowed_actions: config.allowed_actions.into_iter().collect(),
        }
    }
}

/// Error type returned by API handlers.
#[derive(Debug)]
struct ApiError {
    status: StatusCode,
    message: String,
}

/// Error payload returned on API failures.
#[derive(Debug, Serialize, ToSchema)]
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

/// Build the router for the bee-api service.
pub fn router(state: AppState) -> Router {
    let openapi = ApiDoc::openapi();
    Router::new()
        .route("/v1/health", get(health_handler))
        .route("/v1/config", get(config_handler))
        .route("/v1/action", post(action_handler))
        .route("/v1/parse", post(parse_handler))
        .merge(SwaggerUi::new("/v1/docs").url("/v1/openapi.json", openapi))
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(make_span)
                .on_response(trace_response),
        )
        .with_state(state)
}

fn make_span<B>(request: &axum::http::Request<B>) -> Span {
    log::info!("{} {}", request.method(), request.uri().path());
    log::debug!("request headers: {:?}", request.headers());
    Span::none()
}

fn trace_response<B>(response: &axum::http::Response<B>, latency: Duration, _span: &Span) {
    log::info!("response {} in {:?}", response.status(), latency);
    log::debug!("response headers: {:?}", response.headers());
}

#[utoipa::path(
    get,
    path = "/v1/health",
    responses((status = 200, description = "Service health check", body = String))
)]
async fn health_handler() -> &'static str {
    "ok"
}


#[utoipa::path(
    get,
    path = "/v1/config",
    responses((status = 200, description = "Current report configuration", body = ConfigResponse))
)]
async fn config_handler(State(state): State<AppState>) -> Json<ConfigResponse> {
    Json(ConfigResponse {
        report: ReportConfigDto {
            filters: state.report.filters.clone(),
            columns: state.report.columns.clone(),
            column_names: state.report.column_names.clone(),
        },
    })
}

#[utoipa::path(
    post,
    path = "/v1/parse",
    request_body = ParseRequest,
    responses(
        (status = 200, description = "Parsed input", body = ParseResponse),
        (status = 400, description = "Invalid input", body = ErrorResponse)
    )
)]
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

#[utoipa::path(
    post,
    path = "/v1/action",
    request_body = ActionRequest,
    responses(
        (status = 200, description = "Action result", body = ActionResponse),
        (status = 400, description = "Invalid request", body = ErrorResponse),
        (status = 500, description = "Server error", body = ErrorResponse)
    )
)]
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

    if !is_api_action_allowed(&state, action_name) {
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

fn is_api_action_allowed(state: &AppState, action: &str) -> bool {
    state.allowed_actions.contains(action)
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

/// OpenAPI document for the bee-api service.
#[derive(OpenApi)]
#[openapi(
    paths(health_handler, config_handler, parse_handler, action_handler),
    components(schemas(
        ActionRequest,
        ActionResponse,
        ParseRequest,
        ParseResponse,
        ConfigResponse,
        ReportConfigDto,
        ApiTask,
        ApiEvent,
        TokenSpan,
        ErrorResponse
    )),
    tags((name = "bee-api", description = "Bee REST API"))
)]
struct ApiDoc;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::ApiConfig;
    use axum::body::Body;
    use bee_core::{filters, task::TaskProperties};
    use http_body_util::BodyExt;
    use serde_json::json;
    use tower::ServiceExt;

    #[tokio::test]
    async fn test_health_endpoint() {
        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);
        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/health")
                    .method("GET")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .expect("health response");

        assert_eq!(response.status(), StatusCode::OK);
        let body = response.into_body().collect().await.unwrap().to_bytes();
        assert_eq!(std::str::from_utf8(&body).unwrap(), "ok");
    }

    #[tokio::test]
    async fn test_parse_endpoint() {
        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);
        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/parse")
                    .method("POST")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&json!({ "input": "add hello" })).unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .expect("parse response");

        assert_eq!(response.status(), StatusCode::OK);
        let body = response.into_body().collect().await.unwrap().to_bytes();
        let parsed: ParseResponse = serde_json::from_slice(&body).unwrap();
        assert_eq!(parsed.action, "add");
        assert!(parsed.properties.is_some());
    }

    #[tokio::test]
    async fn test_action_rejects_unknown_action() {
        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);
        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/action")
                    .method("POST")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&json!({ "action": "nope" })).unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .expect("action response");

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[test]
    fn test_filter_roundtrip() {
        let filter = filters::from(&["status:pending".to_string()]).unwrap();
        let serialized = serialize_filter(Some(filter)).unwrap();
        let deserialized = deserialize_filter(serialized).unwrap();
        assert!(deserialized.is_some());
    }

    #[test]
    fn test_properties_roundtrip() {
        let props = TaskProperties::from(&["summary +tag".to_string()]).unwrap();
        let serialized = serialize_properties(Some(props.clone())).unwrap();
        let deserialized = deserialize_properties(serialized).unwrap();
        assert_eq!(deserialized, Some(props));
    }
}
