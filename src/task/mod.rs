mod parser;
use std::{collections::HashSet, fmt};

use chrono::prelude::DateTime;
use serde_json::Value;
use uuid::Uuid;

use chrono::Local;
use serde::{ser::Serializer, Deserialize, Deserializer, Serialize};
use std::collections::HashMap;

use crate::lexer::Lexer;

use super::filters::Filter;

#[path = "task_test.rs"]
#[cfg(test)]
mod task_test;

#[derive(Clone, Debug, PartialEq, PartialOrd, serde::Serialize, serde::Deserialize, Default)]
pub enum TaskStatus {
    #[default]
    Pending,
    Completed,
    Deleted,
}

impl TaskStatus {
    pub fn from_string(input: &str) -> Result<TaskStatus, String> {
        match input.to_lowercase().as_str() {
            "pending" => Ok(TaskStatus::Pending),
            "completed" => Ok(TaskStatus::Completed),
            "deleted" => Ok(TaskStatus::Deleted),
            _ => Err("Invalid task status name".to_string()),
        }
    }
}

impl fmt::Display for TaskStatus {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            TaskStatus::Pending => write!(f, "pending"),
            TaskStatus::Completed => write!(f, "completed"),
            TaskStatus::Deleted => write!(f, "deleted"),
        }
    }
}

// This structure contains information regarding setting fields for a Task
// that can be parsed from a user query, i.e. from the command line
// It only contains the fields that can be set by a User
#[derive(Default, PartialEq, Debug)]
pub struct TaskProperties {
    description: Option<String>,
    tags_remove: Option<Vec<String>>,
    tags_add: Option<Vec<String>>,
    status: Option<TaskStatus>,
}

impl TaskProperties {
    pub fn from(values: &[String]) -> TaskProperties {
        let lexer = Lexer::new(values.join(" "));
        let mut parser = parser::Parser::new(lexer);
        parser.parse_task_properties()
    }
}

#[derive(Default, Clone, serde::Serialize, serde::Deserialize)]
pub struct Task {
    id: Option<usize>,
    status: TaskStatus,
    uuid: Uuid,
    description: String,
    tags: Vec<String>,
    date_created: DateTime<chrono::Local>,
    #[serde(default)]
    date_completed: Option<DateTime<chrono::Local>>,
    sub: Vec<Uuid>,
}

impl Task {
    pub fn get_id(&self) -> Option<usize> {
        self.id
    }

    pub fn get_description(&self) -> &str {
        &self.description
    }

    pub fn set_description(&mut self, value: &str) {
        self.description = value.to_owned();
    }

    pub fn get_tags(&self) -> &Vec<String> {
        &self.tags
    }

    pub fn get_status(&self) -> &TaskStatus {
        &self.status
    }

    pub fn get_uuid(&self) -> &Uuid {
        &self.uuid
    }

    pub fn apply(&mut self, props: &TaskProperties) {
        if let Some(desc) = &props.description {
            self.description = desc.clone();
        }

        if let Some(status) = &props.status {
            self.status = status.to_owned();
        }

        if let Some(tags) = &props.tags_remove {
            let s: HashSet<String> = tags.iter().cloned().collect();
            self.tags.retain(|item| !s.contains(item));
        }

        if let Some(tags) = &props.tags_add {
            let existing_tags: HashSet<String> = self.tags.drain(..).collect();
            let new_tags: HashSet<String> = tags.iter().cloned().collect();
            self.tags = existing_tags.union(&new_tags).cloned().collect();
        }
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
        self.status = TaskStatus::Deleted;
        self.id = None;
    }

    pub fn done(&mut self) {
        self.status = TaskStatus::Completed;
        self.date_completed = Some(Local::now());
        self.id = None;
    }
}

#[derive(Default)]
pub struct TaskData {
    tasks: HashMap<Uuid, Task>,
    max_id: usize,
}

impl TaskData {
    pub fn get_task_map(&self) -> &HashMap<Uuid, Task> {
        &self.tasks
    }

    pub fn to_vec(&self) -> Vec<&Task> {
        self.tasks.values().collect()
    }

    pub fn apply(&mut self, task_uuid: &Uuid, props: &TaskProperties) {
        self.tasks.get_mut(task_uuid).unwrap().apply(props);
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

    #[allow(clippy::borrowed_box)]
    pub fn filter(&self, filter: &Box<dyn Filter>) -> Self {
        let mut new_data = TaskData {
            tasks: HashMap::new(),
            max_id: self.max_id,
        };

        for (key, task) in &self.tasks {
            if filter.validate_task(task) {
                new_data.tasks.insert(key.to_owned(), task.to_owned());
            }
        }

        new_data
    }

    pub fn add_task(
        &mut self,
        props: &TaskProperties,
        status: TaskStatus,
    ) -> Result<&Task, String>  {
        // This allows the user to override the default status of the task being
        // created (defined by the caller of this function, usually Pending)
        let status = match &props.status {
            Some(st) => st,
            None => &status,
        }.clone();
        let new_id: Option<usize> = match status {
            TaskStatus::Pending => {
                self.max_id += 1;
                Some(self.max_id)
            }
            TaskStatus::Completed | TaskStatus::Deleted => None,
        };

        let date_completed: Option<DateTime<chrono::Local>> = match status {
            TaskStatus::Pending => None,
            TaskStatus::Completed | TaskStatus::Deleted => Some(Local::now()),
        };

        let description = match &props.description {
            Some(desc) => desc.to_owned(),
            None => {return Err("A task must have a description".to_owned())},
        };

        let tags = match &props.tags_add {
            Some(tags) => tags.to_owned(),
            None => Vec::default(),
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
        Ok(self.tasks.get(&owned_uuid).unwrap())
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
