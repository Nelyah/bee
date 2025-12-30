use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize, ser::Serializer};
use uuid::Uuid;

use std::collections::HashMap;

use super::{DependsOnIdentifier, Link, LinkType, Task, TaskProperties, TaskStatus};
use crate::{CoreError, CoreResult, filters::Filter};

#[derive(Default, Clone)]
pub struct TaskData {
    /// All the active tasks in this manager. This refers as tasks that should directly be
    /// modified.
    tasks: HashMap<Uuid, Task>,

    /// Those are all the loaded undo. This is needed to be able to restore their state
    undos: HashMap<Uuid, Task>,

    /// Dictionary of ID to UUID of ALL the tasks. Not just the ones that are loaded
    id_to_uuid: HashMap<i32, Uuid>,

    max_id: i32,

    /// Those are the tasks not required by the filters, but that might be needed
    /// when processing the action because they are linked to the filters
    extra_tasks: HashMap<Uuid, Task>,
}

impl TaskData {
    pub fn get_task_map(&self) -> &HashMap<Uuid, Task> {
        &self.tasks
    }

    pub fn get_id_to_uuid(&self) -> &HashMap<i32, Uuid> {
        &self.id_to_uuid
    }

    pub fn insert_id_to_uuid(&mut self, id: i32, uuid: Uuid) {
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

    pub fn apply(&mut self, task_uuid: &Uuid, props: &TaskProperties) -> CoreResult<()> {
        if props.depends_on.is_none() && props.blocks.is_none() {
            return self
                .tasks
                .get_mut(task_uuid)
                .ok_or_else(|| CoreError::not_found(format!("Task UUID {task_uuid} not found")))?
                .apply(props);
        }

        let my_props = self.update_task_property_depends_on(props)?;

        if let Some(depends_on_ids) = &my_props.depends_on {
            for depends_on_id in depends_on_ids {
                match depends_on_id {
                    DependsOnIdentifier::Id(_) => {
                        unreachable!("All identifiers should have been converted to Uuid!");
                    }
                    DependsOnIdentifier::Uuid(uuid) => {
                        self.tasks
                            .get_mut(uuid)
                            .or_else(|| self.extra_tasks.get_mut(uuid))
                            .ok_or_else(|| {
                                CoreError::not_found(format!(
                                    "Unable to find task with UUID {}",
                                    uuid
                                ))
                            })?
                            .apply(&TaskProperties {
                                blocks: Some(vec![DependsOnIdentifier::Uuid(task_uuid.to_owned())]),
                                ..Default::default()
                            })?;
                    }
                }
            }
        }
        self.tasks
            .get_mut(task_uuid)
            .ok_or_else(|| CoreError::not_found(format!("Task UUID {task_uuid} not found")))?
            .apply(&my_props)
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
    pub(crate) fn update_task_property_depends_on(
        &self,
        props: &TaskProperties,
    ) -> CoreResult<TaskProperties> {
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
                    DependsOnIdentifier::Id(id) => {
                        new_depends_on.push(DependsOnIdentifier::Uuid(
                            self.id_to_uuid
                                .get(id)
                                .ok_or_else(|| {
                                    CoreError::not_found(format!(
                                        "The given id {} doesn't correspond to any known task.",
                                        &id
                                    ))
                                })?
                                .to_owned(),
                        ));
                    }
                }
            }
        }
        my_props.depends_on = Some(new_depends_on);
        Ok(my_props)
    }

    pub fn filter(&self, filter: &dyn Filter) -> Self {
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

    pub fn add_task_object(&mut self, task: Task) {
        if let Some(task_id) = &task.id {
            self.id_to_uuid
                .insert(task_id.to_owned(), task.uuid.to_owned());
            if *task_id > self.max_id {
                self.max_id = *task_id;
            }
        }
        self.tasks.insert(task.uuid.to_owned(), task);
    }

    pub fn add_task(&mut self, props: &TaskProperties, status: TaskStatus) -> CoreResult<&Task> {
        // This allows the user to override the default status of the task being
        // created (defined by the caller of this function, usually Pending)
        let status = match &props.status {
            Some(st) => st,
            None => &status,
        }
        .clone();
        let new_uuid = Uuid::new_v4();
        let new_id: Option<i32> = match status {
            TaskStatus::Blocked | TaskStatus::Pending | TaskStatus::Active => {
                self.max_id += 1;
                Some(self.max_id)
            }
            TaskStatus::Completed | TaskStatus::Deleted => None,
        };

        let date_completed: Option<DateTime<chrono::Local>> = match status {
            TaskStatus::Pending | TaskStatus::Active | TaskStatus::Blocked => None,
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
            None => return Err(CoreError::task("A task must have a summary")),
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
                        DependsOnIdentifier::Id(_) => {
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
                        id: None,
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
        if let Some(task_id) = t.id {
            self.id_to_uuid.insert(task_id, owned_uuid.to_owned());
        }
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
        D: serde::Deserializer<'de>,
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
