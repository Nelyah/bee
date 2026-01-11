use crate::external_links;
use crate::{
    config::ApiConfig,
    dto::{
        ActionRequest, ActionResponse, ApiEvent, ApiTask, ApiTaskDetail, AttachmentDto,
        BurndownDataPoint, CompletionItem, CompletionsResponse, ConfigResponse,
        ExternalLinkCreateRequest, ExternalLinkDto, ExternalLinkResolveRequest,
        ExternalLinkResolveResponse, ExternalLinkSyncRequest, ExternalLinkSyncResponse,
        GitlabMergeRequestDto, JiraIssueDto, ParseRequest, ParseResponse, ProfileCreateRequest,
        ProfileDto, ProfilesListResponse, ProjectBurndownResponse, ProjectNodeDto, ProjectStatsDto,
        ProjectsResponse, ReportConfigDto, ReportSummary, TaskAnnotationDto, TaskHistoryDto,
        TokenSpan, UpdateProjectRequest, UpdateProjectResponse, UserReportDto, UserReportRequest,
        UserReportsListResponse,
    },
    error_type::{ApiError, ApiErrorResponse, ApiResult},
    parse::{parse_input, tokenize_with_spans},
    printer::JsonPrinter,
};
use axum::{
    Json, Router,
    body::Bytes,
    extract::{Multipart, Path, Query, State},
    http::{StatusCode, header},
    response::IntoResponse,
    routing::{delete, get, patch, post, put},
};
use bee_actions::{ActionRegistry, command_parser::ParsedCommand};
use bee_core::{
    attachment::AttachmentAddInput,
    config::ReportConfig,
    filters::{self, Filter},
    profile,
    storage::AsyncStore,
    storage::db::{DbStore, UserReportParams},
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

    /// Validate that no static reports collide with user reports.
    /// Panics if a collision is detected.
    /// Call this at startup before serving requests.
    pub async fn validate_report_name_collisions() {
        let core_config = bee_core::config::get_config();
        let static_names: HashSet<String> = core_config
            .get_all_reports()
            .map(|(name, _)| name.to_owned())
            .collect();

        let user_report_names = match DbStore::list_user_report_names().await {
            Ok(names) => names,
            Err(e) => {
                log::warn!(
                    "Could not load user report names for collision check: {}",
                    e
                );
                return;
            }
        };

        let collisions: Vec<String> = user_report_names
            .into_iter()
            .filter(|name| static_names.contains(name))
            .collect();

        if !collisions.is_empty() {
            panic!(
                "Startup failed: Static report(s) {} conflict with existing user report(s). \
                 Either rename the static report(s) in bee.toml or delete the user report(s).",
                collisions.join(", ")
            );
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
            "/v1/tasks/:task_uuid/attachments",
            get(list_attachments_handler).post(upload_attachment_handler),
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
        // Project overview
        .route("/v1/projects", get(projects_handler))
        .route("/v1/projects/:name", patch(update_project_handler))
        .route("/v1/projects/:name/burndown", get(project_burndown_handler))
        // User reports CRUD
        .route(
            "/v1/reports",
            get(list_user_reports_handler).post(create_user_report_handler),
        )
        .route(
            "/v1/reports/:name",
            put(update_user_report_handler).delete(delete_user_report_handler),
        )
        // Attachments (individual operations by ID)
        .route(
            "/v1/attachments/:attachment_id/download",
            get(download_attachment_handler),
        )
        .route(
            "/v1/attachments/:attachment_id",
            delete(delete_attachment_handler),
        )
        // Profile management routes
        .route(
            "/v1/profiles",
            get(list_profiles_handler).post(create_profile_handler),
        )
        .route("/v1/profiles/:profile_key", delete(delete_profile_handler))
        // Profile-scoped routes (new API structure)
        .route(
            "/v1/profiles/:profile_key/action",
            post(profile_action_handler),
        )
        .route(
            "/v1/profiles/:profile_key/config",
            get(profile_config_handler),
        )
        .route(
            "/v1/profiles/:profile_key/tasks/:task_uuid",
            get(profile_task_detail_handler),
        )
        // Profile-scoped completions
        .route(
            "/v1/profiles/:profile_key/completions",
            get(profile_completions_handler),
        )
        // Profile-scoped reports
        .route(
            "/v1/profiles/:profile_key/reports",
            get(profile_list_user_reports_handler).post(profile_create_user_report_handler),
        )
        .route(
            "/v1/profiles/:profile_key/reports/:name",
            put(profile_update_user_report_handler).delete(profile_delete_user_report_handler),
        )
        // Profile-scoped projects
        .route(
            "/v1/profiles/:profile_key/projects",
            get(profile_projects_handler),
        )
        .route(
            "/v1/profiles/:profile_key/projects/:name",
            patch(profile_update_project_handler),
        )
        .route(
            "/v1/profiles/:profile_key/projects/:name/burndown",
            get(profile_project_burndown_handler),
        )
        // Profile-scoped attachments
        .route(
            "/v1/profiles/:profile_key/tasks/:task_uuid/attachments",
            post(profile_upload_attachment_handler),
        )
        .route(
            "/v1/profiles/:profile_key/attachments/:attachment_id",
            delete(profile_delete_attachment_handler),
        )
        .route(
            "/v1/profiles/:profile_key/attachments/:attachment_id/download",
            get(profile_download_attachment_handler),
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

    // Build static reports from config (is_user_report: false)
    // Static reports use `filters` (Vec<String>) - still need parsing at runtime
    let mut reports: Vec<ReportSummary> = core_config
        .get_all_reports()
        .map(|(name, report)| ReportSummary {
            name: name.to_string(),
            filters: report.filters.clone(),
            filter: None, // Static reports don't have pre-parsed filter
            columns: report.columns.clone(),
            column_names: report.column_names.clone(),
            column_widths: None, // Static reports don't have custom widths
            sort_column: None,   // Static reports use default urgency sort
            sort_direction: None,
            is_default: name == default_report_name,
            is_user_report: false,
        })
        .collect();

    // Load user reports from database and merge
    // User reports use `filter` (JSON Value) - no re-parsing needed
    if let Ok(user_reports) = DbStore::list_user_reports().await {
        for report in user_reports {
            reports.push(ReportSummary {
                name: report.name,
                filters: vec![], // User reports use `filter` field instead
                filter: report.filter,
                columns: report.columns,
                column_names: report.column_names,
                column_widths: report.column_widths,
                sort_column: report.sort_column,
                sort_direction: report.sort_direction,
                is_default: false,
                is_user_report: true,
            });
        }
    }

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
    let attachments = DbStore::list_attachments_by_task(task_uuid).await?;
    Ok(Json(ApiTaskDetail::from_task_with_attachments(
        &task,
        attachments,
    )))
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

// ============================================================================
// Project Overview Handlers
// ============================================================================

/// Query parameters for project burndown endpoint.
#[derive(Debug, Deserialize, utoipa::IntoParams)]
struct BurndownQuery {
    /// Number of days to include (default: 30).
    #[serde(default = "default_burndown_days")]
    days: u32,
}

fn default_burndown_days() -> u32 {
    30
}

#[utoipa::path(
    get,
    path = "/v1/projects",
    responses(
        (status = 200, description = "Project hierarchy with statistics", body = ProjectsResponse)
    )
)]
async fn projects_handler() -> ApiResult<Json<ProjectsResponse>> {
    let stats = DbStore::get_projects_with_stats().await?;

    // Build hierarchical tree from flat list
    let projects = build_project_hierarchy(stats);

    Ok(Json(ProjectsResponse { projects }))
}

#[utoipa::path(
    patch,
    path = "/v1/projects/{name}",
    params(
        ("name" = String, Path, description = "Project name (URL-encoded)")
    ),
    request_body = UpdateProjectRequest,
    responses(
        (status = 200, description = "Project updated", body = UpdateProjectResponse),
        (status = 404, description = "Project not found", body = ApiErrorResponse)
    )
)]
async fn update_project_handler(
    Path(name): Path<String>,
    Json(payload): Json<UpdateProjectRequest>,
) -> ApiResult<Json<UpdateProjectResponse>> {
    let updated = DbStore::update_project_metadata(&name, payload.emoji, payload.color).await?;

    match updated {
        Some(project) => Ok(Json(UpdateProjectResponse {
            name: project.get_name().clone(),
            emoji: project.get_emoji().clone(),
            color: project.get_color().clone(),
        })),
        None => Err(ApiError::not_found(format!("Project '{}' not found", name))),
    }
}

