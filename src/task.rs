use chrono::prelude::DateTime;
use serde;
use std::fs;
use uuid::Uuid;

#[derive(Default, serde::Serialize, serde::Deserialize)]
struct TaskData {
    pub completed: Vec<Task>,
    pub pending: Vec<Task>,
    pub deleted: Vec<Task>,
}

impl serde::Serialize for TaskData {

}
// TODO: Task need to have:
// - Status
// - Due date
// - Project
// - Link to other tasks (RelatesTo, Blocks, Depend, etc.)

#[derive(Default, serde::Serialize, serde::Deserialize)]
struct Task {
    id: usize,
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

// TODO: We probably don't need a trait for this

pub trait TaskManager {
    fn add_task(&mut self, description: &str);
    fn complete_task_by_id(&mut self, id: usize);
    fn complete_task_by_uuid(&mut self, uuid: &Uuid);
    fn delete_task_by_id(&mut self, id: usize);
    fn delete_task_by_uuid(&mut self, uuid: &Uuid);
    fn load_task_data(&mut self, data_file: &str);
    fn write_task_data(&self, data_file: &str);
}

fn delete_task_with_uuid(tasks: &mut Vec<Task>, uuid: &Uuid) {
    let mut i = 0;
    while i < tasks.len() {
        if tasks[i].uuid == *uuid {
            tasks.swap_remove(i);
            return;
        }
        i += 1;
    }
}

fn complete_task_with_uuid(
    pending_tasks: &mut Vec<Task>,
    completed_tasks: &mut Vec<Task>,
    uuid: &Uuid,
) {
    let mut i = 0;
    while i < pending_tasks.len() {
        if pending_tasks[i].uuid == *uuid {
            let task = pending_tasks.swap_remove(i);
            completed_tasks.push(task);
            return;
        }
        i += 1;
    }
}

impl TaskManager for Manager {
    fn delete_task_by_id(&mut self, id: usize) {
        let mut i = 0;
        while i < self.data.pending.len() {
            if self.data.pending[i].id == id {
                let temp_uuid = self.data.pending[i].uuid.clone();
                delete_task_with_uuid(&mut self.data.pending, &temp_uuid);
                return;
            }
            i += 1;
        }
    }

    // TODO: Need to return whether we could delete the task or not
    fn delete_task_by_uuid(&mut self, uuid: &Uuid) {
        delete_task_with_uuid(&mut self.data.completed, uuid);
        delete_task_with_uuid(&mut self.data.pending, uuid);
    }

    fn complete_task_by_id(&mut self, id: usize) {
        let mut i = 0;
        while i < self.data.pending.len() {
            if self.data.pending[i].id == id {
                let temp_uuid = self.data.pending[i].uuid.clone();
                complete_task_with_uuid(
                    &mut self.data.pending,
                    &mut self.data.completed,
                    &temp_uuid,
                );
                return;
            }
            i += 1;
        }
    }

    fn complete_task_by_uuid(&mut self, uuid: &Uuid) {
        complete_task_with_uuid(&mut self.data.pending, &mut self.data.completed, uuid);
    }

    fn add_task(&mut self, description: &str) {
        self.data.pending.push(Task {
            uuid: Uuid::new_v4(),
            date_created: chrono::offset::Local::now(),
            id: self.data.pending.len(),
            description: description.to_string(),
            ..Default::default()
        });
    }
    fn load_task_data(&mut self, data_file: &str) {
        if std::path::Path::new(data_file).exists() {
            self.data =
                serde_json::from_str(&fs::read_to_string(data_file).expect("unable to read file"))
                    .unwrap();
        } else {
            self.data = TaskData::default();
        }
    }

    fn write_task_data(&self, data_file: &str) {
        fs::write(data_file, serde_json::to_string(&self.data).unwrap())
            .expect("Unable to write file");
    }
}
