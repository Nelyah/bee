use chrono::prelude::DateTime;
use serde_json::Value;
use uuid::Uuid;

#[path = "task_test.rs"]
#[cfg(test)]
mod task_test;

#[derive(Clone, Debug, PartialEq, PartialOrd, serde::Serialize, serde::Deserialize)]
pub enum TaskStatus {
    PENDING,
    COMPLETED,
    DELETED,
}

impl Default for TaskStatus {
    fn default() -> TaskStatus {
        TaskStatus::PENDING
    }
}

impl TaskStatus {
    pub fn from_string(input: &str) -> Result<TaskStatus, String> {
        match input.to_lowercase().as_str() {
            "pending" => Ok(TaskStatus::PENDING),
            "completed" => Ok(TaskStatus::COMPLETED),
            "deleted" => Ok(TaskStatus::DELETED),
            _ => Err("Invalid task status".to_string()),
        }
    }

    pub fn to_string(&self) -> String {
        match self {
            TaskStatus::PENDING => "pending".to_string(),
            TaskStatus::COMPLETED => "completed".to_string(),
            TaskStatus::DELETED => "deleted".to_string(),
        }
    }
}

#[derive(Default, Clone, serde::Serialize, serde::Deserialize)]
pub struct Task {
    pub id: Option<usize>,
    pub status: TaskStatus,
    pub uuid: Uuid,
    pub description: String,
    pub tags: Vec<String>,
    pub date_created: DateTime<chrono::Local>,
    #[serde(default)]
    pub date_completed: Option<DateTime<chrono::Local>>,
    pub sub: Vec<Uuid>,
}

impl Task {
    pub fn get_id(&self) -> Option<usize> {
        self.id
    }

    pub fn get_uuid(&self) -> &Uuid {
        &self.uuid
    }

    pub fn get_field(&self, field_name: &str) -> Value {
        let v = serde_json::to_value(self).unwrap();
        if let Some(value) = v.get(field_name) {
            value.clone()
        } else {
            panic!("Could not get the value of '{}'", field_name);
        }
    }
}
