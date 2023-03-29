pub mod task;

use task::{Manager,TaskManager};


fn main() {

    let data_file = "data.json";

    let mut manager = Manager::default();
    manager.load_task_data(data_file);
    manager.add_task("new description");
    manager.write_task_data(data_file);
}