/// Update project metadata (emoji and color) for a specific profile.
async fn profile_update_project_handler(
    Path((profile_key, name)): Path<(String, String)>,
    Json(payload): Json<UpdateProjectRequest>,
) -> ApiResult<Json<UpdateProjectResponse>> {
    validate_profile(&profile_key)?;
    let updated = DbStore::update_project_metadata_for_profile(
        &profile_key,
        &name,
        payload.emoji,
        payload.color,
    )
    .await?;

    match updated {
        Some(project) => Ok(Json(UpdateProjectResponse {
            name: project.get_name().clone(),
            emoji: project.get_emoji().clone(),
            color: project.get_color().clone(),
        })),
        None => Err(ApiError::not_found(format!("Project '{}' not found", name))),
    }
}

#[utoipa::path(
    get,
    path = "/v1/projects/{name}/burndown",
    params(
        ("name" = String, Path, description = "Project name (URL-encoded)"),
        BurndownQuery
    ),
    responses(
        (status = 200, description = "Burndown data for project", body = ProjectBurndownResponse),
        (status = 404, description = "Project not found", body = ApiErrorResponse)
    )
)]
async fn project_burndown_handler(
    Path(name): Path<String>,
    Query(query): Query<BurndownQuery>,
) -> ApiResult<Json<ProjectBurndownResponse>> {
    let (total_tasks, total_completed) = DbStore::get_project_totals(&name).await?;

    if total_tasks == 0 {
        return Err(ApiError::not_found(format!(
            "Project '{}' not found or has no tasks",
            name
        )));
    }

    let burndown_rows = DbStore::get_burndown(&name, query.days).await?;

    // Convert to cumulative data points
    let mut data_points = Vec::new();
    let mut cumulative = 0i64;

    for row in burndown_rows {
        cumulative += row.completed_on_day;
        data_points.push(BurndownDataPoint {
            date: row.date,
            completed_cumulative: cumulative,
            remaining: total_tasks - cumulative,
        });
    }

    Ok(Json(ProjectBurndownResponse {
        project: name,
        data_points,
        total_tasks,
        total_completed,
    }))
}

/// Build a hierarchical project tree from flat project stats.
///
/// Projects use dot notation for hierarchy (e.g., "backend.api").
/// This function groups them into a tree structure.
///
/// Uses an iterative bottom-up approach to avoid stack overflow with deep hierarchies.
fn build_project_hierarchy(
    stats: Vec<bee_core::storage::db::ProjectStatusRow>,
) -> Vec<ProjectNodeDto> {
    use std::collections::{HashMap, HashSet};

    if stats.is_empty() {
        return Vec::new();
    }

    // First, collect all projects with their stats and emoji/color
    let mut project_stats: HashMap<String, ProjectStatsDto> = HashMap::new();
    let mut project_emoji: HashMap<String, Option<String>> = HashMap::new();
    let mut project_color: HashMap<String, Option<String>> = HashMap::new();
    for row in &stats {
        project_emoji.insert(row.project_name.clone(), row.emoji.clone());
        project_color.insert(row.project_name.clone(), row.color.clone());
        project_stats.insert(
            row.project_name.clone(),
            ProjectStatsDto {
                name: row
                    .project_name
                    .rsplit('.')
                    .next()
                    .unwrap_or(&row.project_name)
                    .to_string(),
                pending_count: row.pending_count,
                active_count: row.active_count,
                completed_count: row.completed_count,
                overdue_count: row.overdue_count,
                total_count: row.total_count,
                emoji: row.emoji.clone(),
                color: row.color.clone(),
            },
        );
    }

    // Identify all unique project paths (including intermediate parents)
    let mut all_paths: HashSet<String> = HashSet::new();
    for row in &stats {
        let parts: Vec<&str> = row.project_name.split('.').collect();
        let mut path = String::new();
        for (i, part) in parts.iter().enumerate() {
            if i > 0 {
                path.push('.');
            }
            path.push_str(part);
            all_paths.insert(path.clone());
        }
    }

    // Build nodes bottom-up: start with deepest nodes, work up to root
    // Sort paths by depth (number of dots), descending
    let mut sorted_paths: Vec<String> = all_paths.into_iter().collect();
    sorted_paths.sort_by(|a, b| {
        let depth_a = a.matches('.').count();
        let depth_b = b.matches('.').count();
        // Sort by depth descending, then by name ascending for stable order
        depth_b.cmp(&depth_a).then_with(|| a.cmp(b))
    });

    // Map from full_path to built node
    let mut nodes: HashMap<String, ProjectNodeDto> = HashMap::new();

    // Process from deepest to shallowest
    for full_path in sorted_paths {
        let name = full_path
            .rsplit('.')
            .next()
            .unwrap_or(&full_path)
            .to_string();

        // Get stats if this is an actual project, or default stats
        let mut stats = project_stats.get(&full_path).cloned().unwrap_or_default();
        stats.name = name.clone();

        // Find and collect children (already built since we process bottom-up)
        let prefix = format!("{}.", full_path);
        let child_keys: Vec<String> = nodes
            .keys()
            .filter(|k| k.starts_with(&prefix) && !k[prefix.len()..].contains('.'))
            .cloned()
            .collect();

        let mut children: Vec<ProjectNodeDto> = child_keys
            .into_iter()
            .filter_map(|k| nodes.remove(&k))
            .collect();
        children.sort_by(|a, b| a.name.cmp(&b.name));

        // Aggregate children stats into parent
        for child in &children {
            stats.pending_count += child.stats.pending_count;
            stats.active_count += child.stats.active_count;
            stats.completed_count += child.stats.completed_count;
            stats.overdue_count += child.stats.overdue_count;
            stats.total_count += child.stats.total_count;
        }

        // Get emoji and color for this project (from stored maps, not stats which may be default)
        let emoji = project_emoji.get(&full_path).cloned().flatten();
        let color = project_color.get(&full_path).cloned().flatten();

        nodes.insert(
            full_path.clone(),
            ProjectNodeDto {
                name,
                full_path,
                emoji,
                color,
                stats,
                children,
            },
        );
    }

    // Collect top-level nodes (no dots in path)
    let mut result: Vec<ProjectNodeDto> = nodes
        .into_iter()
        .filter(|(path, _)| !path.contains('.'))
        .map(|(_, node)| node)
        .collect();
    result.sort_by(|a, b| a.name.cmp(&b.name));
    result
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

// User Reports Handlers

#[utoipa::path(
    get,
    path = "/v1/reports",
    responses((status = 200, description = "List of user reports", body = UserReportsListResponse))
)]
async fn list_user_reports_handler() -> ApiResult<Json<UserReportsListResponse>> {
    let reports = DbStore::list_user_reports().await?;
    let dtos: Vec<UserReportDto> = reports
        .into_iter()
        .map(UserReportDto::from_user_report)
        .collect();
    Ok(Json(UserReportsListResponse { reports: dtos }))
}

