pub mod filters;
pub mod manager;
pub mod task;

use task::Task;
use manager::{TaskHandler, TaskManager};
use rocket::serde::json::Json;
use rocket::{launch, post, routes};
use uuid::Uuid;

#[derive(serde::Serialize, serde::Deserialize, Default)]
struct IdTaskData {
    uuid: Option<Uuid>,
    id: Option<usize>,
}

#[derive(serde::Serialize, serde::Deserialize, Default)]
struct TaskQuery {
    query: String,
}

#[derive(serde::Serialize)]
struct StatusResponse {
    status: String,
}

#[post("/add_task")]
fn add_task() {
    let data_file = "data.json";
    let mut manager = TaskManager::default();
    manager.load_task_data(data_file);
    manager.add_task("new description");
    manager.write_task_data(data_file);
}

#[post("/complete_task", data = "<data>")]
fn complete_task(data: Json<IdTaskData>) -> Json<StatusResponse> {
    let data_file = "data.json";
    let mut manager = TaskManager::default();
    manager.load_task_data(data_file);

    match data.uuid {
        Some(uuid) => {
            manager.complete_task(&uuid);
        }
        None => match data.id {
            Some(id) => {
                manager.complete_task(&manager.id_to_uuid(&id));
            }
            None => {
                return Json(StatusResponse {
                    status: String::from("FAIL"),
                });
            }
        },
    }

    manager.write_task_data(data_file);
    return Json(StatusResponse {
        status: String::from("OK"),
    });
}

#[post("/get_tasks", data = "<data>")]
fn get_tasks(data: Json<TaskQuery>) -> Json<Vec<Task>> {
    let data_file = "data.json";
    let mut manager = TaskManager::default();

    manager.load_task_data(data_file);
    let filtered_tasks = manager.filter_tasks_from_string(&data.query);
    let owned_tasks : Vec<Task> = filtered_tasks.iter().map(|&t| t.to_owned()).collect();

    return Json(owned_tasks);
}

#[post("/remove_task", data = "<data>")]
fn delete_task(data: Json<IdTaskData>) -> Json<StatusResponse> {
    let data_file = "data.json";
    let mut manager = TaskManager::default();
    manager.load_task_data(data_file);

    match data.uuid {
        Some(uuid) => {
            manager.delete_task(&uuid);
        }
        None => match data.id {
            Some(id) => {
                manager.delete_task(&manager.id_to_uuid(&id));
            }
            None => {
                return Json(StatusResponse {
                    status: String::from("FAIL"),
                });
            }
        },
    }

    manager.write_task_data(data_file);
    return Json(StatusResponse {
        status: String::from("OK"),
    });
}

#[launch]
fn rocket() -> _ {
    rocket::build()
        .mount("/v1", routes![add_task])
        .mount("/v1", routes![delete_task])
        .mount("/v1", routes![complete_task])
        .mount("/v1", routes![get_tasks])
}
