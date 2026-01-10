use bee_core::{
    attachment::Attachment,
    email_link::EmailLink,
    important_link::ImportantLink,
    task::{Link, LinkType, Task, TaskAnnotation, TaskHistory, TaskStatus},
};
use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use utoipa::ToSchema;
use uuid::Uuid;

/// Request payload for running an action against tasks.
#[derive(Debug, Deserialize, ToSchema)]
pub struct ActionRequest {
    pub action: String,
    #[schema(value_type = utoipa::openapi::Object)]
    pub properties: Option<Value>,
    #[schema(value_type = utoipa::openapi::Object)]
    pub filter: Option<Value>,
}

/// Response payload for action execution.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ActionResponse {
    pub action: String,
    pub tasks: Vec<ApiTask>,
    pub events: Vec<ApiEvent>,
}

/// Request payload for parsing user input into action/filters/properties.
#[derive(Debug, Deserialize, ToSchema)]
pub struct ParseRequest {
    pub input: String,
}

/// Response payload for parse results and token spans.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ParseResponse {
    pub action: String,
    #[schema(value_type = utoipa::openapi::Object)]
    pub properties: Option<Value>,
    #[schema(value_type = utoipa::openapi::Object)]
    pub filter: Option<Value>,
    pub tokens: Vec<TokenSpan>,
}

/// Structured event emitted by actions (info/warn/error/etc).
#[derive(Debug, Serialize, Deserialize, Clone, ToSchema)]
pub struct ApiEvent {
    pub kind: String,
    pub message: String,
}

impl ApiEvent {
    /// Build a new API event from a kind and message.
    pub fn new(kind: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            kind: kind.into(),
            message: message.into(),
        }
    }
}

/// Trimmed task payload returned by the API.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ApiTask {
    pub id: Option<i32>,
    #[schema(value_type = String, format = "uuid")]
    pub uuid: Uuid,
    #[schema(value_type = String)]
    pub status: TaskStatus,
    pub summary: String,
    pub project: Option<String>,
    pub tags: Vec<String>,
    #[schema(value_type = String, format = DateTime)]
    pub date_created: DateTime<Local>,
    #[schema(value_type = String, format = DateTime)]
    pub date_completed: Option<DateTime<Local>>,
    #[schema(value_type = String, format = DateTime)]
    pub date_due: Option<DateTime<Local>>,
    pub urgency: Option<i64>,
}

impl ApiTask {
    /// Build a trimmed API task payload from a domain task.
    pub fn from_task(task: &Task) -> Self {
        let urgency = {
            let task = task.clone();
            *task.get_urgency()
        };
        Self {
            id: task.get_id(),
            uuid: *task.get_uuid(),
            status: task.get_status().clone(),
            summary: task.get_summary().to_owned(),
            project: task.get_project().as_ref().map(|p| p.get_name().to_owned()),
            tags: task.get_tags().to_vec(),
            date_created: task.get_date_created().to_owned(),
            date_completed: task.get_date_completed().to_owned(),
            date_due: task.get_date_due().to_owned(),
            urgency,
        }
    }
}

/// Task annotation payload.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct TaskAnnotationDto {
    pub value: String,
    #[schema(value_type = String, format = DateTime)]
    pub time: DateTime<Local>,
}

impl TaskAnnotationDto {
    pub fn from_annotation(annotation: &TaskAnnotation) -> Self {
        Self {
            value: annotation.get_value().to_owned(),
            time: annotation.get_time().to_owned(),
        }
    }
}

/// Task history payload.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct TaskHistoryDto {
    pub value: String,
    #[schema(value_type = String, format = DateTime)]
    pub datetime: DateTime<Local>,
}

impl TaskHistoryDto {
    pub fn from_history(history: &TaskHistory) -> Self {
        Self {
            value: history.get_value().to_owned(),
            datetime: history.get_datetime().to_owned(),
        }
    }
}

/// Task link payload.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct TaskLinkDto {
    /// Link type: "depends_on", "blocking", "parent_of", "child_of", "related_to", "duplicates"
    pub link_type: String,
    /// Target task UUID
    #[schema(value_type = String, format = "uuid")]
    pub target_uuid: Uuid,
}

