pub mod task;

use task::{Manager, TaskManager};
use rocket::serde::json::Json;
use uuid::Uuid;

#[macro_use]
extern crate rocket;

#[derive(serde::Serialize, serde::Deserialize,Default)]
struct DeleteTaskData {
    uuid: Option<Uuid>,
    id: Option<usize>,
}

#[post("/add_task")]
fn add_task() {
    let data_file = "data.json";
    let mut manager = Manager::default();
    manager.load_task_data(data_file);
    manager.add_task("new description");
    manager.write_task_data(data_file);
}

#[post("/remove_task", data = "<data>")]
fn delete_task(data: Json<DeleteTaskData>)
{
    let data_file = "data.json";
    let mut manager = Manager::default();
    manager.load_task_data(data_file);
    manager.delete_task_by_id(data.id.unwrap());
    manager.write_task_data(data_file);
}

#[launch]
fn rocket() -> _ {
    rocket::build()
        .mount("/", routes![add_task])
        .mount("/", routes![delete_task])
}
