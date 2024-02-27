use serde::{ser::Serializer, Deserialize, Deserializer, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

use super::task::Task;

#[derive(Default)]
pub struct TaskData {
    pub tasks: HashMap<Uuid, Task>,
}

impl TaskData {
    pub fn get_task_map(&self) -> &HashMap<Uuid, Task> {
        &self.tasks
    }

    pub fn set_task(&mut self, task: Task) {
        self.tasks.insert(task.get_uuid().clone(), task.clone());
    }
}

impl Serialize for TaskData {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let tasks: Vec<&Task> = self.tasks.values().collect();
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
        Ok(TaskData { tasks: task_map })
    }
}

#[path = "manager_test.rs"]
mod manager_test;