impl TaskLinkDto {
    pub fn from_link(link: &Link) -> Self {
        let link_type = match link.get_link_type() {
            LinkType::DependsOn => "depends_on",
            LinkType::Blocking => "blocking",
            LinkType::ParentOf => "parent_of",
            LinkType::ChildOf => "child_of",
            LinkType::RelatedTo => "related_to",
            LinkType::Duplicates => "duplicates",
        };
        Self {
            link_type: link_type.to_string(),
            target_uuid: *link.get_target(),
        }
    }
}

/// Full task payload including annotations, history, and attachments.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ApiTaskDetail {
    pub id: Option<i32>,
    #[schema(value_type = String, format = "uuid")]
    pub uuid: Uuid,
    #[schema(value_type = String)]
    pub status: TaskStatus,
    pub summary: String,
    pub project: Option<String>,
    pub tags: Vec<String>,
    #[schema(value_type = String, format = DateTime)]
    pub date_created: DateTime<Local>,
    #[schema(value_type = String, format = DateTime)]
    pub date_completed: Option<DateTime<Local>>,
    #[schema(value_type = String, format = DateTime)]
    pub date_due: Option<DateTime<Local>>,
    pub urgency: Option<i64>,
    pub annotations: Vec<TaskAnnotationDto>,
    pub history: Vec<TaskHistoryDto>,
    pub links: Vec<TaskLinkDto>,
    pub attachments: Vec<AttachmentDto>,
    pub email_links: Vec<EmailLinkDto>,
    pub important_links: Vec<ImportantLinkDto>,
}

impl ApiTaskDetail {
    /// Build detail from task with attachments loaded separately.
    pub fn from_task_with_attachments(task: &Task, attachments: Vec<Attachment>) -> Self {
        let urgency = {
            let task = task.clone();
            *task.get_urgency()
        };
        Self {
            id: task.get_id(),
            uuid: *task.get_uuid(),
            status: task.get_status().clone(),
            summary: task.get_summary().to_owned(),
            project: task.get_project().as_ref().map(|p| p.get_name().to_owned()),
            tags: task.get_tags().to_vec(),
            date_created: task.get_date_created().to_owned(),
            date_completed: task.get_date_completed().to_owned(),
            date_due: task.get_date_due().to_owned(),
            urgency,
            annotations: task
                .get_annotations()
                .iter()
                .map(TaskAnnotationDto::from_annotation)
                .collect(),
            history: task
                .get_history()
                .iter()
                .map(TaskHistoryDto::from_history)
                .collect(),
            links: task
                .get_links()
                .iter()
                .map(TaskLinkDto::from_link)
                .collect(),
            attachments: attachments
                .into_iter()
                .map(AttachmentDto::from_attachment)
                .collect(),
            email_links: task
                .get_email_links()
                .iter()
                .map(EmailLinkDto::from_email_link)
                .collect(),
            important_links: task
                .get_important_links()
                .iter()
                .map(ImportantLinkDto::from_important_link)
                .collect(),
        }
    }
}

/// External link response payload.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ExternalLinkDto {
    pub id: i32,
    #[schema(value_type = String)]
    pub provider: String,
    pub url: String,
    pub external_key: String,
    pub cached_response: Option<String>,
    #[schema(value_type = String, format = DateTime)]
    pub last_synced_at: Option<DateTime<Local>>,
    pub sync_error: Option<String>,
}

impl ExternalLinkDto {
    pub fn from_link(link: bee_core::external_links::ExternalLink) -> Self {
        let last_synced_at = link.last_synced_at.map(|dt| dt.with_timezone(&Local));
        Self {
            id: link.id,
            provider: link.provider,
            url: link.url,
            external_key: link.external_key,
            cached_response: link.cached_response,
            last_synced_at,
            sync_error: link.sync_error,
        }
    }
}

/// Create external link request.
#[derive(Debug, Deserialize, ToSchema)]
pub struct ExternalLinkCreateRequest {
    pub url: String,
}

/// File attachment response payload.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct AttachmentDto {
    pub id: i32,
    #[schema(value_type = String, format = "uuid")]
    pub uuid: Uuid,
    pub filename: String,
    pub mime_type: String,
    pub size_bytes: i64,
    #[schema(value_type = String, format = DateTime)]
    pub created_at: DateTime<Local>,
}

