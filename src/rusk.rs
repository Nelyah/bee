use crate::{manager::TaskData, storage::Store};

mod config;
pub mod storage;
pub mod filters;
pub mod manager;
pub mod task;
pub mod actions;

fn main() {
    print!("hello world");
    storage::JsonStore::write_tasks(&TaskData::default())

}
