use crate::external_links;
use crate::{
    config::ApiConfig,
    dto::{
        ActionRequest, ActionResponse, ApiEvent, ApiTask, ApiTaskDetail, CompletionItem,
        CompletionsResponse, ConfigResponse, ExternalLinkCreateRequest, ExternalLinkDto,
        ExternalLinkResolveRequest, ExternalLinkResolveResponse, ExternalLinkSyncRequest,
        ExternalLinkSyncResponse, GitlabMergeRequestDto, JiraIssueDto, ParseRequest, ParseResponse,
        ReportConfigDto, ReportSummary, TaskAnnotationDto, TaskHistoryDto, TokenSpan,
    },
    error_type::{ApiError, ApiErrorResponse, ApiResult},
    parse::{parse_input, tokenize_with_spans},
    printer::JsonPrinter,
};
use axum::{
    Json, Router,
    extract::{Path, Query, State},
    http::StatusCode,
    routing::{delete, get, post},
};
use bee_actions::{ActionRegistry, command_parser::ParsedCommand};
use bee_core::{
    config::ReportConfig, filters::Filter, storage::AsyncStore, storage::db::DbStore,
    task::TaskProperties,
};
use serde::Deserialize;
use serde_json::Value;
use std::{collections::HashSet, time::Duration};
use tower_http::trace::TraceLayer;
use tracing::Span;
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;
use uuid::Uuid;

/// Shared application state for request handlers.
#[derive(Clone)]
pub struct AppState {
    undo_count: usize,
    report: ReportConfig,
    allowed_actions: HashSet<String>,
    external_links: bee_core::config::ExternalLinksConfig,
    external_links_sync: crate::config::SyncConfig,
    http_client: reqwest::Client,
}

impl AppState {
    /// Build API state from configuration.
    pub fn from_config(config: ApiConfig) -> Self {
        Self {
            undo_count: config.undo_count,
            report: config.report,
            allowed_actions: config.allowed_actions.into_iter().collect(),
            external_links: bee_core::config::get_config().external_links.clone(),
            external_links_sync: config.external_links.sync,
            http_client: reqwest::Client::new(),
        }
    }
}

/// Build the router for the bee-api service.
pub fn router(state: AppState) -> Router {
    let openapi = ApiDoc::openapi();
    Router::new()
        .route("/v1/health", get(health_handler))
        .route("/v1/config", get(config_handler))
        .route("/v1/completions", get(completions_handler))
        .route("/v1/action", post(action_handler))
        .route("/v1/parse", post(parse_handler))
        .route("/v1/tasks/:task_uuid", get(task_detail_handler))
        .route(
            "/v1/tasks/:task_uuid/external-links",
            get(list_external_links_handler).post(create_external_link_handler),
        )
        .route(
            "/v1/external-links/:link_id",
            delete(delete_external_link_handler),
        )
        .route(
            "/v1/external-links/:link_id/sync",
            post(sync_external_link_handler),
        )
        .route("/v1/external-links/sync", post(sync_external_links_handler))
        .route(
            "/v1/external-links/gitlab/merge-requests/recent",
            get(recent_gitlab_merge_requests_handler),
        )
        .route(
            "/v1/external-links/jira/issues/recent",
            get(recent_jira_issues_handler),
        )
        .route(
            "/v1/external-links/resolve",
            post(resolve_external_link_handler),
        )
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
    let core_config = bee_core::config::get_config();
    let default_report_name = &core_config.default_report;

    let reports: Vec<ReportSummary> = core_config
        .get_all_reports()
        .map(|(name, report)| ReportSummary {
            name: name.to_string(),
            filters: report.filters.clone(),
            columns: report.columns.clone(),
            column_names: report.column_names.clone(),
            is_default: name == default_report_name,
        })
        .collect();

    Json(ConfigResponse {
        report: ReportConfigDto {
            filters: state.report.filters.clone(),
            columns: state.report.columns.clone(),
            column_names: state.report.column_names.clone(),
        },
        reports,
    })
}

#[utoipa::path(
    get,
    path = "/v1/tasks/{task_uuid}",
    params(
        ("task_uuid" = String, Path, description = "Task UUID")
    ),
    responses(
        (status = 200, description = "Task detail payload", body = ApiTaskDetail),
        (status = 404, description = "Task not found", body = ApiErrorResponse)
    )
)]
async fn task_detail_handler(Path(task_uuid): Path<Uuid>) -> ApiResult<Json<ApiTaskDetail>> {
    let Some(task) = DbStore::get_task_by_uuid(task_uuid).await? else {
        return Err(ApiError::not_found("Task not found"));
    };
    Ok(Json(ApiTaskDetail::from_task(&task)))
}