impl AttachmentDto {
    pub fn from_attachment(attachment: Attachment) -> Self {
        Self {
            id: attachment.id,
            uuid: attachment.uuid,
            filename: attachment.filename,
            mime_type: attachment.mime_type,
            size_bytes: attachment.size_bytes,
            created_at: attachment.created_at,
        }
    }
}

/// Email link response payload (reference to email in Apple Mail).
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct EmailLinkDto {
    pub id: i32,
    #[schema(value_type = String, format = "uuid")]
    pub uuid: Uuid,
    pub message_id: String,
    pub subject: String,
    pub sender: String,
    #[schema(value_type = String, format = DateTime)]
    pub sent_date: Option<DateTime<Local>>,
    #[schema(value_type = String, format = DateTime)]
    pub created_at: DateTime<Local>,
    pub mail_url: String,
}

impl EmailLinkDto {
    pub fn from_email_link(link: &EmailLink) -> Self {
        Self {
            id: link.get_id().unwrap_or(0),
            uuid: link.get_uuid(),
            message_id: link.get_message_id().to_string(),
            subject: link.get_subject().to_string(),
            sender: link.get_sender().to_string(),
            sent_date: link.get_sent_date(),
            created_at: link.get_created_at(),
            mail_url: link.mail_url(),
        }
    }
}

/// Important link response payload (user-defined URL attached to a task).
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ImportantLinkDto {
    pub id: i32,
    #[schema(value_type = String, format = "uuid")]
    pub uuid: Uuid,
    pub url: String,
    pub title: String,
    #[schema(value_type = String, format = DateTime)]
    pub created_at: DateTime<Local>,
}

impl ImportantLinkDto {
    pub fn from_important_link(link: &ImportantLink) -> Self {
        Self {
            id: link.get_id().unwrap_or(0),
            uuid: link.get_uuid(),
            url: link.get_url().to_string(),
            title: link.get_title().to_string(),
            created_at: link.get_created_at(),
        }
    }
}

/// Batch sync request for external links.
#[derive(Debug, Deserialize, ToSchema)]
pub struct ExternalLinkSyncRequest {
    pub provider: Option<String>,
    #[schema(value_type = String, format = "uuid")]
    pub task_uuid: Option<Uuid>,
    pub force: Option<bool>,
}

/// Sync response payload.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ExternalLinkSyncResponse {
    pub attempted: usize,
    pub succeeded: usize,
    pub failed: usize,
    pub errors: Vec<String>,
}

/// Recent GitLab merge request suggestion.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct GitlabMergeRequestDto {
    pub iid: i64,
    pub title: String,
    pub web_url: String,
    pub project_path: String,
    pub state: String,
    pub user_notes_count: Option<i64>,
    pub approved: Option<bool>,
    pub pipeline_status: Option<String>,
    #[schema(value_type = String, format = DateTime)]
    pub updated_at: DateTime<Local>,
}

/// Recent Jira issue suggestion.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct JiraIssueDto {
    pub key: String,
    pub summary: String,
    pub status: String,
    pub web_url: String,
    #[schema(value_type = String, format = DateTime)]
    pub updated_at: DateTime<Local>,
}

/// External link resolve request.
#[derive(Debug, Deserialize, ToSchema)]
pub struct ExternalLinkResolveRequest {
    pub provider: String,
    pub input: String,
}

/// External link resolve response.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ExternalLinkResolveResponse {
    pub url: String,
}

/// Token span emitted by the lexer for UI highlighting.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct TokenSpan {
    pub token_type: String,
    pub literal: String,
    pub start: usize,
    pub end: usize,
}

/// Response payload for the config endpoint.
#[derive(Debug, Serialize, ToSchema)]
pub struct ConfigResponse {
    /// Default report configuration (for backwards compatibility).
    pub report: ReportConfigDto,
    /// All available reports.
    pub reports: Vec<ReportSummary>,
}

/// Report configuration for display in the UI.
#[derive(Debug, Serialize, ToSchema)]
pub struct ReportConfigDto {
    /// Filter expressions to apply by default.
    pub filters: Vec<String>,
    /// Field names to display (technical names like "id", "summary").
    pub columns: Vec<String>,
    /// Display names for columns (human-readable like "ID", "Summary").
    pub column_names: Vec<String>,
}

