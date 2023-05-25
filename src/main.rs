pub mod task;

use rocket::serde::json::Json;
use rocket::{launch, post, routes};
use task::{Manager, TaskManager};
use uuid::Uuid;

#[derive(serde::Serialize, serde::Deserialize, Default)]
struct IdTaskData {
    uuid: Option<Uuid>,
    id: Option<usize>,
}

#[derive(serde::Serialize)]
struct StatusResponse {
    status: String
}

// TODO: Need to have all those entrypoints after a /v1/ route

#[post("/add_task")]
fn add_task() {
    let data_file = "data.json";
    let mut manager = Manager::default();
    manager.load_task_data(data_file);
    manager.add_task("new description");
    manager.write_task_data(data_file);
}

#[post("/complete_task", data = "<data>")]
fn complete_task(data: Json<IdTaskData>) -> Json<StatusResponse> {
    let data_file = "data.json";
    let mut manager = Manager::default();
    manager.load_task_data(data_file);

    match data.uuid {
        Some(uuid) => {
            manager.complete_task(&uuid);
        }
        None => match data.id {
            Some(id) => {
                manager.complete_task(&manager.id_to_uuid(&id));
            }
            None => {return Json(StatusResponse{status: String::from("FAIL")}); }
        },
    }

    manager.write_task_data(data_file);
    return Json(StatusResponse{status: String::from("OK")});
}

#[post("/remove_task", data = "<data>")]
fn delete_task(data: Json<IdTaskData>) -> Json<StatusResponse> {
    let data_file = "data.json";
    let mut manager = Manager::default();
    manager.load_task_data(data_file);

    match data.uuid {
        Some(uuid) => {
            manager.delete_task(&uuid);
        }
        None => match data.id {
            Some(id) => {
                manager.delete_task(&manager.id_to_uuid(&id));
            }
            None => {return Json(StatusResponse{status: String::from("FAIL")}); }
        },
    }

    manager.write_task_data(data_file);
    return Json(StatusResponse{status: String::from("OK")});
}

#[launch]
fn rocket() -> _ {
    rocket::build()
        .mount("/", routes![add_task])
        .mount("/", routes![delete_task])
        .mount("/", routes![complete_task])
}
