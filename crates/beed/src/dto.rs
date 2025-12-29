use bee_core::task::{Task, TaskStatus};
use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct ActionRequest {
    pub action: String,
    pub properties: Option<Value>,
    pub filter: Option<Value>,
}

#[derive(Debug, Serialize)]
pub struct ActionResponse {
    pub action: String,
    pub tasks: Vec<ApiTask>,
    pub events: Vec<ApiEvent>,
}

#[derive(Debug, Deserialize)]
pub struct ParseRequest {
    pub input: String,
}

#[derive(Debug, Serialize)]
pub struct ParseResponse {
    pub action: String,
    pub properties: Option<Value>,
    pub filter: Option<Value>,
    pub tokens: Vec<TokenSpan>,
}

#[derive(Debug, Serialize, Clone)]
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

#[derive(Debug, Serialize)]
pub struct ApiTask {
    pub id: Option<i32>,
    pub uuid: Uuid,
    pub status: TaskStatus,
    pub summary: String,
    pub project: Option<String>,
    pub tags: Vec<String>,
    pub date_created: DateTime<Local>,
    pub date_completed: Option<DateTime<Local>>,
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

#[derive(Debug, Serialize)]
pub struct TokenSpan {
    pub token_type: String,
    pub literal: String,
    pub start: usize,
    pub end: usize,
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