/// Query parameters for the completions endpoint.
#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct CompletionsQuery {
    /// Type of completions to return: projects, tags, actions, status, dates
    #[serde(rename = "type")]
    completion_type: String,
}

#[utoipa::path(
    get,
    path = "/v1/completions",
    params(CompletionsQuery),
    responses(
        (status = 200, description = "Completion suggestions", body = CompletionsResponse),
        (status = 400, description = "Invalid completion type", body = ApiErrorResponse)
    )
)]
async fn completions_handler(
    Query(query): Query<CompletionsQuery>,
) -> ApiResult<Json<CompletionsResponse>> {
    let items = match query.completion_type.as_str() {
        "projects" => {
            let rows = DbStore::get_projects().await?;
            rows.into_iter()
                .map(|r| CompletionItem {
                    value: r.value,
                    count: Some(r.count),
                })
                .collect()
        }
        "tags" => {
            let rows = DbStore::get_tags().await?;
            rows.into_iter()
                .map(|r| CompletionItem {
                    value: r.value,
                    count: Some(r.count),
                })
                .collect()
        }
        "actions" => {
            let commands = ActionRegistry::get_parsed_commands();
            commands
                .into_iter()
                .map(|cmd| CompletionItem {
                    value: cmd.command,
                    count: None,
                })
                .collect()
        }
        "status" => vec![
            CompletionItem {
                value: "pending".to_string(),
                count: None,
            },
            CompletionItem {
                value: "active".to_string(),
                count: None,
            },
            CompletionItem {
                value: "done".to_string(),
                count: None,
            },
            CompletionItem {
                value: "deleted".to_string(),
                count: None,
            },
        ],
        "dates" => vec![
            CompletionItem {
                value: "today".to_string(),
                count: None,
            },
            CompletionItem {
                value: "tomorrow".to_string(),
                count: None,
            },
            CompletionItem {
                value: "yesterday".to_string(),
                count: None,
            },
            CompletionItem {
                value: "monday".to_string(),
                count: None,
            },
            CompletionItem {
                value: "tuesday".to_string(),
                count: None,
            },
            CompletionItem {
                value: "wednesday".to_string(),
                count: None,
            },
            CompletionItem {
                value: "thursday".to_string(),
                count: None,
            },
            CompletionItem {
                value: "friday".to_string(),
                count: None,
            },
            CompletionItem {
                value: "saturday".to_string(),
                count: None,
            },
            CompletionItem {
                value: "sunday".to_string(),
                count: None,
            },
            CompletionItem {
                value: "eow".to_string(),
                count: None,
            },
            CompletionItem {
                value: "eom".to_string(),
                count: None,
            },
        ],
        other => {
            return Err(ApiError::bad_request(format!(
                "Invalid completion type '{}'. Valid types: projects, tags, actions, status, dates",
                other
            )));
        }
    };

    Ok(Json(CompletionsResponse { items }))
}

#[utoipa::path(
    get,
    path = "/v1/tasks/{task_uuid}/external-links",
    params(
        ("task_uuid" = String, Path, description = "Task UUID")
    ),
    responses(
        (status = 200, description = "External links for a task", body = [ExternalLinkDto])
    )
)]
async fn list_external_links_handler(
    Path(task_uuid): Path<Uuid>,
) -> ApiResult<Json<Vec<ExternalLinkDto>>> {
    let links = DbStore::list_external_links_by_task(task_uuid).await?;

    Ok(Json(
        links.into_iter().map(ExternalLinkDto::from_link).collect(),
    ))
}

#[utoipa::path(
    post,
    path = "/v1/tasks/{task_uuid}/external-links",
    request_body = ExternalLinkCreateRequest,
    params(
        ("task_uuid" = String, Path, description = "Task UUID")
    ),
    responses(
        (status = 200, description = "External link created", body = ExternalLinkDto),
        (status = 400, description = "Invalid link", body = ApiErrorResponse)
    )
)]
async fn create_external_link_handler(
    State(state): State<AppState>,
    Path(task_uuid): Path<Uuid>,
    Json(payload): Json<ExternalLinkCreateRequest>,
) -> ApiResult<Json<ExternalLinkDto>> {
    let parsed = external_links::parse_external_link(&payload.url, &state.external_links)?;

    let existing = DbStore::list_external_links_by_task(task_uuid).await?;
    let provider = parsed.provider.to_string();
    if existing
        .iter()
        .any(|link| link.provider == provider && link.external_key == parsed.external_key)
    {
        let message = if parsed.provider == external_links::ProviderKind::Gitlab {
            "Merge Request is already linked to this task"
        } else {
            "Link is already linked to this task"
        };
        return Err(ApiError::bad_request(message));
    }

    let link = DbStore::insert_external_link(task_uuid, provider, payload.url, parsed.external_key)
        .await?;

    Ok(Json(ExternalLinkDto::from_link(link)))
}

