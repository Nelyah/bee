use chrono::prelude::DateTime;
// use serde::{Deserialize, Deserializer, Serialize, SerializeStruct, Serializer};
use serde::{
    ser::{SerializeStruct, Serializer},
    Deserialize, Deserializer, Serialize,
};
use std::fs;
use uuid::Uuid;

use std::collections::HashMap;

#[derive(Default)]
struct TaskData {
    pub completed: HashMap<Uuid, Task>,
    pub pending: HashMap<Uuid, Task>,
    pub deleted: HashMap<Uuid, Task>,
    pub id_to_uuid: HashMap<usize, Uuid>,
}

impl Serialize for TaskData {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let completed_values: Vec<&Task> = self.completed.values().collect();
        let mut pending_values: Vec<&Task> = self.pending.values().collect();
        pending_values.sort_by_key(|task| task.date_created);
        let deleted_values: Vec<&Task> = self.deleted.values().collect();

        // 3 is the number of fields in the struct.
        let mut state = serializer.serialize_struct("TaskData", 3)?;

        state.serialize_field("completed", &completed_values)?;
        state.serialize_field("pending", &pending_values)?;
        state.serialize_field("deleted", &deleted_values)?;
        state.end()
    }
}

impl<'de> Deserialize<'de> for TaskData {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        struct TaskDataFields {
            completed: Vec<Task>,
            pending: Vec<Task>,
            deleted: Vec<Task>,
        }

        let mut task_data_fields: TaskDataFields = Deserialize::deserialize(deserializer)?;

        let mut completed_map: HashMap<Uuid, Task> = HashMap::new();
        for task in task_data_fields.completed {
            completed_map.insert(task.uuid, task);
        }

        let mut id_to_uuid: HashMap<usize, Uuid> = HashMap::new();
        let mut task_id = 1;
        let mut pending_map: HashMap<Uuid, Task> = HashMap::new();
        task_data_fields
            .pending
            .sort_by_key(|task| task.date_created);
        for mut task in task_data_fields.pending {
            id_to_uuid.insert(task_id, task.uuid);
            task.id = Some(task_id);
            task_id += 1;
            pending_map.insert(task.uuid, task);
        }

        let mut deleted_map: HashMap<Uuid, Task> = HashMap::new();
        for task in task_data_fields.deleted {
            deleted_map.insert(task.uuid, task);
        }

        Ok(TaskData {
            completed: completed_map,
            pending: pending_map,
            deleted: deleted_map,
            id_to_uuid,
        })
    }
}

impl TaskData {
    fn data_cleanup(&mut self) {
        for (_, mut task) in &mut self.completed {
            task.id = None;
        }
        for (_, mut task) in &mut self.deleted {
            task.id = None;
        }
    }
}

// TODO: Task need to have:
// - Status
// - Due date
// - Project
// - Link to other tasks (RelatesTo, Blocks, Depend, etc.)

#[derive(Default, serde::Serialize, serde::Deserialize)]
struct Task {
    id: Option<usize>,
    uuid: Uuid,
    description: String,
    tags: Vec<String>,
    date_created: DateTime<chrono::Local>,
    #[serde(default)]
    date_completed: Option<DateTime<chrono::Local>>,
    sub: Vec<Uuid>,
}

/// Manager is there to interact with the data
/// It implements the trait TaskManager which allows it to modify the data.
///
/// The manager owns the data
#[derive(Default)]
pub struct Manager {
    data: TaskData,
}

// // TODO: We probably don't need a trait for this

pub trait TaskManager {
    fn add_task(&mut self, description: &str);
    fn complete_task(&mut self, uuid: &Uuid);
    fn delete_task(&mut self, uuid: &Uuid);
    fn load_task_data(&mut self, data_file: &str);
    fn write_task_data(&self, data_file: &str);
    fn id_to_uuid(&self, id: &usize) -> Uuid;
}

impl TaskManager for Manager {
    fn id_to_uuid(&self, id: &usize) -> Uuid {
        return self.data.id_to_uuid[id];
    }

    fn add_task(&mut self, description: &str) {
        let task = Task {
            uuid: Uuid::new_v4(),
            date_created: chrono::offset::Local::now(),
            id: Some(self.data.pending.len() + 1),
            description: description.to_string(),
            ..Default::default()
        };
        self.data.pending.insert(task.uuid, task);
    }

    fn complete_task(&mut self, uuid: &Uuid) {
        if let Some(mut task) = self.data.pending.remove(uuid) {
            task.date_completed = Some(chrono::offset::Local::now());
            self.data.completed.insert(uuid.clone(), task);
        }
    }

    fn delete_task(&mut self, uuid: &Uuid) {
        if let Some(task) = self.data.pending.remove(uuid) {
            self.data.deleted.insert(uuid.clone(), task);
        }

        if let Some(task) = self.data.completed.remove(uuid) {
            self.data.deleted.insert(uuid.clone(), task);
        }
    }

    fn write_task_data(&self, data_file: &str) {
        fs::write(data_file, serde_json::to_string(&self.data).unwrap())
            .expect("Unable to write file");
    }

    fn load_task_data(&mut self, data_file: &str) {
        self.data.data_cleanup();
        if std::path::Path::new(data_file).exists() {
            self.data =
                serde_json::from_str(&fs::read_to_string(data_file).expect("unable to read file"))
                    .unwrap();
        } else {
            self.data = TaskData::default();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_addition() {
        let data_file = "data.json";
        let mut manager = Manager::default();
        manager.load_task_data(data_file);
        assert_eq!(manager.data.completed.len(), 1);
        println!("{}", serde_json::to_string(&manager.data).unwrap());
    }
}
