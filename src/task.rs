use std::fmt;

use chrono::prelude::DateTime;
use serde_json::Value;
use uuid::Uuid;

use chrono::Local;
use serde::{ser::Serializer, Deserialize, Deserializer, Serialize};
use std::collections::HashMap;

use super::filters::{validate_task, Filter};

#[path = "task_test.rs"]
#[cfg(test)]
mod task_test;

#[derive(Clone, Debug, PartialEq, PartialOrd, serde::Serialize, serde::Deserialize, Default)]
pub enum TaskStatus {
    #[default]
    PENDING,
    COMPLETED,
    DELETED,
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
}

impl fmt::Display for TaskStatus {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            TaskStatus::PENDING => write!(f, "pending"),
            TaskStatus::COMPLETED => write!(f, "completed"),
            TaskStatus::DELETED => write!(f, "deleted"),
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

    pub fn delete(&mut self) {
        self.status = TaskStatus::DELETED;
        self.id = None;
    }

    pub fn done(&mut self) {
        self.status = TaskStatus::COMPLETED;
        self.id = None;
    }
}

#[derive(Default)]
pub struct TaskData {
    pub tasks: HashMap<Uuid, Task>,
    max_id: usize,
}

impl TaskData {
    pub fn get_task_map(&self) -> &HashMap<Uuid, Task> {
        &self.tasks
    }

    pub fn to_vec(&self) -> Vec<&Task> {
        self.tasks.values().collect()
    }

    pub fn set_task(&mut self, task: Task) {
        self.tasks.insert(*task.get_uuid(), task.clone());
    }

    pub fn has_uuid(&self, uuid: &Uuid) -> bool {
        self.tasks.contains_key(uuid)
    }

    pub fn task_done(&mut self, uuid: &Uuid) {
        self.tasks.get_mut(uuid).unwrap().done();
    }

    pub fn task_delete(&mut self, uuid: &Uuid) {
        self.tasks.get_mut(uuid).unwrap().delete();
    }

    pub fn filter(&self, filter: &Filter) -> Self {
        let mut new_data = TaskData {
            tasks: HashMap::new(),
            max_id: self.max_id,
        };

        for (key, task) in &self.tasks {
            if validate_task(task, filter) {
                new_data.tasks.insert(key.to_owned(), task.to_owned());
            }
        }

        new_data
    }

    pub fn add_task(
        &mut self,
        description: String,
        tags: Vec<String>,
        status: TaskStatus,
    ) -> &Task {
        let new_id: Option<usize> = match status {
            TaskStatus::PENDING => {
                self.max_id += 1;
                Some(self.max_id)
            }
            TaskStatus::COMPLETED | TaskStatus::DELETED => None,
        };

        let date_completed: Option<DateTime<chrono::Local>> = match status {
            TaskStatus::PENDING => None,
            TaskStatus::COMPLETED | TaskStatus::DELETED => Some(Local::now()),
        };

        let t = Task {
            description,
            id: new_id,
            status,
            uuid: Uuid::new_v4(),
            tags,
            date_created: Local::now(),
            date_completed,
            sub: Vec::default(),
        };
        let owned_uuid = t.get_uuid().to_owned();
        self.tasks.insert(owned_uuid, t);
        self.tasks.get(&owned_uuid).unwrap()
    }
}

impl Serialize for TaskData {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut tasks: Vec<&Task> = self.tasks.values().collect();
        tasks.sort_by(|lhs, rhs| lhs.date_created.cmp(&rhs.date_created));
        tasks.serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for TaskData {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let tasks: Vec<Task> = Deserialize::deserialize(deserializer)?;

        let task_map: HashMap<Uuid, Task> = tasks
            .into_iter()
            .map(|t| (t.get_uuid().to_owned(), t))
            .collect();
        let max_id = task_map
            .values()
            .filter_map(|t| t.get_id())
            .max()
            .unwrap_or(0);

        Ok(TaskData {
            tasks: task_map,
            max_id,
        })
    }
}

#[cfg(test)]
#[path = "manager_test.rs"]
mod manager_test;
