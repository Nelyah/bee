mod task_prop_parser;

use log::trace;
use task_prop_parser::TaskPropertyParser;

use std::{cmp::Ordering, collections::HashSet, fmt};

use chrono::prelude::DateTime;
use serde_json::Value;
use uuid::Uuid;

use chrono::Local;
use serde::{Deserialize, Deserializer, Serialize, ser::Serializer};
use std::collections::HashMap;

use crate::filters::Filter;
use crate::lexer::Lexer;

#[path = "task_test.rs"]
#[cfg(test)]
mod task_test;

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
}

impl TaskStatus {
    pub fn from_string(input: &str) -> Result<TaskStatus, String> {
        match input.to_lowercase().as_str() {
            "active" => Ok(TaskStatus::Active),
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
            TaskStatus::Active => write!(f, "active"),
            TaskStatus::Pending => write!(f, "pending"),
            TaskStatus::Completed => write!(f, "completed"),
            TaskStatus::Deleted => write!(f, "deleted"),
        }
    }
}

#[derive(Clone, PartialEq, Debug, serde::Serialize, serde::Deserialize)]
pub enum DependsOnIdentifier {
    Usize(usize),
    Uuid(Uuid),
}

/// This structure contains information regarding setting fields for a Task
/// that can be parsed from a user query, i.e. from the command line
/// It only contains the fields that can be set by a User
///
/// Tags are always FIRST removed, THEN applied
#[derive(Clone, Default, PartialEq, Debug, serde::Deserialize)]
pub struct TaskProperties {
    summary: Option<String>,
    tags_remove: Option<Vec<String>>,
    tags_add: Option<Vec<String>>,
    status: Option<TaskStatus>,
    /// Single annotation to ADD to a task
    annotation: Option<String>,
    /// Replace all of this task's annotations with the given vector
    annotations: Option<Vec<TaskAnnotation>>,
    active_status: Option<bool>,
    /// If presents, sets the task's project to the given
    /// Option<Project>
    project: Option<Option<Project>>,
    #[serde(default)]
    date_due: Option<DateTime<chrono::Local>>,
    depends_on: Option<Vec<DependsOnIdentifier>>,
}

// We implement a specific function for annotate because we cannot know how to differenciate
// it from a description
impl TaskProperties {
    pub fn set_annotate(&mut self, value: String) {
        self.annotation = Some(value);
    }

    pub fn set_annotations(&mut self, annotations: &Vec<TaskAnnotation>) {
        self.annotations = Some(annotations.to_owned());
    }

    pub fn set_summary(&mut self, summary: &str) {
        self.summary = Some(summary.to_string());
    }

    pub fn set_project(&mut self, project: &Option<Project>) {
        self.project = Some(project.clone());
    }

    pub fn add_depends_on(&mut self, identifier: &DependsOnIdentifier) {
        if self.depends_on.is_none() {
            self.depends_on = Some(Vec::new());
        }
        if let Some(depends) = &mut self.depends_on {
            depends.push(identifier.clone());
        }
    }

    /// Sets the vector of tags that should be removed
    pub fn set_tag_remove(&mut self, tags: &Vec<String>) {
        self.tags_remove = Some(tags.to_owned());
    }

    /// Sets the vector of tags that should be added
    pub fn set_tag_add(&mut self, tags: &Vec<String>) {
        self.tags_add = Some(tags.to_owned());
    }

    /// When applied, task status will be set to active
    ///
    /// This will ONLY impact tasks that are PENDING
    pub fn set_active_status(&mut self, status: bool) {
        self.active_status = Some(status);
    }

    pub fn from(values: &[String]) -> Result<TaskProperties, String> {
        let lexer = Lexer::new(values.join(" "));
        let mut parser = TaskPropertyParser::new(lexer);
        parser.parse_task_properties()
    }

    pub fn get_referenced_tasks(&self) -> Vec<DependsOnIdentifier> {
        match &self.depends_on {
            Some(deps) => deps.to_owned(),
            None => Vec::default(),
        }
    }
}

#[derive(
    Clone, Debug, serde::Serialize, serde::Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash,
)]
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

#[derive(
    Clone, Debug, serde::Serialize, serde::Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash,
)]
enum LinkType {
    DependsOn,
    Blocking,
}

