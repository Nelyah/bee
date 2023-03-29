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

pub trait TaskManager {
    fn add_task(&mut self, description: &str);
    fn delete_task_by_id(&mut self, id: usize);
    fn delete_task_by_uuid(&mut self, uuid: Uuid);
    fn load_task_data(&mut self, data_file: &str);
    fn write_task_data(&self, data_file: &str);
}

impl TaskManager for Manager {
    fn delete_task_by_id(&mut self, _id: usize) {}

    fn delete_task_by_uuid(&mut self, _uuid: Uuid) {}

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
