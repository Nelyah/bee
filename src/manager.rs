use serde::{
    ser::{SerializeStruct, Serializer},
    Deserialize, Deserializer, Serialize,
};
use std::any::Any;
use std::collections::HashMap;
use uuid::Uuid;

use crate::filters::Filter;
use crate::operation::{GenerateOperation, Operation};
use crate::task::{Task, TaskStatus};

pub mod json_manager;

#[derive(Default)]
struct TaskData {
    pub tasks: HashMap<Uuid, Task>,
    pub id_to_uuid: HashMap<usize, Uuid>,
    pub operations: Vec<Vec<Operation>>,
}

impl GenerateOperation for TaskData {
    fn generate_operation<T: Any>(&self, other: &dyn Any) -> Operation {
        let mut operation = Operation::default();
        let other_manager = other
            .downcast_ref::<TaskData>()
            .expect("Could not downcast `other' into a TaskData");

        for (key, task) in self.tasks.iter().collect::<Vec<_>>() {
            let other_task_option = other_manager.tasks.get(&key);
            let input_task_bytes = serde_json::to_vec::<Task>(&task).expect(&format!(
                "Failed to serialize Task `{}' from output task",
                task.uuid
            ));
            operation.input.insert(key.to_string(), input_task_bytes);

            if let Some(other_task) = other_task_option {
                let output_task_bytes = serde_json::to_vec(&other_task).expect(&format!(
                    "Failed to serialize Task `{}' from output task",
                    task.uuid
                ));
                operation.output.insert(key.to_string(), output_task_bytes);
            }
        }

        for (key, task) in other_manager.tasks.iter().collect::<Vec<_>>() {
            match self.tasks.get(&key) {
                None => {
                    let output_task_bytes = serde_json::to_vec(&task).expect(&format!(
                        "Failed to serialize Task `{}' from output task",
                        task.uuid
                    ));
                    operation.output.insert(key.to_string(), output_task_bytes);
                }
                _ => {}
            }
        }

        operation
    }

    // TODO: Currently, this is an Operation of Tasks instead of being an operation of TaskData
    fn apply_operation(&mut self, operation: &Operation) -> Result<(), String> {
        // TODO: The Err should be a merge conflict

        // Grab the UUID for the task amongst the fields we have
        match operation.input.get("uuid") {
            Some(bytes) => {
                let uuid: Uuid = serde_json::from_slice(&bytes)
                    .map_err(|e| format!("deserializing 'uuid': {}", e))
                    .expect("error");

                self.tasks
                    .get_mut(&uuid)
                    .expect(&format!("could not find task with UUID {}", &uuid))
                    .apply_operation(operation)?;
                return Ok(());
            }
            // The task didn't exist as input. There's only something in the output
            None => {}
        }

        match operation.output.get("uuid") {
            Some(bytes) => {
                let uuid: Uuid = serde_json::from_slice(&bytes)
                    .map_err(|e| format!("deserializing 'uuid': {}", e))
                    .expect("error");
                let mut new_task = Task {
                    uuid,
                    ..Default::default()
                };
                match new_task.apply_operation(operation) {
                    Ok(()) => {}
                    _ => {}
                }

                self.tasks.insert(uuid, new_task);
            }
            None => {
                panic!("Error during applying an operation to TaskData");
            }
        }

        Ok(())
    }
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
        let mut state = serializer.serialize_struct("TaskData", 4)?;

        state.serialize_field("completed", &completed_values)?;
        state.serialize_field("pending", &pending_values)?;
        state.serialize_field("deleted", &deleted_values)?;
        state.serialize_field("operations", &self.operations)?;
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
            operations: Vec<Vec<Operation>>,
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
            operations: task_data_fields.operations,
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

pub trait TaskHandler {
    fn add_task(&mut self, description: &str, tags: Vec<String>, sub_tasks: Vec<Uuid>) -> &Task;
    fn complete_task(&mut self, uuid: &Uuid);
    fn delete_task(&mut self, uuid: &Uuid);
    fn load_task_data(&mut self, data_file: &str);
    fn write_task_data(&self, data_file: &str);
    fn id_to_uuid(&self, id: &usize) -> Uuid;
    fn filter_tasks(&self, filter: &Filter) -> Vec<&Task>;
    fn filter_tasks_from_string(&self, filter_str: &Vec<String>) -> Vec<&Task>;
    fn get_operations(&self) -> &Vec<Vec<Operation>>;
    fn wipe_operations(&mut self);
    fn sync(&mut self, operations: &Vec<Vec<Operation>>);
}

#[path = "manager_test.rs"]
mod manager_test;
