use chrono::Local;
use chrono::prelude::DateTime;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use strum::{Display, EnumString};
use uuid::Uuid;

use std::collections::HashSet;
use std::{cmp::Ordering, fmt};

use super::task_properties::TaskProperties;

#[derive(
    Clone,
    Debug,
    PartialEq,
    serde::Serialize,
    serde::Deserialize,
    Default,
    Eq,
    PartialOrd,
    Ord,
    Hash,
)]
pub enum TaskStatus {
    #[default]
    Pending,
    Active,
    Completed,
    Deleted,
    Blocked,
}

impl TaskStatus {
    pub fn from_string(input: &str) -> Result<TaskStatus, String> {
        match input.to_lowercase().as_str() {
            "active" => Ok(TaskStatus::Active),
            "pending" => Ok(TaskStatus::Pending),
            "completed" => Ok(TaskStatus::Completed),
            "deleted" => Ok(TaskStatus::Deleted),
            "blocked" => Ok(TaskStatus::Blocked),
            _ => Err("Invalid task status name".to_string()),
        }
    }

    /// Returns the uppercase string representation used in the database
    pub fn to_db_string(&self) -> String {
        match self {
            TaskStatus::Active => "ACTIVE".to_string(),
            TaskStatus::Pending => "PENDING".to_string(),
            TaskStatus::Completed => "COMPLETED".to_string(),
            TaskStatus::Deleted => "DELETED".to_string(),
            TaskStatus::Blocked => "BLOCKED".to_string(),
        }
    }
}

impl fmt::Display for TaskStatus {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            TaskStatus::Active => write!(f, "active"),
            TaskStatus::Pending => write!(f, "pending"),
            TaskStatus::Completed => write!(f, "completed"),
            TaskStatus::Deleted => write!(f, "deleted"),
            TaskStatus::Blocked => write!(f, "blocked"),
        }
    }
}

#[derive(Display, EnumString, Default, Debug, PartialEq, Eq, Serialize, Deserialize, Clone)]
pub enum ActionUndoType {
    Add,
    #[default]
    Modify,
}

#[derive(Default, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ActionUndo {
    pub action_type: ActionUndoType,
    pub tasks: Vec<Task>,
}

#[derive(Clone, PartialEq, Debug, serde::Serialize, serde::Deserialize)]
pub enum DependsOnIdentifier {
    Id(i32),
    Uuid(Uuid),
}

#[derive(
    Clone,
    Debug,
    serde::Serialize,
    serde::Deserialize,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
    Hash,
    Default,
)]
pub struct TaskAnnotation {
    /// ID to serve as primary key in the DB
    pub(crate) id: Option<i32>,
    pub(crate) value: String,
    pub(crate) time: DateTime<chrono::Local>,
}

impl TaskAnnotation {
    pub fn get_value(&self) -> &String {
        &self.value
    }

    pub fn get_time(&self) -> &DateTime<chrono::Local> {
        &self.time
    }
}

#[derive(
    Display,
    EnumString,
    Clone,
    Debug,
    serde::Serialize,
    serde::Deserialize,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
    Hash,
)]
pub enum LinkType {
    DependsOn,
    Blocking,
}

#[derive(
    Clone, Debug, serde::Serialize, serde::Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash,
)]
pub struct Link {
    /// ID to serve as primary key in the DB
    pub(crate) id: Option<i32>,
    pub(crate) from: Uuid,
    pub(crate) to: Uuid,
    pub(crate) link_type: LinkType,
}

#[derive(
    Clone,
    Debug,
    serde::Serialize,
    serde::Deserialize,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
    Hash,
    Default,
)]
pub struct TaskHistory {
    /// ID to serve as primary key in the DB
    pub(crate) id: Option<i32>,
    pub(crate) value: String,
    pub(crate) datetime: DateTime<chrono::Local>,
}

impl TaskHistory {
    pub fn get_value(&self) -> &String {
        &self.value
    }

    pub fn get_datetime(&self) -> &DateTime<chrono::Local> {
        &self.datetime
    }
}

#[derive(
    Clone, Debug, serde::Serialize, serde::Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash,
)]
pub struct Task {
    pub(crate) id: Option<i32>,
    pub(crate) db_id: Option<i32>,
    pub(crate) status: TaskStatus,
    pub(crate) uuid: Uuid,
    pub(crate) summary: String,
    #[serde(default)]
    pub(crate) annotations: Vec<TaskAnnotation>,
    #[serde(default)]
    pub(crate) tags: Vec<String>,
    pub(crate) date_created: DateTime<chrono::Local>,
    pub(crate) date_completed: Option<DateTime<chrono::Local>>,
    pub(crate) date_due: Option<DateTime<chrono::Local>>,
    pub(crate) urgency: Option<i64>,
    pub(crate) project: Option<Project>,
    #[serde(default)]
    pub(crate) links: Vec<Link>,
    #[serde(default)]
    pub(crate) history: Vec<TaskHistory>,
}