/// Summary of a report for selection in the UI.
#[derive(Debug, Serialize, ToSchema)]
pub struct ReportSummary {
    /// Report name (identifier).
    pub name: String,
    /// Filter expressions for static reports (from config).
    /// Deprecated for user reports - use `filter` instead.
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub filters: Vec<String>,
    /// Serialized filter JSON for user reports (from parse API).
    /// This replaces filter expression strings and avoids re-parsing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub filter: Option<serde_json::Value>,
    /// Field names to display (technical names like "id", "summary").
    pub columns: Vec<String>,
    /// Display names for columns (human-readable like "ID", "Summary").
    pub column_names: Vec<String>,
    /// Custom column widths as JSON object.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub column_widths: Option<serde_json::Value>,
    /// Column key to sort by. None means default urgency sort.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort_column: Option<String>,
    /// Sort direction: "ascending" or "descending"
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort_direction: Option<String>,
    /// Whether this is the default report.
    pub is_default: bool,
    /// Whether this is a user-created report (vs. static from config).
    #[serde(default, skip_serializing_if = "is_false")]
    pub is_user_report: bool,
}

fn is_false(b: &bool) -> bool {
    !*b
}

// User Reports DTOs

/// Request to create or update a user report.
#[derive(Debug, Deserialize, ToSchema)]
pub struct UserReportRequest {
    /// Report name (identifier). Any printable Unicode allowed.
    pub name: String,
    /// Serialized filter JSON from parse API.
    pub filter: Option<serde_json::Value>,
    /// Field names to display (technical names like "id", "summary").
    pub columns: Vec<String>,
    /// Display names for columns (human-readable like "ID", "Summary").
    pub column_names: Vec<String>,
    /// Custom column widths as JSON object: {"column_key": width_in_pixels}
    #[serde(default)]
    pub column_widths: Option<serde_json::Value>,
    /// Column key to sort by (e.g., "status"). None means default urgency sort.
    #[serde(default)]
    pub sort_column: Option<String>,
    /// Sort direction: "ascending" or "descending"
    #[serde(default)]
    pub sort_direction: Option<String>,
}

/// Response for user report operations.
#[derive(Debug, Serialize, ToSchema)]
pub struct UserReportDto {
    /// Report name (identifier).
    pub name: String,
    /// Serialized filter JSON.
    pub filter: Option<serde_json::Value>,
    /// Field names to display.
    pub columns: Vec<String>,
    /// Display names for columns.
    pub column_names: Vec<String>,
    /// Custom column widths as JSON object.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub column_widths: Option<serde_json::Value>,
    /// Column key to sort by. None means default urgency sort.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort_column: Option<String>,
    /// Sort direction: "ascending" or "descending"
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort_direction: Option<String>,
    /// When the report was created.
    pub created_at: String,
    /// When the report was last updated.
    pub updated_at: String,
}

impl UserReportDto {
    pub fn from_user_report(report: bee_core::storage::db::UserReport) -> Self {
        Self {
            name: report.name,
            filter: report.filter,
            columns: report.columns,
            column_names: report.column_names,
            column_widths: report.column_widths,
            sort_column: report.sort_column,
            sort_direction: report.sort_direction,
            created_at: report.created_at.to_rfc3339(),
            updated_at: report.updated_at.to_rfc3339(),
        }
    }
}

/// Response for listing user reports.
#[derive(Debug, Serialize, ToSchema)]
pub struct UserReportsListResponse {
    pub reports: Vec<UserReportDto>,
}

/// Response payload for completions endpoint.
#[derive(Debug, Serialize, ToSchema)]
pub struct CompletionsResponse {
    pub items: Vec<CompletionItem>,
}

/// A single completion suggestion.
#[derive(Debug, Serialize, ToSchema)]
pub struct CompletionItem {
    /// The completion value (e.g., project name, tag name).
    pub value: String,
    /// Usage count for sorting by frequency (optional).
    pub count: Option<i64>,
}

// ============================================================================
// Project Overview DTOs
// ============================================================================