#[derive(
    Clone, Debug, serde::Serialize, serde::Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash,
)]
pub struct Link {
    from: Uuid,
    to: Uuid,
    link_type: LinkType,
}

/// This struct contains a description of what happened to a task,
/// and when that event happened as well.
#[derive(
    Clone, Debug, serde::Serialize, serde::Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash,
)]
pub struct TaskHistory {
    pub value: String,
    pub time: DateTime<chrono::Local>,
}

#[derive(Default, Clone, serde::Serialize, serde::Deserialize, Debug, PartialEq, Eq, Hash)]
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

    #[serde(default)]
    links: Vec<Link>,

    project: Option<Project>,

    #[serde(default)]
    date_due: Option<DateTime<chrono::Local>>,

    /// Urgency score that will be computed depending on the other fields of the task
    #[serde(default)]
    urgency: Option<i64>,

    /// All the events that have happened to a task after its creation
    #[serde(default)]
    history: Vec<TaskHistory>,
}

impl PartialOrd for Task {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Task {
    fn cmp(&self, other: &Self) -> Ordering {
        match (self.urgency, other.urgency) {
            (Some(lhs), Some(rhs)) => match lhs.cmp(&rhs) {
                Ordering::Equal => self.date_created.cmp(&other.date_created),
                other => other,
            },
            (Some(_), None) => Ordering::Less,
            (None, Some(_)) => Ordering::Greater,
            (None, None) => self.date_created.cmp(&other.date_created),
        }
    }
}

impl Task {
    /// Returns true if this task depends on the given UUID. False otherwise
    pub fn depends_on(&self, uuid: &Uuid) -> bool {
        self.links
            .iter()
            .any(|link| link.link_type == LinkType::DependsOn && link.to == *uuid)
    }

    /// Returns the list of UUID this tasks depends on
    pub fn get_depends_on(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|l| l.link_type == LinkType::DependsOn)
            .map(|l| &l.to)
            .collect()
    }

    pub fn blocks(&self, uuid: &Uuid) -> bool {
        self.links
            .iter()
            .any(|link| link.link_type == LinkType::Blocking && link.to == *uuid)
    }

