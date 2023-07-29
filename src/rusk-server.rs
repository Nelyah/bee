use rusk::manager;
use rusk::operation::Operation;
use rusk::task;

use manager::{json_manager::JsonTaskManager, TaskHandler};
use rocket::serde::json::Json;
use rocket::{launch, post, routes};
use uuid::Uuid;

use crate::task::Task;

#[derive(serde::Serialize, serde::Deserialize, Default)]
struct TaskQuery {
    query: Vec<String>,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct TaskSync {
    operations: Vec<Vec<Operation>>,
}

#[derive(serde::Serialize, serde::Deserialize, Default)]
struct TaskData {
    description: String,
    tags: Option<Vec<String>>,
    sub_tasks: Option<Vec<String>>,
}

#[derive(serde::Serialize, Default)]
struct StatusResponse {
    status: String,
    message: String,
    tasks: Vec<Task>,
}

#[post("/add_task", data = "<data>")]
fn add_task(data: Json<TaskData>) -> Json<StatusResponse> {
    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();
    manager.load_task_data(data_file);

    let mut sub_tasks_uuid: Vec<Uuid> = Default::default();
    if let Some(sub_tasks) = data.sub_tasks.clone() {
        for i in sub_tasks {
            if let Ok(uuid) = Uuid::parse_str(&i) {
                sub_tasks_uuid.push(uuid);
            }
        }
    }

    let mut tags_vec: Vec<String> = Default::default();
    if let Some(tags) = data.tags.clone() {
        tags_vec = tags;
    }

    let new_task: Task = manager
        .add_task(&data.description, tags_vec, sub_tasks_uuid)
        .clone();
    manager.write_task_data(data_file);

    return Json(StatusResponse {
        status: "OK".to_string(),
        tasks: vec![new_task],
        ..Default::default()
    });
}

#[post("/complete_task", data = "<data>")]
fn complete_task(data: Json<TaskQuery>) -> Json<StatusResponse> {
    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();
    manager.load_task_data(data_file);

    let tasks_uuid: Vec<Uuid> = manager
        .filter_tasks_from_string(&data.query)
        .iter()
        .map(|t| t.uuid)
        .collect();
    for uuid in tasks_uuid {
        manager.complete_task(&uuid);
    }

    manager.write_task_data(data_file);
    return Json(StatusResponse {
        status: String::from("OK"),
        ..Default::default()
    });
}

#[post("/get_tasks", data = "<data>")]
fn get_tasks(data: Json<TaskQuery>) -> Json<StatusResponse> {
    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();

    manager.load_task_data(data_file);
    let filtered_tasks = manager.filter_tasks_from_string(&data.query);
    let owned_tasks: Vec<Task> = filtered_tasks.iter().map(|&t| t.to_owned()).collect();

    return Json(StatusResponse {
        status: "OK".to_string(),
        tasks: owned_tasks,
        ..Default::default()
    });
}

#[post("/delete_task", data = "<data>")]
fn delete_task(data: Json<TaskQuery>) -> Json<StatusResponse> {
    // TODO: Move this to the config
    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();
    manager.load_task_data(data_file);

    let tasks_uuid: Vec<Uuid> = manager
        .filter_tasks_from_string(&data.query)
        .iter()
        .map(|t| t.uuid)
        .collect();
    if data.query.len() == 0 {
        return Json(StatusResponse {
            status: "FAIL".to_owned(),
            message: "No task was specified".to_owned(),
            ..Default::default()
        });
    }

    for uuid in tasks_uuid {
        manager.delete_task(&uuid);
    }

    manager.write_task_data(data_file);
    return Json(StatusResponse {
        status: String::from("OK"),
        ..Default::default()
    });
}

#[post("/sync", data = "<data>")]
fn sync(data: Json<TaskSync>) -> Json<StatusResponse> {
    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();
    manager.load_task_data(data_file);
    let operations = &data.operations;
    manager.sync(operations);

    manager.write_task_data(data_file);
    return Json(StatusResponse {
        status: String::from("OK"),
        ..Default::default()
    });
}

#[launch]
fn rocket() -> _ {
    rocket::build()
        .mount("/v1", routes![add_task])
        .mount("/v1", routes![delete_task])
        .mount("/v1", routes![complete_task])
        .mount("/v1", routes![get_tasks])
        .mount("/v1", routes![sync])
}
