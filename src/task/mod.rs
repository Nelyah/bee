pub mod filters;

mod lexer;
mod parser;
mod task_prop_parser;
use task_prop_parser::TaskPropertyParser;

use std::{collections::HashSet, fmt};

use chrono::prelude::DateTime;
use serde_json::Value;
use uuid::Uuid;

use chrono::Local;
use serde::{ser::Serializer, Deserialize, Deserializer, Serialize};
use std::collections::HashMap;

use lexer::Lexer;

use filters::Filter;

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
#[derive(Default, PartialEq, Debug, serde::Deserialize)]
pub struct TaskProperties {
    summary: Option<String>,
    tags_remove: Option<Vec<String>>,
    tags_add: Option<Vec<String>>,
    status: Option<TaskStatus>,
    annotation: Option<String>,
    project: Option<Project>,
    #[serde(default)]
    date_due: Option<DateTime<chrono::Local>>,
}

// We implement a specific function for annotate because we cannot know how to differenciate
// it from a description
impl TaskProperties {
    pub fn set_annotate(&mut self, value: String) {
        self.annotation = Some(value);
    }

    pub fn from(values: &[String]) -> Result<TaskProperties, String> {
        let lexer = Lexer::new(values.join(" "));
        let mut parser = TaskPropertyParser::new(lexer);
        parser.parse_task_properties()
    }
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize, PartialEq, Eq)]
pub struct TaskAnnotation {
    value: String,
    time: DateTime<chrono::Local>,
}

impl TaskAnnotation {
    pub fn get_value(&self) -> &String {
        &self.value
    }

    pub fn get_time(&self) -> &DateTime<chrono::Local> {
        &self.time
    }
}

#[derive(Default, Clone, serde::Serialize, serde::Deserialize, Debug)]
pub struct Task {
    id: Option<usize>,
    status: TaskStatus,
    uuid: Uuid,
    summary: String,
    #[serde(default)]
    annotations: Vec<TaskAnnotation>,
    tags: Vec<String>,
    date_created: DateTime<chrono::Local>,
    #[serde(default)]
    date_completed: Option<DateTime<chrono::Local>>,
    sub: Vec<Uuid>,
    project: Option<Project>,
    #[serde(default)]
    date_due: Option<DateTime<chrono::Local>>,
}

impl Task {
    pub fn get_id(&self) -> Option<usize> {
        self.id
    }

    pub fn get_annotations(&self) -> &Vec<TaskAnnotation> {
        &self.annotations
    }

    pub fn get_summary(&self) -> &str {
        &self.summary
    }

    pub fn set_summary(&mut self, value: &str) {
        self.summary = value.to_owned();
    }

    pub fn get_tags(&self) -> &Vec<String> {
        &self.tags
    }

    pub fn get_project(&self) -> &Option<Project> {
        &self.project
    }

    pub fn get_status(&self) -> &TaskStatus {
        &self.status
    }

    pub fn get_date_created(&self) -> &DateTime<Local> {
        &self.date_created
    }

    pub fn get_date_completed(&self) -> &Option<DateTime<Local>> {
        &self.date_completed
    }

    pub fn get_date_due(&self) -> &Option<DateTime<Local>> {
        &self.date_due
    }

    pub fn get_uuid(&self) -> &Uuid {
        &self.uuid
    }

    pub fn apply(&mut self, props: &TaskProperties) {
        if let Some(summary) = &props.summary {
            self.summary = summary.clone();
        }

        if let Some(date_due) = &props.date_due {
            self.date_due = Some(date_due.to_owned());
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

        if let Some(ann) = &props.annotation {
            self.annotations.push(TaskAnnotation {
                value: ann.to_string(),
                time: Local::now(),
            });
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

#[derive(Clone, Default, Serialize, Deserialize, PartialEq, Debug)]
pub struct Project {
    name: String,
}

impl Project {
    pub fn get_name(&self) -> &String {
        &self.name
    }

    pub fn from(value: String) -> Project {
        Project { name: value }
    }
}

impl fmt::Display for Project {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.name)
    }
}

#[derive(Default)]
pub struct TaskData {
    tasks: HashMap<Uuid, Task>,
    undos: HashMap<Uuid, Task>,
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

    pub fn set_undos(&mut self, tasks: &Vec<Task>) {
        for t in tasks {
            let uuid = *t.get_uuid();
            self.undos.insert(uuid, t.clone());
        }
    }

    pub fn get_undos(&self) -> &HashMap<Uuid, Task> {
        &self.undos
    }

    pub fn task_done(&mut self, uuid: &Uuid) {
        self.tasks.get_mut(uuid).unwrap().done();
    }

    pub fn task_delete(&mut self, uuid: &Uuid) {
        self.tasks.get_mut(uuid).unwrap().delete();
    }

    pub fn upkeep(&mut self) {
        let mut vec: Vec<_> = self.tasks.values().by_ref().collect();

        vec.sort_by(|lhs, rhs| lhs.date_created.cmp(&rhs.date_created));
        let uuids: Vec<Uuid> = vec.iter().map(|t| t.uuid).collect();
        let mut i = 1;
        for cur_uuid in uuids {
            let t: &mut Task = self.tasks.get_mut(&cur_uuid).unwrap();
            match t.status {
                TaskStatus::Pending => {
                    self.tasks.get_mut(&cur_uuid).unwrap().id = Some(i);
                    i += 1;
                }
                TaskStatus::Deleted | TaskStatus::Completed => {
                    self.tasks.get_mut(&cur_uuid).unwrap().id = None;
                }
            }
        }
    }

    #[allow(clippy::borrowed_box)]
    pub fn filter(&self, filter: &Box<dyn Filter>) -> Self {
        let mut new_data = TaskData {
            tasks: HashMap::new(),
            undos: HashMap::new(),
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
    ) -> Result<&Task, String> {
        // This allows the user to override the default status of the task being
        // created (defined by the caller of this function, usually Pending)
        let status = match &props.status {
            Some(st) => st,
            None => &status,
        }
        .clone();
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

        let date_due = props.date_due.as_ref().map(|date| date.to_owned());

        let project = props.project.to_owned();

        let summary = match &props.summary {
            Some(summary) => summary.to_owned(),
            None => return Err("A task must have a summary".to_owned()),
        };

        let tags = match &props.tags_add {
            Some(tags) => tags.to_owned(),
            None => Vec::default(),
        };

        let t = Task {
            summary,
            id: new_id,
            status,
            uuid: Uuid::new_v4(),
            tags,
            date_created: Local::now(),
            date_completed,
            annotations: Vec::default(),
            sub: Vec::default(),
            date_due,
            project,
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
            undos: HashMap::new(),
            max_id,
        })
    }
}

#[cfg(test)]
#[path = "manager_test.rs"]
mod manager_test;
