use crate::filters::{build_filter_from_strings, validate_task, Filter};
use crate::task::{Task, TaskStatus};
use serde::{
    ser::{SerializeStruct, Serializer},
    Deserialize, Deserializer, Serialize,
};
use std::fs;
use uuid::Uuid;

use std::collections::HashMap;

#[derive(Default)]
struct TaskData {
    pub tasks: HashMap<Uuid, Task>,
    pub id_to_uuid: HashMap<usize, Uuid>,
}

impl Serialize for TaskData {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut pending_values: Vec<&Task> = self
            .tasks
            .values()
            .filter(|t| t.status == TaskStatus::PENDING)
            .collect();
        pending_values.sort_by_key(|task| task.date_created);
        let deleted_values: Vec<&Task> = self
            .tasks
            .values()
            .filter(|t| t.status == TaskStatus::DELETED)
            .collect();
        let completed_values: Vec<&Task> = self
            .tasks
            .values()
            .filter(|t| t.status == TaskStatus::COMPLETED)
            .collect();

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

        let mut task_map: HashMap<Uuid, Task> = HashMap::new();
        for task in task_data_fields.completed {
            task_map.insert(task.uuid, task);
        }

        let mut id_to_uuid: HashMap<usize, Uuid> = HashMap::new();
        let mut task_id = 1;
        task_data_fields
            .pending
            .sort_by_key(|task| task.date_created);
        for mut task in task_data_fields.pending {
            id_to_uuid.insert(task_id, task.uuid);
            task.id = Some(task_id);
            task_id += 1;
            task_map.insert(task.uuid, task);
        }

        for task in task_data_fields.deleted {
            task_map.insert(task.uuid, task);
        }

        Ok(TaskData {
            tasks: task_map,
            id_to_uuid,
        })
    }
}

impl TaskData {
    fn data_cleanup(&mut self) {
        for (_, mut task) in &mut self.tasks {
            if task.status == TaskStatus::COMPLETED || task.status == TaskStatus::PENDING {
                task.id = None;
            }
        }
    }

    fn get_pending_count(&self) -> usize {
        self.tasks
            .values()
            .filter(|t| t.status == TaskStatus::PENDING)
            .count()
    }
}

/// TaskManager is there to interact with the data
/// It implements the trait TaskHandler which allows it to modify the data.
///
/// The manager owns the data
#[derive(Default)]
pub struct TaskManager {
    data: TaskData,
}

// // TODO: We probably don't need a trait for this

pub trait TaskHandler {
    fn add_task(&mut self, description: &str);
    fn complete_task(&mut self, uuid: &Uuid);
    fn delete_task(&mut self, uuid: &Uuid);
    fn load_task_data(&mut self, data_file: &str);
    fn write_task_data(&self, data_file: &str);
    fn id_to_uuid(&self, id: &usize) -> Uuid;
    fn filter_tasks(&self, filter: &Filter) -> Vec<&Task>;
    fn filter_tasks_from_string(&self, filter_str: &str) -> Vec<&Task>;
}

impl TaskHandler for TaskManager {
    fn filter_tasks_from_string(&self, filter_str: &str) -> Vec<&Task> {
        let tokens: Vec<String> = filter_str
            .split_whitespace()
            .map(|t| String::from(t))
            .collect();
        self.data
            .tasks
            .values()
            .filter(|t| validate_task(t, &build_filter_from_strings(tokens.as_slice())))
            .collect()
    }

    fn filter_tasks(&self, filter: &Filter) -> Vec<&Task> {
        self.data
            .tasks
            .values()
            .filter(|t| validate_task(t, filter))
            .collect()
    }

    fn id_to_uuid(&self, id: &usize) -> Uuid {
        return self.data.id_to_uuid[id];
    }

    fn add_task(&mut self, description: &str) {
        let new_id = self.data.get_pending_count() + 1;
        let new_uuid = Uuid::new_v4();
        self.data.id_to_uuid.insert(new_id, new_uuid);
        let task = Task {
            uuid: new_uuid,
            id: Some(new_id),
            date_created: chrono::offset::Local::now(),
            description: description.to_string(),
            ..Default::default()
        };
        self.data.tasks.insert(task.uuid, task);
    }

    fn complete_task(&mut self, uuid: &Uuid) {
        if let Some(mut task) = self.data.tasks.get_mut(uuid) {
            task.id = None;
            task.date_completed = Some(chrono::offset::Local::now());
            task.status = TaskStatus::COMPLETED;
        }
    }

