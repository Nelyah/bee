use chrono::prelude::DateTime;
use chrono::Local;
use serde::{ser::Serializer, Deserialize, Deserializer, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

use super::{
    filters::{validate_task, Filter},
    task::{Task, TaskStatus},
};

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