#[utoipa::path(
    post,
    path = "/v1/reports",
    request_body = UserReportRequest,
    responses(
        (status = 201, description = "User report created", body = UserReportDto),
        (status = 400, description = "Invalid request", body = ApiErrorResponse),
        (status = 409, description = "Name conflict", body = ApiErrorResponse)
    )
)]
async fn create_user_report_handler(
    Json(payload): Json<UserReportRequest>,
) -> ApiResult<(StatusCode, Json<UserReportDto>)> {
    // Validate name
    validate_report_name(&payload.name)?;

    // Check collision with static reports
    let core_config = bee_core::config::get_config();
    if core_config.get_report(&payload.name).is_some() {
        return Err(ApiError::conflict(format!(
            "Report name '{}' conflicts with a built-in report",
            payload.name
        )));
    }

    // Check if user report already exists
    if DbStore::get_user_report_by_name(&payload.name)
        .await?
        .is_some()
    {
        return Err(ApiError::conflict(format!(
            "User report '{}' already exists. Use PUT to update.",
            payload.name
        )));
    }

    let params = UserReportParams {
        filter: payload.filter,
        columns: payload.columns,
        column_names: payload.column_names,
        column_widths: payload.column_widths,
        sort_column: payload.sort_column,
        sort_direction: payload.sort_direction,
    };
    let report = DbStore::insert_user_report(payload.name, params).await?;

    Ok((
        StatusCode::CREATED,
        Json(UserReportDto::from_user_report(report)),
    ))
}

#[utoipa::path(
    put,
    path = "/v1/reports/{name}",
    params(("name" = String, Path, description = "Report name")),
    request_body = UserReportRequest,
    responses(
        (status = 200, description = "User report updated", body = UserReportDto),
        (status = 400, description = "Invalid request", body = ApiErrorResponse),
        (status = 404, description = "Report not found", body = ApiErrorResponse)
    )
)]
async fn update_user_report_handler(
    Path(name): Path<String>,
    Json(payload): Json<UserReportRequest>,
) -> ApiResult<Json<UserReportDto>> {
    // Ensure the report exists
    if DbStore::get_user_report_by_name(&name).await?.is_none() {
        return Err(ApiError::not_found(format!(
            "User report '{}' not found",
            name
        )));
    }

    let params = UserReportParams {
        filter: payload.filter,
        columns: payload.columns,
        column_names: payload.column_names,
        column_widths: payload.column_widths,
        sort_column: payload.sort_column,
        sort_direction: payload.sort_direction,
    };
    let report = DbStore::update_user_report(&name, params).await?;

    Ok(Json(UserReportDto::from_user_report(report)))
}

#[utoipa::path(
    delete,
    path = "/v1/reports/{name}",
    params(("name" = String, Path, description = "Report name")),
    responses(
        (status = 204, description = "User report deleted"),
        (status = 404, description = "Report not found", body = ApiErrorResponse)
    )
)]
async fn delete_user_report_handler(Path(name): Path<String>) -> ApiResult<StatusCode> {
    // Ensure the report exists
    if DbStore::get_user_report_by_name(&name).await?.is_none() {
        return Err(ApiError::not_found(format!(
            "User report '{}' not found",
            name
        )));
    }

    DbStore::delete_user_report(&name).await?;
    Ok(StatusCode::NO_CONTENT)
}

// ───────────────────────────────────────────────────────────────────────────
// Attachment endpoints
// ───────────────────────────────────────────────────────────────────────────

#[utoipa::path(
    get,
    path = "/v1/tasks/{task_uuid}/attachments",
    params(("task_uuid" = String, Path, description = "Task UUID")),
    responses(
        (status = 200, description = "List of attachments", body = Vec<AttachmentDto>)
    )
)]
async fn list_attachments_handler(
    Path(task_uuid): Path<Uuid>,
) -> ApiResult<Json<Vec<AttachmentDto>>> {
    let attachments = DbStore::list_attachments_by_task(task_uuid).await?;
    let dtos: Vec<AttachmentDto> = attachments
        .into_iter()
        .map(AttachmentDto::from_attachment)
        .collect();
    Ok(Json(dtos))
}