    fn delete_task(&mut self, uuid: &Uuid) {
        if let Some(mut task) = self.data.tasks.get_mut(uuid) {
            task.id = None;
            task.status = TaskStatus::DELETED;
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
    fn test_task_data_serialize() {
        let mut tasks = HashMap::new();
        let task1 = Task {
            uuid: Uuid::new_v4(),
            status: TaskStatus::PENDING,
            ..Default::default()
        };
        let task2 = Task {
            uuid: Uuid::new_v4(),
            status: TaskStatus::COMPLETED,
            ..Default::default()
        };
        tasks.insert(task1.uuid, task1.clone());
        tasks.insert(task2.uuid, task2.clone());

        let task_data = TaskData {
            tasks,
            id_to_uuid: HashMap::new(),
        };

        let serialized = serde_json::to_string(&task_data).unwrap();
        let expected = format!(
            r#"{{"completed":[{}],"pending":[{}],"deleted":[]}}"#,
            serde_json::to_string(&task2).unwrap(),
            serde_json::to_string(&task1).unwrap(),
        );
        assert_eq!(serialized, expected);
    }

    #[test]
    fn test_task_data_deserialize() {
        let json = r#"{
            "completed": [
                {
                    "uuid": "00000000-0000-0000-0000-000000000001",
                    "date_created": "2023-05-25T21:25:24.899710+02:00",
                    "status": "COMPLETED",
                    "description": "task1",
                    "sub": [],
                    "tags": []
                }
            ],
            "pending": [
                {
                    "uuid": "00000000-0000-0000-0000-000000000002",
                    "date_created": "2023-05-25T21:25:24.899710+02:00",
                    "status": "COMPLETED",
                    "description": "task2",
                    "sub": [],
                    "tags": []
                },
                {
                    "uuid": "00000000-0000-0000-0000-000000000003",
                    "date_created": "2023-05-25T21:25:24.899710+02:00",
                    "status": "COMPLETED",
                    "description": "task3",
                    "sub": [],
                    "tags": []
                }
            ],
            "deleted": []
        }"#;

        let task_data: TaskData = serde_json::from_str(json).unwrap();

        assert_eq!(task_data.tasks.len(), 3);
        assert_eq!(
            task_data
                .tasks
                .contains_key(&Uuid::parse_str("00000000-0000-0000-0000-000000000001").unwrap()),
            true
        );
        assert_eq!(
            task_data
                .tasks
                .contains_key(&Uuid::parse_str("00000000-0000-0000-0000-000000000002").unwrap()),
            true
        );
        assert_eq!(
            task_data
                .tasks
                .contains_key(&Uuid::parse_str("00000000-0000-0000-0000-000000000003").unwrap()),
            true
        );
    }

    #[test]
    fn test_task_data_get_pending_count() {
        let mut tasks = HashMap::new();
        tasks.insert(
            Uuid::new_v4(),
            Task {
                status: TaskStatus::PENDING,
                ..Default::default()
            },
        );
        tasks.insert(
            Uuid::new_v4(),
            Task {
                status: TaskStatus::COMPLETED,
                ..Default::default()
            },
        );
        tasks.insert(
            Uuid::new_v4(),
            Task {
                status: TaskStatus::PENDING,
                ..Default::default()
            },
        );

        let task_data = TaskData {
            tasks,
            id_to_uuid: HashMap::new(),
        };

        assert_eq!(task_data.get_pending_count(), 2);
    }

    #[test]
    fn test_task_manager_add_task() {
        let mut task_manager = TaskManager::default();
        task_manager.add_task("Task 1");
        task_manager.add_task("Task 2");
        task_manager.add_task("Task 3");

        assert_eq!(task_manager.data.tasks.len(), 3);
        assert_eq!(task_manager.data.get_pending_count(), 3);
    }

    #[cfg(test)]
    #[test]
    fn test_task_handler_complete_task() {
        let mut task_manager = TaskManager::default();
        let task_uuid = Uuid::new_v4();
        task_manager.add_task("Task 1");
        task_manager.add_task("Task 2");
        task_manager.data.tasks.insert(
            task_uuid.clone(),
            Task {
                uuid: task_uuid.clone(),
                status: TaskStatus::PENDING,
                ..Default::default()
            },
        );

        assert_eq!(
            task_manager.data.tasks[&task_uuid].status,
            TaskStatus::PENDING
        );

        task_manager.complete_task(&task_uuid);

        assert_eq!(
            task_manager.data.tasks[&task_uuid].status,
            TaskStatus::COMPLETED
        );
        assert!(task_manager.data.tasks[&task_uuid].date_completed.is_some());
    }

    #[test]
    fn test_task_handler_delete_task() {
        let mut task_manager = TaskManager::default();
        let task_uuid = Uuid::new_v4();
        task_manager.add_task("Task 1");
        task_manager.add_task("Task 2");
        task_manager.data.tasks.insert(
            task_uuid.clone(),
            Task {
                uuid: task_uuid,
                status: TaskStatus::PENDING,
                ..Default::default()
            },
        );

        assert_eq!(
            task_manager.data.tasks[&task_uuid].status,
            TaskStatus::PENDING
        );

        task_manager.delete_task(&task_uuid);

        assert_eq!(
            task_manager.data.tasks[&task_uuid].status,
            TaskStatus::DELETED
        );
    }

    #[test]
    fn test_task_handler_load_task_data() {
        let mut task_manager = TaskManager::default();
        task_manager.add_task("Task 1");
        task_manager.add_task("Task 2");
        task_manager.write_task_data("test_data.json");

        task_manager.load_task_data("test_data.json");

        assert_eq!(task_manager.data.tasks.len(), 2);
        assert_eq!(task_manager.data.get_pending_count(), 2);
    }

    #[test]
    fn test_task_handler_filter_tasks() {
        let mut task_manager = TaskManager::default();
        task_manager.add_task("Task 1");
        task_manager.add_task("Task 2");
        task_manager.complete_task(&task_manager.data.tasks.keys().next().unwrap().clone());

        let filter_str = "task 1".to_owned();
        let filter = build_filter_from_strings(&[filter_str]);

        let filtered_tasks = task_manager.filter_tasks(&filter);

        assert_eq!(filtered_tasks.len(), 1);
        assert_eq!(filtered_tasks[0].description, "Task 1");
    }

    #[test]
    fn test_filter_tasks_from_string() {
        let mut manager = TaskManager::default();
        manager.add_task("A task about llamss");
        manager.add_task("Socket is the most beautiful cat in the world");
        manager.add_task("Task 1");

        assert_eq!(manager.filter_tasks_from_string("some filter string").len(), 0);
        assert_eq!(manager.filter_tasks_from_string("1").len(), 2);
        assert_eq!(manager.filter_tasks_from_string("task").len(), 2);
        assert_eq!(manager.filter_tasks_from_string("task and cat").len(), 0);
        assert_eq!(manager.filter_tasks_from_string("task or cat").len(), 3);
    }
}