#[utoipa::path(
    delete,
    path = "/v1/external-links/{link_id}",
    params(
        ("link_id" = i32, Path, description = "External link id")
    ),
    responses(
        (status = 200, description = "External link deleted")
    )
)]
async fn delete_external_link_handler(Path(link_id): Path<i32>) -> ApiResult<StatusCode> {
    DbStore::delete_external_link_by_id(link_id).await?;
    Ok(StatusCode::OK)
}

#[utoipa::path(
    post,
    path = "/v1/external-links/{link_id}/sync",
    params(
        ("link_id" = i32, Path, description = "External link id"),
        ("force" = bool, Query, description = "Force sync")
    ),
    responses(
        (status = 200, description = "Sync result", body = ExternalLinkSyncResponse),
        (status = 400, description = "Sync error", body = ApiErrorResponse)
    )
)]
async fn sync_external_link_handler(
    State(state): State<AppState>,
    Path(link_id): Path<i32>,
    Query(query): Query<external_links::SyncQuery>,
) -> ApiResult<Json<ExternalLinkSyncResponse>> {
    let Some(link) = DbStore::get_external_link_by_id(link_id).await? else {
        return Err(ApiError::not_found("External link not found"));
    };

    let result = external_links::sync_single_link(
        &state.http_client,
        &state.external_links,
        &state.external_links_sync,
        link,
        query.force.unwrap_or(false),
    )
    .await?;

    Ok(Json(result))
}

#[utoipa::path(
    post,
    path = "/v1/external-links/sync",
    request_body = ExternalLinkSyncRequest,
    responses(
        (status = 200, description = "Batch sync result", body = ExternalLinkSyncResponse),
        (status = 400, description = "Sync error", body = ApiErrorResponse)
    )
)]
async fn sync_external_links_handler(
    State(state): State<AppState>,
    Json(payload): Json<ExternalLinkSyncRequest>,
) -> ApiResult<Json<ExternalLinkSyncResponse>> {
    let result = external_links::sync_links_batch(
        &state.http_client,
        &state.external_links,
        &state.external_links_sync,
        payload.provider.as_deref(),
        payload.task_uuid,
        payload.force.unwrap_or(false),
    )
    .await?;

    Ok(Json(result))
}

#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct RecentGitlabQuery {
    /// Max number of merge requests
    pub limit: Option<usize>,
}

#[utoipa::path(
    get,
    path = "/v1/external-links/gitlab/merge-requests/recent",
    params(RecentGitlabQuery),
    responses(
        (status = 200, description = "Recent merge requests", body = [GitlabMergeRequestDto]),
        (status = 400, description = "GitLab error", body = ApiErrorResponse)
    )
)]
async fn recent_gitlab_merge_requests_handler(
    State(state): State<AppState>,
    Query(query): Query<RecentGitlabQuery>,
) -> ApiResult<Json<Vec<GitlabMergeRequestDto>>> {
    let limit = query.limit.unwrap_or(20);
    let items = external_links::fetch_recent_gitlab_merge_requests(
        &state.http_client,
        &state.external_links,
        limit,
    )
    .await?;
    Ok(Json(items))
}

#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct RecentJiraQuery {
    /// Max number of issues
    pub limit: Option<usize>,
    /// Scope: assigned, created, or both
    pub scope: Option<String>,
}

#[utoipa::path(
    get,
    path = "/v1/external-links/jira/issues/recent",
    params(RecentJiraQuery),
    responses(
        (status = 200, description = "Recent Jira issues", body = [JiraIssueDto]),
        (status = 400, description = "Jira error", body = ApiErrorResponse)
    )
)]
async fn recent_jira_issues_handler(
    State(state): State<AppState>,
    Query(query): Query<RecentJiraQuery>,
) -> ApiResult<Json<Vec<JiraIssueDto>>> {
    let limit = query.limit.unwrap_or(20);
    let scope = match query.scope.as_deref() {
        Some("assigned") => external_links::JiraIssueScope::Assigned,
        Some("created") => external_links::JiraIssueScope::Created,
        _ => external_links::JiraIssueScope::Both,
    };
    let items = external_links::fetch_recent_jira_issues(
        &state.http_client,
        &state.external_links,
        limit,
        scope,
    )
    .await?;
    Ok(Json(items))
}

