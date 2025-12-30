use bee_core::task::{Task, TaskStatus};
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
            let mut task = task.clone();
            task.get_urgency().ok()
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
        let last_synced_at = link
            .last_synced_at
            .map(|dt| dt.with_timezone(&Local));
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
    pub report: ReportConfigDto,
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
