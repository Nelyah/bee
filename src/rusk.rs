mod config;
pub mod storage;
pub mod task;
pub mod actions;

use crate::task::manager::TaskData;
use crate::storage::Store;

fn main() {
    print!("hello world");
    storage::JsonStore::write_tasks(&TaskData::default())

}