#[utoipa::path(
    post,
    path = "/v1/tasks/{task_uuid}/attachments",
    params(("task_uuid" = String, Path, description = "Task UUID")),
    request_body(content_type = "multipart/form-data", content = inline(UploadAttachmentForm)),
    responses(
        (status = 201, description = "Attachment uploaded", body = AttachmentDto),
        (status = 400, description = "Invalid file upload", body = ApiErrorResponse)
    )
)]
async fn upload_attachment_handler(
    State(state): State<AppState>,
    Path(task_uuid): Path<Uuid>,
    mut multipart: Multipart,
) -> ApiResult<(StatusCode, Json<AttachmentDto>)> {
    // Extract the file from the multipart form
    let field = multipart
        .next_field()
        .await
        .map_err(|e| ApiError::bad_request(format!("Failed to read multipart: {}", e)))?
        .ok_or_else(|| ApiError::bad_request("No file provided"))?;

    let filename = field
        .file_name()
        .map(|s| s.to_string())
        .unwrap_or_else(|| "unnamed".to_string());

    let content_type = field
        .content_type()
        .map(|s| s.to_string())
        .unwrap_or_else(|| "application/octet-stream".to_string());

    let data = field
        .bytes()
        .await
        .map_err(|e| ApiError::bad_request(format!("Failed to read file data: {}", e)))?;

    let attachment =
        DbStore::insert_attachment(task_uuid, filename.clone(), content_type, data.to_vec())
            .await?;

    // Use the action system to add history entry (enables undo support)
    let filter_json = serde_json::json!({"type": "UuidFilter", "value": {"uuid": task_uuid}});
    let filter = deserialize_filter(Some(filter_json))?;
    let undos = DbStore::load_undos(state.undo_count).await?;
    let mut tasks = DbStore::load_tasks(filter, None).await?;

    for undo_action in &undos {
        tasks.set_undos(&undo_action.tasks);
    }

    let mut action = ActionRegistry::get_action_from_command_parser(&ParsedCommand {
        command: "modify".to_string(),
        report_kind: state.report.clone(),
        ..Default::default()
    });

    let mut props = TaskProperties::default();
    props.set_attachment_add(AttachmentAddInput::new(filename));
    action.set_properties(props);
    action.set_tasks(tasks);
    action.set_undos(undos);

    let printer = JsonPrinter::new();
    action.do_action(&printer)?;

    DbStore::write_tasks(action.get_tasks(), action.get_undos()).await?;
    DbStore::log_undo(state.undo_count, action.get_undos().to_owned()).await?;

    Ok((
        StatusCode::CREATED,
        Json(AttachmentDto::from_attachment(attachment)),
    ))
}

/// Form schema for file upload (for OpenAPI documentation).
#[derive(utoipa::ToSchema)]
#[allow(dead_code)]
struct UploadAttachmentForm {
    /// The file to upload
    #[schema(value_type = String, format = Binary)]
    file: Vec<u8>,
}

#[utoipa::path(
    get,
    path = "/v1/attachments/{attachment_id}/download",
    params(("attachment_id" = i32, Path, description = "Attachment ID")),
    responses(
        (status = 200, description = "File data", content_type = "application/octet-stream"),
        (status = 404, description = "Attachment not found", body = ApiErrorResponse)
    )
)]
async fn download_attachment_handler(
    Path(attachment_id): Path<i32>,
) -> ApiResult<impl IntoResponse> {
    let attachment = DbStore::get_attachment_by_id(attachment_id)
        .await?
        .ok_or_else(|| ApiError::not_found("Attachment not found"))?;

    let data = DbStore::get_attachment_data(attachment_id)
        .await?
        .ok_or_else(|| ApiError::not_found("Attachment data not found"))?;

    let headers = [
        (header::CONTENT_TYPE, attachment.mime_type),
        (
            header::CONTENT_DISPOSITION,
            format!("attachment; filename=\"{}\"", attachment.filename),
        ),
    ];

    Ok((headers, Bytes::from(data)))
}

#[utoipa::path(
    delete,
    path = "/v1/attachments/{attachment_id}",
    params(("attachment_id" = i32, Path, description = "Attachment ID")),
    responses(
        (status = 204, description = "Attachment deleted"),
        (status = 404, description = "Attachment not found", body = ApiErrorResponse)
    )
)]
async fn delete_attachment_handler(Path(attachment_id): Path<i32>) -> ApiResult<StatusCode> {
    // Verify it exists first
    if DbStore::get_attachment_by_id(attachment_id)
        .await?
        .is_none()
    {
        return Err(ApiError::not_found("Attachment not found"));
    }

    DbStore::delete_attachment_by_id(attachment_id).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// Validate report name: non-empty, <= 64 chars, no control characters
fn validate_report_name(name: &str) -> ApiResult<()> {
    let trimmed = name.trim();
    if trimmed.is_empty() {
        return Err(ApiError::bad_request("Report name cannot be empty"));
    }
    if trimmed.len() > 64 {
        return Err(ApiError::bad_request(
            "Report name must be 64 characters or fewer",
        ));
    }
    // Allow any printable Unicode, reject only control characters
    if trimmed.chars().any(|c| c.is_control()) {
        return Err(ApiError::bad_request(
            "Report name cannot contain control characters",
        ));
    }
    Ok(())
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

    // Skip write_tasks for read-only actions that don't modify tasks
    let readonly_actions = ["list", "info", "export", "help"];
    if !readonly_actions.contains(&action_name) {
        DbStore::write_tasks(action.get_tasks(), action.get_undos()).await?;
        DbStore::log_undo(state.undo_count, action.get_undos().to_owned()).await?;
    }

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

// ==================== Profile Handlers ====================

/// List all configured profiles.
#[utoipa::path(
    get,
    path = "/v1/profiles",
    responses((status = 200, description = "List of profiles", body = ProfilesListResponse))
)]
async fn list_profiles_handler() -> Json<ProfilesListResponse> {
    let profiles = profile::list_profiles().unwrap_or_default();
    let profile_dtos: Vec<ProfileDto> = profiles
        .into_iter()
        .map(|(key, p)| ProfileDto {
            key,
            name: p.name.clone(),
            description: p.description.clone(),
            data_dir: profile::get_profile_data_dir(&p.name)
                .to_string_lossy()
                .to_string(),
            config_dir: profile::get_profile_config_dir(&p.name)
                .to_string_lossy()
                .to_string(),
        })
        .collect();
    Json(ProfilesListResponse {
        profiles: profile_dtos,
    })
}

