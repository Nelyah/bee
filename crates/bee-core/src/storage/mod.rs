use crate::{filters::Filter, task::{ActionUndo, TaskData, TaskProperties}};

pub mod db;
pub mod json;


pub trait Store {
    #[allow(clippy::borrowed_box)]
    fn load_tasks(
        filter: Option<&Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> Result<TaskData, String>;
    /// Will write the task and return the TaskData written
    fn write_tasks(data: &TaskData) -> Result<TaskData, String>;

    /// Load up to limit undos
    fn load_undos(limit: usize) -> Vec<ActionUndo>;

    /// Replace the last count undos with updated_undos.
    fn log_undo(count: usize, updated_undos: Vec<ActionUndo>);
}

