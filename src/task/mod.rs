pub mod filters;

mod lexer;
mod parser;
mod task_prop_parser;
use log::trace;
use task_prop_parser::TaskPropertyParser;

use std::{cmp::Ordering, collections::HashSet, fmt};

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

#[derive(Clone, PartialEq, Debug, serde::Serialize, serde::Deserialize)]
pub enum DependsOnIdentifier {
    Usize(usize),
    Uuid(Uuid),
}

// This structure contains information regarding setting fields for a Task
// that can be parsed from a user query, i.e. from the command line
// It only contains the fields that can be set by a User
#[derive(Clone, Default, PartialEq, Debug, serde::Deserialize)]
pub struct TaskProperties {
    summary: Option<String>,
    tags_remove: Option<Vec<String>>,
    tags_add: Option<Vec<String>>,
    status: Option<TaskStatus>,
    annotation: Option<String>,
    project: Option<Project>,
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
    depends_on: Vec<Uuid>,

    #[serde(default)]
    blocking: Vec<Uuid>,

    project: Option<Project>,

    #[serde(default)]
    date_due: Option<DateTime<chrono::Local>>,

    /// Urgency score that will be computed depending on the other fields of the task
    #[serde(default)]
    urgency: Option<i64>,
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
                _ => {
                    return Err(format!(
                        "Error parsing the coefficient field in the configuration file. \
                            '{}' is not a valid 'field' name. Valid field names are: 'tag', 'depends', 'blocking'",
                        coef_field.field
                    ));
                }
            }
        }

        urgency += self.blocking.len() as i64 * blocking_coef;
        urgency += self.depends_on.len() as i64 * depends_coef;

        // Compute number of days remaining until the due date
        if let Some(date_due) = self.date_due {
            let now = Local::now();
            let days = date_due.signed_duration_since(now).num_days();
            urgency += days;
        }

        self.urgency = Some(urgency);
        Ok(self.urgency.unwrap())
    }

    pub fn get_annotations(&self) -> &Vec<TaskAnnotation> {
        &self.annotations
    }

    pub fn get_depends(&self) -> &Vec<Uuid> {
        &self.depends_on
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
        let mut uuids = [self.depends_on.to_owned(), self.blocking.to_owned()].concat();
        uuids.sort_unstable();
        uuids.dedup();
        uuids
    }

    pub fn apply(&mut self, props: &TaskProperties) -> Result<(), String> {
        if let Some(summary) = &props.summary {
            self.summary = summary.clone();
        }

        if let Some(date_due) = &props.date_due {
            self.date_due = Some(date_due.to_owned());
        }

        if let Some(status) = &props.status {
            self.status = status.to_owned();
        }

        if let Some(proj) = &props.project {
            self.project = Some(proj.to_owned());
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

        if let Some(depends_on) = &props.depends_on {
            let mut deps_set = HashSet::<Uuid>::new();

            // If the vector is empty, it's because we want to cancel all dependencies
            // for the task. In which case just don't add any. This will update the
            // task to not have any dependencies
            if !depends_on.is_empty() {
                self.depends_on.iter().for_each(|uuid| {
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
                        self.depends_on.push(uuid.to_owned());
                        deps_set.insert(uuid.to_owned());
                    }
                }
            }
            self.depends_on = deps_set.into_iter().collect();
        }
        self.compute_urgency()?;
        Ok(())
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
        self.urgency = None;
    }

    pub fn done(&mut self) {
        self.status = TaskStatus::Completed;
        self.date_completed = Some(Local::now());
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
    /// All the loaded tasks in this manager
    tasks: HashMap<Uuid, Task>,
    /// Those are all the loaded undo. This is needed to be able to restore their state
    undos: HashMap<Uuid, Task>,
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
        return self.tasks.get_mut(task_uuid).unwrap().apply(&my_props);
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
                TaskStatus::Pending => {
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

        let mut task_depends_to_update = HashMap::<Uuid, Vec<Uuid>>::default();
        for task in self.tasks.values() {
            let mut dependencies_to_update = HashSet::<Uuid>::default();
            let deps_set_before: HashSet<Uuid> = task.depends_on.iter().cloned().collect();
            for dep_uuid in &deps_set_before {
                if let Some(t) = self.tasks.get(dep_uuid) {
                    match t.status {
                        TaskStatus::Pending => {}
                        TaskStatus::Completed | TaskStatus::Deleted => {
                            dependencies_to_update.insert(*dep_uuid);
                        }
                    }
                } else if let Some(t) = self.extra_tasks.get(dep_uuid) {
                    match t.status {
                        TaskStatus::Pending => {}
                        TaskStatus::Completed | TaskStatus::Deleted => {
                            dependencies_to_update.insert(*dep_uuid);
                        }
                    }
                } else {
                    trace!("We have {} task", self.tasks.len());
                    trace!("tasks are: {:?}", self.tasks);
                    unreachable!("We were unable to find the task associated with uuid {:?} during upkeep phase", dep_uuid);
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
                self.tasks.get_mut(&task_uuid).unwrap().depends_on = deps_uuids;
            });

        // Add the blocking UUID when being referred by depends_on
        let mut blockers_uuid = HashMap::new();
        for task in self.tasks.values() {
            for blocking_uuid in &task.depends_on {
                blockers_uuid.insert(blocking_uuid.to_owned(), task.uuid.to_owned());
            }
        }
        for (blocker_uuid, blocked_uuid) in blockers_uuid {
            let t = self.tasks.get_mut(&blocker_uuid).unwrap();
            t.blocking.push(blocked_uuid);
            t.blocking.sort_unstable();
            t.blocking.dedup();
        }

        // Update blocking status for tasks
        // For each blocking task, this looks up the tasks depending on it and keeps
        // the blocking list up to date.
        let blockers_uuid: Vec<_> = self
            .tasks
            .values()
            .filter(|t| {
                !t.blocking.is_empty()
                    && t.status != TaskStatus::Deleted
                    && t.status != TaskStatus::Completed
            })
            .map(|t| t.uuid)
            .collect();
        for blocker_uuid in blockers_uuid {
            let mut blocker_task = self.tasks.get_mut(&blocker_uuid).unwrap().to_owned();
            let mut new_blocking_uuids = Vec::new();

            for blocked_uuid in &blocker_task.blocking {
                let blocked_task = self.tasks.get(blocked_uuid).unwrap();

                if blocked_task.depends_on.contains(&blocker_uuid) {
                    new_blocking_uuids.push(*blocked_uuid);
                }
            }
            blocker_task.blocking = new_blocking_uuids;
            self.tasks
                .insert(blocker_task.uuid.to_owned(), blocker_task);
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
                for uuid_dep in &task.depends_on {
                    extra_tasks.push(self.tasks.get(uuid_dep).unwrap());
                }
                for uuid_dep in &task.blocking {
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

        let depends_on = match &props.depends_on {
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
            }
            None => Vec::default(),
        };

        let t = Task {
            summary,
            id: new_id,
            status,
            tags,
            uuid: Uuid::new_v4(),
            date_created: Local::now(),
            date_completed,
            date_due,
            project,
            depends_on,
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