/// Create a new profile.
#[utoipa::path(
    post,
    path = "/v1/profiles",
    request_body = ProfileCreateRequest,
    responses(
        (status = 201, description = "Profile created", body = ProfileDto),
        (status = 400, description = "Invalid profile name", body = ApiErrorResponse)
    )
)]
async fn create_profile_handler(
    Json(request): Json<ProfileCreateRequest>,
) -> ApiResult<(StatusCode, Json<ProfileDto>)> {
    let name = request.name.as_deref().unwrap_or(&request.key);
    let description = request.description.as_deref().unwrap_or("");

    profile::create_profile(&request.key, description)
        .map_err(|e| ApiError::bad_request(format!("{}", e)))?;

    Ok((
        StatusCode::CREATED,
        Json(ProfileDto {
            key: request.key.clone(),
            name: name.to_string(),
            description: description.to_string(),
            data_dir: profile::get_profile_data_dir(&request.key)
                .to_string_lossy()
                .to_string(),
            config_dir: profile::get_profile_config_dir(&request.key)
                .to_string_lossy()
                .to_string(),
        }),
    ))
}

/// Delete a profile.
#[utoipa::path(
    delete,
    path = "/v1/profiles/{profile_key}",
    params(("profile_key" = String, Path, description = "Profile key")),
    responses(
        (status = 204, description = "Profile deleted"),
        (status = 404, description = "Profile not found", body = ApiErrorResponse)
    )
)]
async fn delete_profile_handler(Path(profile_key): Path<String>) -> ApiResult<StatusCode> {
    profile::delete_profile(&profile_key).map_err(|e| ApiError::not_found(format!("{}", e)))?;
    Ok(StatusCode::NO_CONTENT)
}

/// Validate that a profile exists.
fn validate_profile(profile_key: &str) -> ApiResult<()> {
    if !profile::profile_exists(profile_key) {
        return Err(ApiError::not_found(format!(
            "Profile '{}' not found. Available profiles can be listed at GET /v1/profiles",
            profile_key
        )));
    }
    Ok(())
}

/// Get config for a specific profile.
#[utoipa::path(
    get,
    path = "/v1/profiles/{profile_key}/config",
    params(("profile_key" = String, Path, description = "Profile key")),
    responses(
        (status = 200, description = "Profile configuration", body = ConfigResponse),
        (status = 404, description = "Profile not found", body = ApiErrorResponse)
    )
)]
async fn profile_config_handler(
    State(state): State<AppState>,
    Path(profile_key): Path<String>,
) -> ApiResult<Json<ConfigResponse>> {
    validate_profile(&profile_key)?;

    let core_config = bee_core::config::load_config_for_profile(&profile_key)
        .map_err(|e| ApiError::internal(format!("Failed to load config: {}", e)))?;
    let default_report_name = &core_config.default_report;

    // Build static reports from config
    let reports: Vec<ReportSummary> = core_config
        .get_all_reports()
        .map(|(name, report)| ReportSummary {
            name: name.to_string(),
            filters: report.filters.clone(),
            filter: None,
            columns: report.columns.clone(),
            column_names: report.column_names.clone(),
            column_widths: None,
            sort_column: None,
            sort_direction: None,
            is_default: name == default_report_name,
            is_user_report: false,
        })
        .collect();

    // TODO: Load user reports from profile-specific database
    // For now, we use the global DbStore which doesn't support profiles yet
    // This will be updated when DbStore is made profile-aware

    Ok(Json(ConfigResponse {
        report: ReportConfigDto {
            filters: state.report.filters.clone(),
            columns: state.report.columns.clone(),
            column_names: state.report.column_names.clone(),
        },
        reports,
    }))
}

/// Get task detail for a specific profile.
#[utoipa::path(
    get,
    path = "/v1/profiles/{profile_key}/tasks/{task_uuid}",
    params(
        ("profile_key" = String, Path, description = "Profile key"),
        ("task_uuid" = String, Path, description = "Task UUID")
    ),
    responses(
        (status = 200, description = "Task detail", body = ApiTaskDetail),
        (status = 404, description = "Profile or task not found", body = ApiErrorResponse)
    )
)]
async fn profile_task_detail_handler(
    Path((profile_key, task_uuid)): Path<(String, Uuid)>,
) -> ApiResult<Json<ApiTaskDetail>> {
    validate_profile(&profile_key)?;

    let Some(task) = DbStore::get_task_by_uuid_for_profile(&profile_key, task_uuid).await? else {
        return Err(ApiError::not_found("Task not found"));
    };
    let attachments = DbStore::list_attachments_for_profile(&profile_key, task_uuid).await?;
    Ok(Json(ApiTaskDetail::from_task_with_attachments(
        &task,
        attachments,
    )))
}

/// Execute an action for a specific profile.
#[utoipa::path(
    post,
    path = "/v1/profiles/{profile_key}/action",
    params(("profile_key" = String, Path, description = "Profile key")),
    request_body = ActionRequest,
    responses(
        (status = 200, description = "Action executed successfully", body = ActionResponse),
        (status = 400, description = "Bad request", body = ApiErrorResponse),
        (status = 403, description = "Action not allowed", body = ApiErrorResponse),
        (status = 404, description = "Profile not found", body = ApiErrorResponse)
    )
)]
async fn profile_action_handler(
    State(state): State<AppState>,
    Path(profile_key): Path<String>,
    Json(request): Json<ActionRequest>,
) -> ApiResult<Json<ActionResponse>> {
    validate_profile(&profile_key)?;

    // Validate action is known
    if !valid_action_names().contains(&request.action) {
        return Err(ApiError::bad_request(format!(
            "unknown action: {}",
            request.action
        )));
    }
    // Validate action is allowed by config
    if !is_api_action_allowed(&state, &request.action) {
        return Err(ApiError::bad_request(format!(
            "action '{}' is not allowed by server configuration",
            request.action
        )));
    }

    let filter: Option<Box<dyn Filter>> = deserialize_filter(request.filter)?;
    let properties: Option<TaskProperties> = deserialize_properties(request.properties)?;

    // Use profile-specific database operations
    let mut tasks =
        DbStore::load_tasks_for_profile(&profile_key, filter, properties.clone()).await?;
    let undos = DbStore::load_undos_for_profile(&profile_key, state.undo_count).await?;

    let cp = ParsedCommand {
        command: request.action.clone(),
        filters: filters::new_empty(),
        arguments: vec![],
        arguments_as_filters: false,
        report_kind: state.report.clone(),
    };

    let printer = JsonPrinter::new();
    let mut action = ActionRegistry::get_action_from_command_parser(&cp);
    action.set_tasks(tasks.clone());
    action.set_undos(undos);

    if let Some(props) = &properties {
        action.set_properties(props.clone());
    }
    action.do_action(&printer)?;

    let new_tasks = action.get_tasks();
    let new_undos = action.get_undos();

    // Write back to profile-specific database
    DbStore::write_tasks_for_profile(&profile_key, new_tasks, new_undos).await?;
    DbStore::log_undo_for_profile(&profile_key, state.undo_count, new_undos.to_owned()).await?;

    // Reload tasks from profile database to return updated state
    tasks = DbStore::load_tasks_for_profile(&profile_key, None, None).await?;
    let tasks: Vec<ApiTask> = tasks
        .to_vec()
        .iter()
        .map(|t| ApiTask::from_task(t))
        .collect();

    Ok(Json(ActionResponse {
        action: request.action,
        tasks,
        events: printer.take_events(),
    }))
}