impl Default for Task {
    fn default() -> Task {
        Task {
            id: None,
            db_id: None,
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            summary: "".to_string(),
            annotations: Vec::default(),
            tags: Vec::default(),
            date_created: Local::now(),
            date_completed: None,
            date_due: None,
            urgency: None,
            project: None,
            links: Vec::default(),
            history: Vec::default(),
        }
    }
}

impl Task {
    pub fn get_id(&self) -> Option<i32> {
        self.id
    }

    pub fn get_depends_on(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|link| link.link_type == LinkType::DependsOn)
            .map(|link| &link.to)
            .collect()
    }

    pub fn depends_on(&self, uuid: &Uuid) -> bool {
        self.get_depends_on().iter().any(|&id| id == uuid)
    }

    pub fn get_blocking(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|link| link.link_type == LinkType::Blocking)
            .map(|link| &link.to)
            .collect()
    }

    pub fn has_property(&self, prop: &String) -> bool {
        let p = prop.to_lowercase();
        match p.as_str() {
            "active" => self.status == TaskStatus::Active,
            "pending" => self.status == TaskStatus::Pending,
            "completed" => self.status == TaskStatus::Completed,
            "deleted" => self.status == TaskStatus::Deleted,
            "blocked" => self.status == TaskStatus::Blocked,
            _ => false,
        }
    }

    pub fn compare_urgency(&self, other: &Task) -> Ordering {
        match self.urgency {
            Some(urgency) => match other.urgency {
                Some(other_urgency) => urgency.cmp(&other_urgency),
                None => Ordering::Greater,
            },
            None => match other.urgency {
                Some(_) => Ordering::Less,
                None => Ordering::Equal,
            },
        }
    }

    pub fn compute_urgency(&mut self) -> Result<i64, String> {
        if self.status == TaskStatus::Deleted {
            return Err("Cannot compute urgency for deleted task".to_string());
        }

        let active_status_coef: i64 = 2;

        let mut urgency: i64 = 0;
        for tag in &self.tags {
            if tag == "next" {
                urgency += 1;
            }
        }

        if self.status == TaskStatus::Active {
            urgency += active_status_coef;
        }

        // Compute number of days remaining until the due date
        if let Some(date_due) = self.date_due {
            let now = Local::now();
            let days = date_due.signed_duration_since(now).num_days();
            urgency += days;
        }

        self.urgency = Some(urgency);
        Ok(self.urgency.unwrap())
    }

    pub fn get_history(&self) -> &Vec<TaskHistory> {
        &self.history
    }

    pub fn get_annotations(&self) -> &Vec<TaskAnnotation> {
        &self.annotations
    }

    pub fn get_summary(&self) -> &str {
        &self.summary
    }

    // TODO: To remove, only used in tests
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

    /// Send back a list of the UUID that this task knows about or refers to
    pub fn get_extra_uuid(&self) -> Vec<Uuid> {
        let mut uuids = [
            self.get_depends_on()
                .into_iter()
                .cloned()
                .collect::<Vec<_>>(),
            self.get_blocking().into_iter().cloned().collect::<Vec<_>>(),
        ]
        .concat();
        uuids.sort_unstable();
        uuids.dedup();
        uuids
    }

    pub(crate) fn apply(&mut self, props: &TaskProperties) -> Result<(), String> {
        if let Some(summary) = &props.summary {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: format!("Summary changed from '{}' to '{}'.", self.summary, summary),
            });
            self.summary = summary.clone();
        }

        if let Some(date_due) = &props.date_due {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: format!("Due date set to {}", date_due),
            });
            self.date_due = Some(date_due.to_owned());
        }

        if let Some(active) = &props.active_status {
            if *active {
                if self.status != TaskStatus::Pending {
                    return Err(format!(
                        "Task '{}' status cannot be set to 'ACTIVE' because its status is already 'ACTIVE'",
                        self.summary
                    ));
                }
                self.status = TaskStatus::Active;
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: "Status changed from 'PENDING' to 'ACTIVE'".to_string(),
                });
            } else {
                if self.status != TaskStatus::Active {
                    return Err(format!(
                        "Task '{}' status cannot be 'stopped' because its status is not 'ACTIVE'",
                        self.summary
                    ));
                }
                self.status = TaskStatus::Pending;
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: "Status changed from 'ACTIVE' to 'PENDING'".to_string(),
                });
            }
        }

        if let Some(status) = &props.status {
            if &self.status != status {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!("Status changed from '{}' to '{}'", self.status, status),
                });
            }
            self.status = status.to_owned();
        }

        if let Some(proj_option) = &props.project {
            if let Some(proj) = proj_option {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!("Project set to '{}'", proj),
                });
                self.project = Some(proj.to_owned());
            } else {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: "Project has been unset".to_string(),
                });
                self.project = None;
            }
        }

        if let Some(tags) = &props.tags_remove {
            let s: HashSet<String> = tags.iter().cloned().collect();
            let mut removed_tags: Vec<String> = Vec::new();
            self.tags.retain(|item| {
                if s.contains(item) {
                    removed_tags.push(item.clone());
                    false
                } else {
                    true
                }
            });

            if !removed_tags.is_empty() {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!("Removed tag(s) '{}'", removed_tags.join(", ")),
                });
            }
        }

        if let Some(tags) = &props.tags_add {
            let existing_tags: HashSet<String> = self.tags.drain(..).collect();
            let new_tags: HashSet<String> = tags.iter().cloned().collect();
            self.tags = existing_tags.union(&new_tags).cloned().collect();

            let tags_added: HashSet<String> =
                new_tags.difference(&existing_tags).cloned().collect();
            if !tags_added.is_empty() {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!(
                        "Added tag(s) '{}'",
                        tags_added
                            .iter()
                            .cloned()
                            .collect::<Vec<String>>()
                            .join(", ")
                    ),
                });
            }
        }

        if let Some(ann) = &props.annotation {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: format!("Added an annotation '{}'", ann),
            });
            self.annotations.push(TaskAnnotation {
                id: None,
                value: ann.to_string(),
                time: Local::now(),
            });
        }

        if let Some(annotations) = &props.annotations {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: "The list of annotations have been changed".to_string(),
            });
            self.annotations = annotations.to_owned();
        }

        if let Some(depends_on) = &props.depends_on {
            let mut deps_set = HashSet::<Uuid>::new();

            // If the vector is empty, it's because we want to cancel all dependencies
            // for the task. In which case just don't add any. This will update the
            // task to not have any dependencies
            if !depends_on.is_empty() {
                self.get_depends_on().iter().for_each(|&uuid| {
                    deps_set.insert(uuid.to_owned());
                });
            }
            for dep in depends_on {
                match dep {
                    DependsOnIdentifier::Id(_) => {
                        unreachable!(
                            "We should not have a usize here. \
                            We should have converted it to a UUID before applying \
                            the properties to the task."
                        );
                    }
                    DependsOnIdentifier::Uuid(uuid) => {
                        if deps_set.contains(uuid) {
                            continue;
                        }
                        self.history.push(TaskHistory {
                            id: None,
                            datetime: Local::now(),
                            value: format!("Added a UUID to depend on: '{}'", uuid),
                        });
                        self.links.push(Link {
                            id: None,
                            from: self.uuid,
                            to: uuid.to_owned(),
                            link_type: LinkType::DependsOn,
                        });
                        deps_set.insert(uuid.to_owned());
                    }
                }
            }
        }
        if let Some(blocks) = &props.blocks {
            let mut deps_set = HashSet::<Uuid>::new();

            // If the vector is empty, it's because we want to cancel all dependencies
            // for the task. In which case just don't add any. This will update the
            // task to not have any dependencies
            if !blocks.is_empty() {
                self.get_blocking().iter().for_each(|&uuid| {
                    deps_set.insert(uuid.to_owned());
                });
            }
            for dep in blocks {
                match dep {
                    DependsOnIdentifier::Id(_) => {
                        unreachable!(
                            "We should not have a usize here. \
                            We should have converted it to a UUID before applying \
                            the properties to the task."
                        );
                    }
                    DependsOnIdentifier::Uuid(uuid) => {
                        if deps_set.contains(uuid) {
                            continue;
                        }
                        self.history.push(TaskHistory {
                            id: None,
                            datetime: Local::now(),
                            value: format!("Added a UUID to block: '{}'", uuid),
                        });
                        self.links.push(Link {
                            id: None,
                            from: self.uuid,
                            to: uuid.to_owned(),
                            link_type: LinkType::Blocking,
                        });
                        deps_set.insert(uuid.to_owned());
                    }
                }
            }
        }
        self.compute_urgency()?;
        Ok(())
    }

    /// Get the field of this task by name
    ///
    /// This serialises the task into JSON to then get the field name
    /// and deserialise it back. The name that we are looking is therefore
    /// the serialisation name
    pub fn get_field(&self, field_name: &str) -> Value {
        let v = serde_json::to_value(self).unwrap();
        if let Some(value) = v.get(field_name) {
            value.clone()
        } else {
            panic!("Could not get the value of '{}'", field_name);
        }
    }

    pub fn delete(&mut self) {
        self.history.push(TaskHistory {
            id: None,
            datetime: Local::now(),
            value: "Deleted task.".to_string(),
        });
        self.status = TaskStatus::Deleted;
        self.id = None;
        self.urgency = None;
    }

    pub fn done(&mut self) {
        let current_time = Local::now();
        self.history.push(TaskHistory {
            id: None,
            datetime: current_time,
            value: "Marked task as done".to_string(),
        });
        self.status = TaskStatus::Completed;
        self.date_completed = Some(current_time);
        self.id = None;
        self.urgency = None;
    }
}

#[derive(Clone, Default, Serialize, Deserialize, PartialEq, Debug, Eq, PartialOrd, Ord, Hash)]
pub struct Project {
    /// Primary key in the database
    pub(crate) id: Option<i32>,
    /// Name of the project.
    /// Dots (.) separate a project into sub projects
    /// a.project --> 'a' is a project with subproject 'a.project'
    pub(crate) name: String,
}

impl Project {
    pub fn get_name(&self) -> &String {
        &self.name
    }

    pub fn from(value: String) -> Project {
        Project {
            name: value,
            id: None,
        }
    }
}

impl fmt::Display for Project {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.name)
    }
}