    pub fn get_blocking(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|l| l.link_type == LinkType::Blocking)
            .map(|l| &l.to)
            .collect()
    }

    pub fn get_id(&self) -> Option<usize> {
        self.id
    }

    pub fn get_urgency(&mut self) -> Result<i64, String> {
        if let Some(urgency) = self.urgency {
            return Ok(urgency);
        }

        self.compute_urgency()
    }

    fn compute_urgency(&mut self) -> Result<i64, String> {
        let mut urgency: i64 = 0;
        let mut blocking_coef = 1;
        let mut depends_coef = -1;
        let mut active_status_coef = 10;

        let conf = crate::config::get_config();
        for coef_field in conf.coefficients.iter() {
            match coef_field.field.as_str() {
                "tag" => {
                    if let Some(tag_value) = &coef_field.value {
                        if self.tags.contains(tag_value) {
                            urgency += coef_field.coefficient;
                        }
                    } else {
                        urgency += coef_field.coefficient;
                    }
                }
                "depends" => {
                    depends_coef = coef_field.coefficient;
                }
                "blocking" => {
                    blocking_coef = coef_field.coefficient;
                }
                "active_status" => {
                    active_status_coef = coef_field.coefficient;
                }
                _ => {
                    return Err(format!(
                        "Error parsing the coefficient field in the configuration file. \
                            '{}' is not a valid 'field' name. Valid field names are: 'tag', 'depends', 'blocking'",
                        coef_field.field
                    ));
                }
            }
        }

        urgency += self.get_blocking().len() as i64 * blocking_coef;
        urgency += self.get_depends_on().len() as i64 * depends_coef;

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

    pub fn apply(&mut self, props: &TaskProperties) -> Result<(), String> {
        if let Some(summary) = &props.summary {
            self.history.push(TaskHistory {
                time: Local::now(),
                value: format!("Summary changed from '{}' to '{}'.", self.summary, summary),
            });
            self.summary = summary.clone();
        }

        if let Some(date_due) = &props.date_due {
            self.history.push(TaskHistory {
                time: Local::now(),
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
                    time: Local::now(),
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
                    time: Local::now(),
                    value: "Status changed from 'ACTIVE' to 'PENDING'".to_string(),
                });
            }
        }

        if let Some(status) = &props.status {
            if &self.status != status {
                self.history.push(TaskHistory {
                    time: Local::now(),
                    value: format!("Status changed from '{}' to '{}'", self.status, status),
                });
            }
            self.status = status.to_owned();
        }

        if let Some(proj_option) = &props.project {
            if let Some(proj) = proj_option {
                self.history.push(TaskHistory {
                    time: Local::now(),
                    value: format!("Project set to '{}'", proj),
                });
                self.project = Some(proj.to_owned());
            } else {
                self.history.push(TaskHistory {
                    time: Local::now(),
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
                    time: Local::now(),
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
                    time: Local::now(),
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
                time: Local::now(),
                value: format!("Added an annotation '{}'", ann),
            });
            self.annotations.push(TaskAnnotation {
                value: ann.to_string(),
                time: Local::now(),
            });
        }

        if let Some(annotations) = &props.annotations {
            self.history.push(TaskHistory {
                time: Local::now(),
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
                    DependsOnIdentifier::Usize(_) => {
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
                            time: Local::now(),
                            value: format!("Added a UUID to depend on: '{}'", uuid),
                        });
                        self.links.push(Link {
                            from: self.uuid,
                            to: uuid.to_owned(),
                            link_type: LinkType::DependsOn,
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
            time: Local::now(),
            value: "Deleted task.".to_string(),
        });
        self.status = TaskStatus::Deleted;
        self.id = None;
        self.urgency = None;
    }

    pub fn done(&mut self) {
        let current_time = Local::now();
        self.history.push(TaskHistory {
            time: current_time,
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

#[derive(Default, Clone)]
pub struct TaskData {
    /// All the active tasks in this manager. This refers as tasks that should directly be
    /// modified.
    tasks: HashMap<Uuid, Task>,

    /// Those are all the loaded undo. This is needed to be able to restore their state
    undos: HashMap<Uuid, Task>,

    /// Dictionary of ID to UUID of ALL the tasks. Not just the ones that are loaded
    id_to_uuid: HashMap<usize, Uuid>,

    max_id: usize,

    /// Those are the tasks not required by the filters, but that might be needed
    /// when processing the action because they are linked to the filters
    extra_tasks: HashMap<Uuid, Task>,
}

impl TaskData {
    pub fn get_task_map(&self) -> &HashMap<Uuid, Task> {
        &self.tasks
    }

    pub fn get_id_to_uuid(&self) -> &HashMap<usize, Uuid> {
        &self.id_to_uuid
    }

    pub fn insert_id_to_uuid(&mut self, id: usize, uuid: Uuid) {
        self.id_to_uuid.insert(id, uuid);
    }

    pub fn insert_extra_task(&mut self, task: Task) {
        self.extra_tasks.insert(task.uuid.to_owned(), task);
    }

    pub fn get_extra_tasks(&self) -> &HashMap<Uuid, Task> {
        &self.extra_tasks
    }

    pub fn to_vec(&self) -> Vec<&Task> {
        self.tasks.values().collect()
    }

    pub fn apply(&mut self, task_uuid: &Uuid, props: &TaskProperties) -> Result<(), String> {
        if props.depends_on.is_none() {
            return self.tasks.get_mut(task_uuid).unwrap().apply(props);
        }

        let my_props = self.update_task_property_depends_on(props)?;
        self.tasks.get_mut(task_uuid).unwrap().apply(&my_props)
    }

    pub fn get_owned(&self, uuid: &Uuid) -> Option<Task> {
        self.tasks.get(uuid).cloned()
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

    /// Turns the ID to UUIDs in the depends_on vector of TaskProperties
    /// This also copies the TaskProperties to a owned object
    fn update_task_property_depends_on(
        &self,
        props: &TaskProperties,
    ) -> Result<TaskProperties, String> {
        if props.depends_on.is_none() {
            return Ok(props.clone());
        }

        // Update the depends_on vector from the ID to use UUID instead
        let mut my_props: TaskProperties = props.clone();
        let mut new_depends_on = Vec::<DependsOnIdentifier>::new();

        if let Some(deps) = &my_props.depends_on {
            for dep in deps {
                match dep {
                    DependsOnIdentifier::Uuid(uuid) => {
                        new_depends_on.push(DependsOnIdentifier::Uuid(uuid.to_owned()))
                    }
                    DependsOnIdentifier::Usize(id) => {
                        new_depends_on.push(DependsOnIdentifier::Uuid(
                            self.id_to_uuid
                                .get(id)
                                .ok_or(format!(
                                    "The given id {} doesn't correspond to any known task.",
                                    &id
                                ))?
                                .to_owned(),
                        ));
                    }
                }
            }
        }
        my_props.depends_on = Some(new_depends_on);
        Ok(my_props)
    }

    pub fn upkeep(&mut self) -> Result<(), String> {
        let mut vec: Vec<_> = self.tasks.values().by_ref().collect();

        // Set the ID of the tasks by sorting them by date_created
        vec.sort_by(|lhs, rhs| lhs.date_created.cmp(&rhs.date_created));
        let uuids: Vec<Uuid> = vec.iter().map(|t| t.uuid).collect();
        let mut i = 1;
        for cur_uuid in uuids {
            let t: &mut Task = self.tasks.get_mut(&cur_uuid).unwrap();
            match t.status {
                TaskStatus::Pending | TaskStatus::Active => {
                    self.tasks.get_mut(&cur_uuid).unwrap().id = Some(i);
                    i += 1;
                }
                TaskStatus::Deleted | TaskStatus::Completed => {
                    self.tasks.get_mut(&cur_uuid).unwrap().id = None;
                }
            }
        }

        for t in self.tasks.values_mut() {
            t.compute_urgency()?;
        }

        // Update dependency status if a depended class is done / deleted

        // this is the UUID with all the tasks it should depends ONTO
        let mut task_depends_to_update = HashMap::<Uuid, Vec<Uuid>>::default();

        for task in self.tasks.values() {
            let mut dependencies_to_update = HashSet::<Uuid>::default();
            let deps_set_before: HashSet<Uuid> =
                task.get_depends_on().into_iter().cloned().collect();

            for dep_uuid in &deps_set_before {
                if let Some(t) = self.tasks.get(dep_uuid) {
                    match t.status {
                        TaskStatus::Pending | TaskStatus::Active => {}
                        TaskStatus::Completed | TaskStatus::Deleted => {
                            dependencies_to_update.insert(*dep_uuid);
                        }
                    }
                } else if let Some(t) = self.extra_tasks.get(dep_uuid) {
                    match t.status {
                        TaskStatus::Pending | TaskStatus::Active => {}
                        TaskStatus::Completed | TaskStatus::Deleted => {
                            dependencies_to_update.insert(*dep_uuid);
                        }
                    }
                } else {
                    trace!("We have {} task", self.tasks.len());
                    trace!("tasks are: {:?}", self.tasks);
                    unreachable!(
                        "We were unable to find the task associated with uuid {:?} during upkeep phase",
                        dep_uuid
                    );
                }
            }

            let deps_set_after: HashSet<Uuid> = deps_set_before
                .difference(&dependencies_to_update)
                .cloned()
                .collect();
            task_depends_to_update.insert(task.uuid, deps_set_after.into_iter().collect());
        }
        task_depends_to_update
            .into_iter()
            .for_each(|(task_uuid, deps_uuids)| {
                let t = self.tasks.get_mut(&task_uuid).unwrap();
                t.links.retain(|l| l.link_type != LinkType::DependsOn);

                for uuid in deps_uuids {
                    trace!("adding {} -- DependsOn --> {}", t.uuid, uuid);
                    t.links.push(Link {
                        from: t.uuid.to_owned(),
                        to: uuid,
                        link_type: LinkType::DependsOn,
                    });
                }
            });

        // Add the blocking UUID when being referred by depends_on
        let mut blocking_to_blocked_uuids = HashMap::new();
        for task in self.tasks.values() {
            for link in &task.links {
                match link.link_type {
                    LinkType::DependsOn => {
                        // If A depends on B → B blocks A
                        blocking_to_blocked_uuids.insert(link.to, link.from);
                    }
                    LinkType::Blocking => {
                        blocking_to_blocked_uuids.insert(link.from, link.to);
                    }
                }
            }
        }

        for (blocking_uuid, blocked_uuid) in blocking_to_blocked_uuids {
            let t = self.tasks.get_mut(&blocking_uuid).unwrap();

            if !t.blocks(&blocked_uuid) {
                t.links.push(Link {
                    from: blocking_uuid,
                    to: blocked_uuid,
                    link_type: LinkType::Blocking,
                });
            }
        }

        // Update blocking status for tasks
        // For each blocking task, this looks up the tasks depending on it and keeps
        // the blocking list up to date.
        let blockers_uuid: Vec<_> = self
            .tasks
            .values()
            .filter(|t| {
                !t.get_blocking().is_empty()
                    && t.status != TaskStatus::Deleted
                    && t.status != TaskStatus::Completed
            })
            .map(|t| t.uuid)
            .collect();
        for blocker_uuid in blockers_uuid {
            let mut new_blocked_uuids = Vec::new();

            for blocked_uuid in self.tasks.get(&blocker_uuid).unwrap().get_blocking() {
                let blocked_task = self.tasks.get(blocked_uuid).unwrap();

                if blocked_task.depends_on(&blocker_uuid) {
                    new_blocked_uuids.push(*blocked_uuid);
                }
            }
            let blocker_task = self.tasks.get_mut(&blocker_uuid).unwrap();

            blocker_task
                .links
                .retain(|l| l.link_type != LinkType::Blocking);

            blocker_task
                .links
                .extend(new_blocked_uuids.iter().map(|&uuid| Link {
                    from: blocker_task.uuid,
                    to: uuid,
                    link_type: LinkType::Blocking,
                }));
        }

        Ok(())
    }

    #[allow(clippy::borrowed_box)]
    pub fn filter(&self, filter: &Box<dyn Filter>) -> Self {
        let mut new_data = TaskData {
            tasks: HashMap::default(),
            ..TaskData::clone(self)
        };

        let mut extra_tasks = Vec::new();
        for (key, task) in &self.tasks {
            if filter.validate_task(task) {
                new_data.tasks.insert(key.to_owned(), task.to_owned());
                for uuid_dep in &task.get_depends_on() {
                    extra_tasks.push(self.tasks.get(uuid_dep).unwrap());
                }
                for uuid_dep in task.get_blocking() {
                    extra_tasks.push(self.tasks.get(uuid_dep).unwrap());
                }
            }
        }

        for task in extra_tasks {
            new_data.extra_tasks.insert(task.uuid, task.to_owned());
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
        let new_uuid = Uuid::new_v4();
        let new_id: Option<usize> = match status {
            TaskStatus::Pending | TaskStatus::Active => {
                self.max_id += 1;
                Some(self.max_id)
            }
            TaskStatus::Completed | TaskStatus::Deleted => None,
        };

        let date_completed: Option<DateTime<chrono::Local>> = match status {
            TaskStatus::Pending | TaskStatus::Active => None,
            TaskStatus::Completed | TaskStatus::Deleted => Some(Local::now()),
        };

        let date_due = props.date_due.as_ref().map(|date| date.to_owned());

        let project = if let Some(proj) = &props.project {
            proj.to_owned()
        } else {
            None
        };

        let summary = match &props.summary {
            Some(summary) => summary.to_owned(),
            None => return Err("A task must have a summary".to_owned()),
        };

        let tags = match &props.tags_add {
            Some(tags) => tags.to_owned(),
            None => Vec::default(),
        };

        let links = match &props.depends_on {
            Some(_) => {
                let my_props = self.update_task_property_depends_on(props)?;
                let mut deps_uuid: Vec<Uuid> = Vec::new();
                for item in my_props.depends_on.unwrap() {
                    match item {
                        DependsOnIdentifier::Usize(_) => {
                            unreachable!(
                                "We should not have a usize here. \
                            We should have converted it to a UUID before applying \
                            the properties to the task."
                            );
                        }
                        DependsOnIdentifier::Uuid(item_uuid) => deps_uuid.push(item_uuid),
                    }
                }
                deps_uuid
                    .iter()
                    .map(|&uuid| Link {
                        from: new_uuid.to_owned(),
                        to: uuid,
                        link_type: LinkType::DependsOn,
                    })
                    .collect()
            }
            None => Vec::default(),
        };

        let t = Task {
            summary,
            id: new_id,
            status,
            tags,
            uuid: new_uuid,
            date_created: Local::now(),
            date_completed,
            date_due,
            project,
            links,
            ..Task::default()
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
            ..TaskData::default()
        })
    }
}

#[cfg(test)]
#[path = "manager_test.rs"]
mod manager_test;