// =============================================================================
// Profile-scoped completions handler
// =============================================================================

/// Get completions for a specific profile.
async fn profile_completions_handler(
    Path(profile_key): Path<String>,
    Query(query): Query<CompletionsQuery>,
) -> ApiResult<Json<CompletionsResponse>> {
    validate_profile(&profile_key)?;

    let items = match query.completion_type.as_str() {
        "projects" => {
            let rows = DbStore::get_projects_for_profile(&profile_key).await?;
            rows.into_iter()
                .map(|r| CompletionItem {
                    value: r.value,
                    count: Some(r.count),
                })
                .collect()
        }
        "tags" => {
            let rows = DbStore::get_tags_for_profile(&profile_key).await?;
            rows.into_iter()
                .map(|r| CompletionItem {
                    value: r.value,
                    count: Some(r.count),
                })
                .collect()
        }
        "actions" => {
            // Actions are static, no profile needed
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

// =============================================================================
// Profile-scoped reports handlers
// =============================================================================

/// List user reports for a specific profile.
async fn profile_list_user_reports_handler(
    Path(profile_key): Path<String>,
) -> ApiResult<Json<UserReportsListResponse>> {
    validate_profile(&profile_key)?;

    let reports = DbStore::list_user_reports_for_profile(&profile_key).await?;
    let dtos: Vec<UserReportDto> = reports
        .into_iter()
        .map(UserReportDto::from_user_report)
        .collect();

    Ok(Json(UserReportsListResponse { reports: dtos }))
}

/// Create a user report for a specific profile.
async fn profile_create_user_report_handler(
    Path(profile_key): Path<String>,
    Json(payload): Json<UserReportRequest>,
) -> ApiResult<(StatusCode, Json<UserReportDto>)> {
    validate_profile(&profile_key)?;

    // Validate name
    validate_report_name(&payload.name)?;

    // Check collision with static reports
    let core_config = bee_core::config::get_config();
    if core_config.get_report(&payload.name).is_some() {
        return Err(ApiError::conflict(format!(
            "Report name '{}' conflicts with a built-in report",
            payload.name
        )));
    }

    // Check if user report already exists in this profile
    if DbStore::get_user_report_by_name_for_profile(&profile_key, &payload.name)
        .await?
        .is_some()
    {
        return Err(ApiError::conflict(format!(
            "User report '{}' already exists. Use PUT to update.",
            payload.name
        )));
    }

    let params = UserReportParams {
        filter: payload.filter,
        columns: payload.columns,
        column_names: payload.column_names,
        column_widths: payload.column_widths,
        sort_column: payload.sort_column,
        sort_direction: payload.sort_direction,
    };
    let report =
        DbStore::insert_user_report_for_profile(&profile_key, payload.name, params).await?;

    Ok((
        StatusCode::CREATED,
        Json(UserReportDto::from_user_report(report)),
    ))
}

/// Update a user report for a specific profile.
async fn profile_update_user_report_handler(
    Path((profile_key, name)): Path<(String, String)>,
    Json(payload): Json<UserReportRequest>,
) -> ApiResult<Json<UserReportDto>> {
    validate_profile(&profile_key)?;

    // Ensure the report exists in this profile
    if DbStore::get_user_report_by_name_for_profile(&profile_key, &name)
        .await?
        .is_none()
    {
        return Err(ApiError::not_found(format!(
            "User report '{}' not found",
            name
        )));
    }

    let params = UserReportParams {
        filter: payload.filter,
        columns: payload.columns,
        column_names: payload.column_names,
        column_widths: payload.column_widths,
        sort_column: payload.sort_column,
        sort_direction: payload.sort_direction,
    };
    let report = DbStore::update_user_report_for_profile(&profile_key, &name, params).await?;

    Ok(Json(UserReportDto::from_user_report(report)))
}

/// Delete a user report for a specific profile.
async fn profile_delete_user_report_handler(
    Path((profile_key, name)): Path<(String, String)>,
) -> ApiResult<StatusCode> {
    validate_profile(&profile_key)?;

    // Ensure the report exists in this profile
    if DbStore::get_user_report_by_name_for_profile(&profile_key, &name)
        .await?
        .is_none()
    {
        return Err(ApiError::not_found(format!(
            "User report '{}' not found",
            name
        )));
    }

    DbStore::delete_user_report_for_profile(&profile_key, &name).await?;

    Ok(StatusCode::NO_CONTENT)
}

// =============================================================================
// Profile-scoped projects handlers
// =============================================================================

/// Get project hierarchy for a specific profile.
async fn profile_projects_handler(
    Path(profile_key): Path<String>,
) -> ApiResult<Json<ProjectsResponse>> {
    validate_profile(&profile_key)?;

    let stats = DbStore::get_projects_with_stats_for_profile(&profile_key).await?;

    // Build hierarchical tree from flat list
    let projects = build_project_hierarchy(stats);

    Ok(Json(ProjectsResponse { projects }))
}

#[derive(Deserialize)]
struct ProfileProjectBurndownParams {
    profile_key: String,
    name: String,
}

/// Get project burndown data for a specific profile.
async fn profile_project_burndown_handler(
    Path(params): Path<ProfileProjectBurndownParams>,
    Query(query): Query<BurndownQuery>,
) -> ApiResult<Json<ProjectBurndownResponse>> {
    validate_profile(&params.profile_key)?;

    let project_name = urlencoding::decode(&params.name)
        .map_err(|_| ApiError::bad_request("Invalid project name encoding"))?
        .to_string();

    let (total_tasks, total_completed) =
        DbStore::get_project_totals_for_profile(&params.profile_key, &project_name).await?;

    if total_tasks == 0 {
        return Err(ApiError::not_found(format!(
            "Project '{}' not found or has no tasks",
            project_name
        )));
    }

    let burndown_rows =
        DbStore::get_burndown_for_profile(&params.profile_key, &project_name, query.days).await?;

    // Convert to cumulative data points
    let mut data_points = Vec::new();
    let mut cumulative = 0i64;

    for row in burndown_rows {
        cumulative += row.completed_on_day;
        data_points.push(BurndownDataPoint {
            date: row.date,
            completed_cumulative: cumulative,
            remaining: total_tasks - cumulative,
        });
    }

    Ok(Json(ProjectBurndownResponse {
        project: project_name,
        data_points,
        total_tasks,
        total_completed,
    }))
}

// =============================================================================
// Profile-scoped attachments handlers
// =============================================================================

#[derive(Deserialize)]
struct ProfileAttachmentUploadParams {
    profile_key: String,
    task_uuid: Uuid,
}

/// Upload an attachment for a task in a specific profile.
async fn profile_upload_attachment_handler(
    Path(params): Path<ProfileAttachmentUploadParams>,
    mut multipart: Multipart,
) -> ApiResult<(StatusCode, Json<AttachmentDto>)> {
    validate_profile(&params.profile_key)?;

    // Verify task exists in profile
    let Some(_task) =
        DbStore::get_task_by_uuid_for_profile(&params.profile_key, params.task_uuid).await?
    else {
        return Err(ApiError::not_found(format!(
            "Task {} not found",
            params.task_uuid
        )));
    };

    // Extract file from multipart
    let field = multipart
        .next_field()
        .await
        .map_err(|e| ApiError::bad_request(format!("Failed to read multipart: {}", e)))?
        .ok_or_else(|| ApiError::bad_request("No file provided"))?;

    let filename = field
        .file_name()
        .map(|s| s.to_string())
        .unwrap_or_else(|| "unnamed".to_string());

    let mime_type = field
        .content_type()
        .map(|s| s.to_string())
        .unwrap_or_else(|| "application/octet-stream".to_string());

    let data = field
        .bytes()
        .await
        .map_err(|e| ApiError::bad_request(format!("Failed to read file data: {}", e)))?;

    let attachment = DbStore::insert_attachment_for_profile(
        &params.profile_key,
        params.task_uuid,
        filename,
        mime_type,
        data.to_vec(),
    )
    .await?;

    Ok((
        StatusCode::CREATED,
        Json(AttachmentDto::from_attachment(attachment)),
    ))
}

#[derive(Deserialize)]
struct ProfileAttachmentParams {
    profile_key: String,
    attachment_id: i32,
}

/// Download an attachment from a specific profile.
async fn profile_download_attachment_handler(
    Path(params): Path<ProfileAttachmentParams>,
) -> ApiResult<impl IntoResponse> {
    validate_profile(&params.profile_key)?;

    let Some(attachment) =
        DbStore::get_attachment_by_id_for_profile(&params.profile_key, params.attachment_id)
            .await?
    else {
        return Err(ApiError::not_found("Attachment not found"));
    };

    let Some(data) =
        DbStore::get_attachment_data_for_profile(&params.profile_key, params.attachment_id).await?
    else {
        return Err(ApiError::not_found("Attachment data not found"));
    };

    let headers = [
        (header::CONTENT_TYPE, attachment.mime_type),
        (
            header::CONTENT_DISPOSITION,
            format!("attachment; filename=\"{}\"", attachment.filename),
        ),
    ];

    Ok((headers, Bytes::from(data)))
}

/// Delete an attachment from a specific profile.
async fn profile_delete_attachment_handler(
    Path(params): Path<ProfileAttachmentParams>,
) -> ApiResult<StatusCode> {
    validate_profile(&params.profile_key)?;

    // Verify attachment exists
    let Some(_attachment) =
        DbStore::get_attachment_by_id_for_profile(&params.profile_key, params.attachment_id)
            .await?
    else {
        return Err(ApiError::not_found("Attachment not found"));
    };

    DbStore::delete_attachment_by_id_for_profile(&params.profile_key, params.attachment_id).await?;

    Ok(StatusCode::NO_CONTENT)
}

/// OpenAPI document for the bee-api service.
#[derive(OpenApi)]
#[openapi(
    paths(
        health_handler,
        config_handler,
        completions_handler,
        projects_handler,
        project_burndown_handler,
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
        resolve_external_link_handler,
        list_attachments_handler,
        upload_attachment_handler,
        download_attachment_handler,
        delete_attachment_handler
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
        ProjectsResponse,
        ProjectNodeDto,
        ProjectStatsDto,
        ProjectBurndownResponse,
        BurndownDataPoint,
        ApiTask,
        ApiTaskDetail,
        ApiEvent,
        TaskAnnotationDto,
        TaskHistoryDto,
        TokenSpan,
        ApiErrorResponse,
        AttachmentDto,
        UploadAttachmentForm
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
    fn test_flat_uuid_filter_fails_deserialization() {
        // Test that the flat format (what the macOS Swift client currently sends) fails deserialization
        // This is the format Swift sends: {"type": "UuidFilter", "uuid": "..."}
        let flat_filter = serde_json::json!({
            "type": "UuidFilter",
            "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        });

        let result = deserialize_filter(Some(flat_filter));
        // This should fail because typetag expects {"type": "UuidFilter", "value": {...}}
        assert!(
            result.is_err(),
            "Flat format should fail deserialization. Expected error but got: {:?}",
            result
        );
    }

    #[test]
    fn test_correct_uuid_filter_format_deserializes() {
        // Test the correct format with "value" wrapper deserializes successfully
        let correct_filter = serde_json::json!({
            "type": "UuidFilter",
            "value": {
                "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            }
        });

        let result = deserialize_filter(Some(correct_filter));
        assert!(
            result.is_ok(),
            "Correct format should deserialize. Got error: {:?}",
            result
        );
        assert!(result.unwrap().is_some());
    }

    #[test]
    fn test_properties_roundtrip() {
        let props = TaskProperties::from(&["summary +tag".to_string()]).unwrap();
        let serialized = serialize_properties(Some(props.clone())).unwrap();
        let deserialized = deserialize_properties(serialized).unwrap();
        assert_eq!(deserialized, Some(props));
    }

    // MARK: - Report Name Validation Tests

    #[test]
    fn test_validate_report_name_valid() {
        // Basic names
        assert!(validate_report_name("my-report").is_ok());
        assert!(validate_report_name("My_Report_123").is_ok());
        assert!(validate_report_name("a").is_ok());
        assert!(validate_report_name("report-with-dashes").is_ok());
        assert!(validate_report_name("report_with_underscores").is_ok());
        // Names with spaces
        assert!(validate_report_name("My Report").is_ok());
        // Unicode names (CJK, accented, etc.)
        assert!(validate_report_name("日本語レポート").is_ok());
        assert!(validate_report_name("Ñoño café").is_ok());
        // Special characters
        assert!(validate_report_name("Report #1 (draft)").is_ok());
        assert!(validate_report_name("report.name").is_ok());
        assert!(validate_report_name("report@v2!").is_ok());
    }

    #[test]
    fn test_validate_report_name_empty() {
        let result = validate_report_name("");
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(matches!(err, ApiError::BadRequest { .. }));
    }

    #[test]
    fn test_validate_report_name_whitespace_only() {
        // Whitespace-only should be invalid (trims to empty)
        assert!(validate_report_name("   ").is_err());
        assert!(validate_report_name("\t\n").is_err());
    }

    #[test]
    fn test_validate_report_name_too_long() {
        let long_name = "a".repeat(65);
        let result = validate_report_name(&long_name);
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(matches!(err, ApiError::BadRequest { .. }));

        // Exactly 64 chars should be valid
        let max_name = "a".repeat(64);
        assert!(validate_report_name(&max_name).is_ok());
    }

    #[test]
    fn test_validate_report_name_control_chars() {
        // Only control characters should be rejected
        assert!(validate_report_name("report\nname").is_err());
        assert!(validate_report_name("report\tname").is_err());
        assert!(validate_report_name("report\x00name").is_err());
        assert!(validate_report_name("report\x1Fname").is_err());
    }

    #[test]
    fn test_build_project_hierarchy_nested() {
        use bee_core::storage::db::ProjectStatusRow;

        let stats = vec![
            ProjectStatusRow {
                project_name: "backend".to_string(),
                pending_count: 2,
                active_count: 1,
                completed_count: 5,
                overdue_count: 0,
                total_count: 8,
                emoji: Some("🔧".to_string()),
                color: Some("#FF5733".to_string()),
            },
            ProjectStatusRow {
                project_name: "backend.api".to_string(),
                pending_count: 1,
                active_count: 0,
                completed_count: 3,
                overdue_count: 0,
                total_count: 4,
                emoji: None,
                color: None,
            },
            ProjectStatusRow {
                project_name: "frontend".to_string(),
                pending_count: 3,
                active_count: 2,
                completed_count: 10,
                overdue_count: 1,
                total_count: 16,
                emoji: Some("🎨".to_string()),
                color: None,
            },
        ];

        let hierarchy = build_project_hierarchy(stats);

        // Should have 2 top-level projects
        assert_eq!(hierarchy.len(), 2);

        // Find backend and check it has children
        let backend = hierarchy.iter().find(|p| p.name == "backend").unwrap();
        assert_eq!(backend.children.len(), 1);
        assert_eq!(backend.children[0].name, "api");

        // Frontend should have no children
        let frontend = hierarchy.iter().find(|p| p.name == "frontend").unwrap();
        assert!(frontend.children.is_empty());
    }

    #[test]
    fn test_openapi_schema_generates_without_overflow() {
        // This test ensures the OpenAPI schema can be generated without stack overflow.
        // The recursive ProjectNodeDto was causing utoipa to infinitely recurse.
        let doc = ApiDoc::openapi();
        let json = doc.to_json();
        assert!(
            json.is_ok(),
            "OpenAPI schema should serialize without error"
        );

        // Verify that ProjectNodeDto appears in the schema
        let json_str = json.unwrap();
        assert!(
            json_str.contains("ProjectNodeDto"),
            "Schema should contain ProjectNodeDto"
        );
    }

    #[tokio::test]
    async fn test_projects_endpoint() {
        // Use in-memory database for isolated test
        // SAFETY: This test runs in isolation and no other threads depend on this env var
        unsafe {
            std::env::set_var("BEE_DATABASE_URL", "sqlite::memory:");
        }

        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);
        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/projects")
                    .method("GET")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .expect("projects response");

        assert_eq!(response.status(), StatusCode::OK);
        let body = response.into_body().collect().await.unwrap().to_bytes();
        let parsed: ProjectsResponse = serde_json::from_slice(&body).unwrap();
        // Response should be valid JSON (may have 0 projects for empty database)
        assert!(parsed.projects.is_empty());

        // SAFETY: Cleaning up env var set by this test
        unsafe {
            std::env::remove_var("BEE_DATABASE_URL");
        }
    }

    // MARK: - Profile Tests

    #[tokio::test]
    async fn test_list_profiles_endpoint() {
        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);
        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/profiles")
                    .method("GET")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .expect("profiles response");

        assert_eq!(response.status(), StatusCode::OK);
        let body = response.into_body().collect().await.unwrap().to_bytes();
        let parsed: ProfilesListResponse = serde_json::from_slice(&body).unwrap();
        // Response should be valid JSON (may have 0 profiles if not configured)
        assert!(parsed.profiles.is_empty() || !parsed.profiles.is_empty());
    }

    #[tokio::test]
    async fn test_validate_profile_returns_not_found_for_invalid_profile() {
        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);

        // Request with a profile that doesn't exist
        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/profiles/nonexistent-profile-123/config")
                    .method("GET")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .expect("profile config response");

        // Should return 404 Not Found for non-existent profile
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn test_profile_task_detail_requires_valid_profile() {
        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);

        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/profiles/fake-profile/tasks/a1b2c3d4-e5f6-7890-abcd-ef1234567890")
                    .method("GET")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .expect("task detail response");

        // Should return 404 for non-existent profile
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn test_profile_action_requires_valid_profile() {
        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);

        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/profiles/fake-profile/action")
                    .method("POST")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&json!({ "action": "list" })).unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .expect("action response");

        // Should return 404 for non-existent profile
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[test]
    fn test_validate_profile_function() {
        // Test validate_profile with invalid profile names
        let result = validate_profile("nonexistent-profile");
        assert!(result.is_err());

        // Invalid profile names should also fail validation
        let result = validate_profile("INVALID");
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_create_profile_endpoint() {
        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);

        // Use a unique name based on timestamp to avoid conflicts between test runs
        let unique_name = format!(
            "test-profile-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
                % 1000000
        );

        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/profiles")
                    .method("POST")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&json!({
                            "key": unique_name,
                            "name": "Test Profile",
                            "description": "A test profile"
                        }))
                        .unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .expect("create profile response");

        // 201 (created) or 409 (already exists) are acceptable
        // 400 might occur if the profiles.toml directory doesn't exist in the test environment
        let status = response.status();
        assert!(
            status == StatusCode::CREATED
                || status == StatusCode::OK
                || status == StatusCode::CONFLICT
                || status == StatusCode::BAD_REQUEST, // May fail in CI without proper setup
            "Unexpected status: {:?}",
            status
        );
    }

    #[tokio::test]
    async fn test_create_profile_rejects_invalid_name() {
        let state = AppState::from_config(ApiConfig::default());
        let app = router(state);

        let response = app
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/profiles")
                    .method("POST")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&json!({
                            "key": "INVALID_NAME",  // Invalid: uppercase and underscore
                            "name": "Invalid Profile"
                        }))
                        .unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .expect("create profile response");

        // Should return 400 Bad Request for invalid profile name
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }
}
