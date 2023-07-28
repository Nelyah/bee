use crate::filters::{build_filter_from_strings, validate_task, Filter, FilterView};
use crate::task::{Task, TaskStatus};
use crate::operation::{GenerateOperation, Operation};
use std::fs;
use uuid::Uuid;

use super::{TaskData,TaskHandler};

/// TaskManager is there to interact with the data
/// It implements the trait TaskHandler which allows it to modify the data.
///
/// The manager owns the data
#[derive(Default)]
pub struct JsonTaskManager {
    data: TaskData,
}

// // TODO: We probably don't need a trait for this

impl TaskHandler for JsonTaskManager {
    fn filter_tasks_from_string(&self, filter_str: &Vec<String>) -> Vec<&Task> {
        let tokens: Vec<String> = filter_str.iter().map(|t| String::from(t)).collect();
        let mut filter = build_filter_from_strings(tokens.as_slice());

        let mentions_status_or_view: bool = filter
            .iter()
            .filter(|f| f.has_value)
            .take_while(|f| f.value.starts_with("status:") || f.value.starts_with("view:"))
            .count()
            != 0;

        if !mentions_status_or_view {
            filter = filter.and(FilterView::default().get_view("pending"));
        }
        self.filter_tasks(&filter)
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

    fn add_task(&mut self, description: &str, tags: Vec<String>, sub_tasks: Vec<Uuid>) -> &Task {
        let new_id = self.data.get_pending_count() + 1;
        let new_uuid = Uuid::new_v4();
        self.data.id_to_uuid.insert(new_id, new_uuid);

        let task = Task {
            uuid: new_uuid,
            id: Some(new_id),
            date_created: chrono::offset::Local::now(),
            description: description.to_string(),
            tags,
            sub: sub_tasks,
            ..Default::default()
        };
        let mut op = Operation::default();
            let task_bytes = serde_json::to_vec::<Task>(&task).expect(&format!(
                "Failed to serialize Task `{}'",
                task.uuid
            ));
        self.data.tasks.insert(task.uuid, task);
        self.data.operations.push(vec![op]);

        &self.data.tasks[&new_uuid]
    }

    fn complete_task(&mut self, uuid: &Uuid) {
        if let Some(mut task) = self.data.tasks.get_mut(uuid) {
            let task_before = task.clone();
            task.id = None;
            task.date_completed = Some(chrono::offset::Local::now());
            task.status = TaskStatus::COMPLETED;
            let vec_op: Vec<Operation> = vec![task_before.generate_operation::<Task>(task)];
            self.data.operations.push(vec_op);
            
        }
    }

    fn delete_task(&mut self, uuid: &Uuid) {
        if let Some(mut task) = self.data.tasks.get_mut(uuid) {
            let task_before = task.clone();
            task.id = None;
            task.status = TaskStatus::DELETED;
            self.data.operations.push(vec![task_before.generate_operation::<Task>(task)]);
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

    fn get_operations(&self) -> &Vec<Vec<Operation>> {
        &self.data.operations
    }

    fn wipe_operations(&mut self) {
        self.data.operations = Vec::default();
    }

    // TODO: Implement this
    fn sync(&mut self, operations: &Vec<Vec<Operation>>) {
        for batch in operations {
            for op in batch {
                match self.data.apply_operation(&op) {
                    Ok(()) => {},
                    _ => {},
                }
            }
        }
    }
}
#[path = "json_manager_test.rs"]
mod jsonmanager_test;