#[utoipa::path(
    post,
    path = "/v1/external-links/resolve",
    request_body = ExternalLinkResolveRequest,
    responses(
        (status = 200, description = "Resolved link", body = ExternalLinkResolveResponse),
        (status = 400, description = "Resolve error", body = ApiErrorResponse)
    )
)]
async fn resolve_external_link_handler(
    State(state): State<AppState>,
    Json(payload): Json<ExternalLinkResolveRequest>,
) -> ApiResult<Json<ExternalLinkResolveResponse>> {
    let provider = match payload.provider.as_str() {
        "jira" => external_links::ProviderKind::Jira,
        "gitlab" => external_links::ProviderKind::Gitlab,
        _ => return Err(ApiError::bad_request("Unknown provider")),
    };

    let resolved = external_links::resolve_external_link(
        &state.http_client,
        &state.external_links,
        provider,
        &payload.input,
    )
    .await?;

    Ok(Json(resolved))
}

#[utoipa::path(
    post,
    path = "/v1/parse",
    request_body = ParseRequest,
    responses(
        (status = 200, description = "Parsed input", body = ParseResponse),
        (status = 400, description = "Invalid input", body = ApiErrorResponse)
    )
)]
async fn parse_handler(Json(payload): Json<ParseRequest>) -> ApiResult<Json<ParseResponse>> {
    let parsed = parse_input(&payload.input)?;
    let tokens = tokenize_with_spans(&payload.input)?;
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
        (status = 400, description = "Invalid request", body = ApiErrorResponse),
        (status = 500, description = "Server error", body = ApiErrorResponse)
    )
)]
async fn action_handler(
    State(state): State<AppState>,
    Json(payload): Json<ActionRequest>,
) -> ApiResult<Json<ActionResponse>> {
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

    let undos = DbStore::load_undos(state.undo_count).await?;

    let mut tasks = DbStore::load_tasks(filter_for_load, props_for_load).await?;

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
    action.do_action(&printer)?;

    DbStore::write_tasks(action.get_tasks()).await?;

    DbStore::log_undo(state.undo_count, action.get_undos().to_owned()).await?;

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

fn deserialize_filter(filter: Option<Value>) -> ApiResult<Option<Box<dyn Filter>>> {
    match filter {
        Some(value) => serde_json::from_value(value)
            .map(Some)
            .map_err(|err| ApiError::bad_request(format!("invalid filter: {err}"))),
        None => Ok(None),
    }
}

fn serialize_filter(filter: Option<Box<dyn Filter>>) -> ApiResult<Option<Value>> {
    match filter {
        Some(filter) => serde_json::to_value(filter)
            .map(Some)
            .map_err(|err| ApiError::internal(format!("failed to serialize filter: {err}"))),
        None => Ok(None),
    }
}

fn deserialize_properties(properties: Option<Value>) -> ApiResult<Option<TaskProperties>> {
    match properties {
        Some(value) => serde_json::from_value(value)
            .map(Some)
            .map_err(|err| ApiError::bad_request(format!("invalid properties: {err}"))),
        None => Ok(None),
    }
}

fn serialize_properties(properties: Option<TaskProperties>) -> ApiResult<Option<Value>> {
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
    paths(
        health_handler,
        config_handler,
        completions_handler,
        parse_handler,
        action_handler,
        task_detail_handler,
        list_external_links_handler,
        create_external_link_handler,
        delete_external_link_handler,
        sync_external_link_handler,
        sync_external_links_handler,
        recent_gitlab_merge_requests_handler,
        recent_jira_issues_handler,
        resolve_external_link_handler
    ),
    components(schemas(
        ActionRequest,
        ActionResponse,
        ParseRequest,
        ParseResponse,
        ConfigResponse,
        ExternalLinkCreateRequest,
        ExternalLinkDto,
        ExternalLinkResolveRequest,
        ExternalLinkResolveResponse,
        ExternalLinkSyncRequest,
        ExternalLinkSyncResponse,
        GitlabMergeRequestDto,
        JiraIssueDto,
        ReportConfigDto,
        ReportSummary,
        CompletionsResponse,
        CompletionItem,
        ApiTask,
        ApiTaskDetail,
        ApiEvent,
        TaskAnnotationDto,
        TaskHistoryDto,
        TokenSpan,
        ApiErrorResponse
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
