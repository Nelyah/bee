use chrono::prelude::DateTime;
use std::any::Any;
use uuid::Uuid;

#[path = "task_test.rs"]
#[cfg(test)]
mod task_test;

use crate::operation::{GenerateOperation, Operation};

// TODO: Task need to have:
// - Due date
// - Project
// - Link to other tasks (RelatesTo, Blocks, Depend, etc.)

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
    pub fn from_str(input: &str) -> Result<TaskStatus, String> {
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

impl GenerateOperation for Task {
    fn generate_operation<T: Any>(&self, other: &dyn Any) -> Operation {
        let mut operation = Operation::default();
        let other_task = other
            .downcast_ref::<Task>()
            .expect("Could not downcast `other' into a Task");

        let self_fields = serde_json::to_value(self).expect("Failed to serialize self");
        let other_fields =
            serde_json::to_value(other_task).expect("Failed to serialize other_task");

        let field_names = self_fields
            .as_object()
            .expect("Failed to retrieve field names");

        for (field_name, self_value) in field_names.iter() {
            if field_name == "id" {
                continue;
            }

            let other_value = other_fields.get(field_name).expect(&format!(
                "Could not get the field {} from the other task",
                field_name
            ));

            if self_value != other_value {
                let input = serde_json::to_vec(self_value).expect(&format!(
                    "Failed to serialize field `{}' from input task",
                    field_name
                ));
                let output = serde_json::to_vec(other_value).expect(&format!(
                    "Failed to serialize field `{}' from output task",
                    field_name
                ));
                operation.input.insert(field_name.to_owned(), input);
                operation.output.insert(field_name.to_owned(), output);
            }
        }

        operation
    }

    fn apply_operation(&mut self, operation: &Operation) -> Result<(), String> {
        // TODO: The Err should be a merge conflict
        for (key, value) in &operation.input {
            match key.as_str() {
                "id" | "uuid" | "date_created" => {
                    panic!("Trying to update either one of `id', `uuid' or `date_created' field.");
                }
                "status" => {
                    let input_status: TaskStatus = serde_json::from_slice(&value)
                        .map_err(|e| format!("Error deserializing 'status': {}", e))?;
                    if self.status != input_status {
                        return Err("Error: operation.input 'status' does not match self.status"
                            .to_string());
                    }
                }
                "description" => {
                    let input_description: String = serde_json::from_slice(&value)
                        .map_err(|e| format!("Error deserializing 'description': {}", e))?;
                    if self.description != input_description {
                        return Err(
                            "Error: operation.input 'description' does not match self.description"
                                .to_string(),
                        );
                    }
                }
                "tags" => {
                    let input_tags: Vec<String> = serde_json::from_slice(&value)
                        .map_err(|e| format!("Error deserializing 'tags': {}", e))?;
                    if self.tags != input_tags {
                        return Err(
                            "Error: operation.input 'tags' does not match self.tags".to_string()
                        );
                    }
                }
                "date_completed" => {
                    let input_date_completed: Option<DateTime<chrono::Local>> =
                        serde_json::from_slice(&value)
                            .map_err(|e| format!("Error deserializing 'date_completed': {}", e))?;
                    if self.date_completed != input_date_completed {
                        return Err("Error: operation.input 'date_completed' does not match self.date_completed".to_string());
                    }
                }
                "sub" => {
                    let input_sub: Vec<Uuid> = serde_json::from_slice(&value)
                        .map_err(|e| format!("Error deserializing 'sub': {}", e))?;
                    if self.sub != input_sub {
                        return Err(
                            "Error: operation.input 'sub' does not match self.sub".to_string()
                        );
                    }
                }
                _ => {
                    panic!("Error: trying to update an unknown field: '{}'", key);
                }
            }
        }

        for (key, value) in &operation.output {
            match key.as_str() {
                "id" => panic!("Error: the `id' field should not be updated by an operation"),
                "uuid" => panic!("Error: the `uuid' field should not be updated by an operation"),
                "date_created" => {
                    panic!("Error: the `date_created' field should not be updated by an operation")
                }
                "status" => {
                    self.status =
                        serde_json::from_slice(&value).expect("Error deserialising `status'");
                }
                "description" => {
                    self.description =
                        serde_json::from_slice(&value).expect("Error deserialising `description'");
                }
                "tags" => {
                    self.tags = serde_json::from_slice(&value).expect("Error deserialising `tags'")
                }
                "date_completed" => {
                    self.date_completed = serde_json::from_slice(&value)
                        .expect("Error deserialising `date_completed'");
                }
                "sub" => {
                    self.sub = serde_json::from_slice(&value).expect("Error deserialising `sub'")
                }
                _ => {
                    panic!("Error: trying to update an unknown field");
                }
            }
        }

        Ok(())
    }
}