/// Statistics breakdown for a single project.
#[derive(Clone, Debug, Default, Serialize, Deserialize, ToSchema)]
pub struct ProjectStatsDto {
    /// Display name (leaf name, e.g., "api" for "backend.api").
    pub name: String,
    /// Number of pending tasks.
    pub pending_count: i64,
    /// Number of active tasks.
    pub active_count: i64,
    /// Number of completed tasks.
    pub completed_count: i64,
    /// Number of overdue tasks (pending/active with past due date).
    pub overdue_count: i64,
    /// Total task count.
    pub total_count: i64,
    /// Optional emoji for visual identification (single emoji character).
    pub emoji: Option<String>,
    /// Optional hex color for project theming (e.g., "#FF5733").
    pub color: Option<String>,
}

/// Hierarchical project node with nested children.
#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct ProjectNodeDto {
    /// Display name (leaf name, e.g., "api").
    pub name: String,
    /// Full path with dot notation (e.g., "backend.api").
    pub full_path: String,
    /// Optional emoji for visual identification (single emoji character).
    pub emoji: Option<String>,
    /// Optional hex color for project theming (e.g., "#FF5733").
    pub color: Option<String>,
    /// Statistics for this project (including children aggregated).
    pub stats: ProjectStatsDto,
    /// Child projects.
    pub children: Vec<ProjectNodeDto>,
}

/// Response payload for GET /v1/projects.
#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct ProjectsResponse {
    /// Hierarchical list of top-level projects.
    pub projects: Vec<ProjectNodeDto>,
}

/// Single data point for burndown chart.
#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct BurndownDataPoint {
    /// Date in YYYY-MM-DD format.
    pub date: String,
    /// Cumulative completed tasks up to this date.
    pub completed_cumulative: i64,
    /// Remaining tasks (total - completed cumulative).
    pub remaining: i64,
}

/// Response payload for GET /v1/projects/{name}/burndown.
#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct ProjectBurndownResponse {
    /// Project name (full path).
    pub project: String,
    /// Data points for the burndown chart (sorted by date ascending).
    pub data_points: Vec<BurndownDataPoint>,
    /// Total tasks in this project (historical max).
    pub total_tasks: i64,
    /// Total completed tasks.
    pub total_completed: i64,
}

// ==================== Profile DTOs ====================

/// Profile information.
#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct ProfileDto {
    /// Profile key (lowercase identifier).
    pub key: String,
    /// Display name for the profile.
    pub name: String,
    /// Optional description.
    pub description: String,
    /// Path to the data directory.
    pub data_dir: String,
    /// Path to the config directory.
    pub config_dir: String,
}

/// Response payload for GET /v1/profiles.
#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct ProfilesListResponse {
    /// List of configured profiles.
    pub profiles: Vec<ProfileDto>,
}

/// Request payload for POST /v1/profiles.
#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct ProfileCreateRequest {
    /// Profile key (lowercase, alphanumeric with hyphens).
    pub key: String,
    /// Optional display name. Defaults to key if not provided.
    pub name: Option<String>,
    /// Optional description.
    pub description: Option<String>,
}

// ============================================================================
// Project Update DTOs
// ============================================================================

/// Request payload for PATCH /v1/projects/{name}.
#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct UpdateProjectRequest {
    /// Optional emoji for visual identification (single emoji character).
    /// Set to null to clear the emoji.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub emoji: Option<Option<String>>,
    /// Optional hex color for project theming (e.g., "#FF5733").
    /// Set to null to clear the color.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub color: Option<Option<String>>,
}

/// Response payload for PATCH /v1/projects/{name}.
#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct UpdateProjectResponse {
    /// Project name (full path).
    pub name: String,
    /// Updated emoji (if set).
    pub emoji: Option<String>,
    /// Updated color (if set).
    pub color: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::ApiTask;
    use bee_core::task::{TaskData, TaskProperties, TaskStatus};

    #[test]
    fn test_api_task_from_task() {
        let mut data = TaskData::default();
        let props = TaskProperties::from(&["demo summary +tag project:demo".to_string()]).unwrap();
        let task = data
            .add_task(&props, TaskStatus::Pending)
            .expect("task should be created");

        let api_task = ApiTask::from_task(task);
        assert_eq!(api_task.summary, "demo summary");
        assert_eq!(api_task.status, TaskStatus::Pending);
        assert_eq!(api_task.project.as_deref(), Some("demo"));
        assert_eq!(api_task.tags, vec!["tag".to_string()]);
    }
}
