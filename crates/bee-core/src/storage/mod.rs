use crate::{
    filters::Filter,
    task::{ActionUndo, TaskData, TaskProperties},
};

pub mod db;

pub trait Store {
    fn load_tasks(
        filter: Option<Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> Result<TaskData, String>;
    /// Will write the task and return the TaskData written
    fn write_tasks(data: &TaskData) -> Result<(), String>;

    /// Load up to limit undos
    fn load_undos(limit: usize) -> Vec<ActionUndo>;

    /// Replace the last count undos with updated_undos.
    fn log_undo(count: usize, updated_undos: Vec<ActionUndo>);
}

pub trait AsyncStore {
    fn load_tasks(
        filter: Option<Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> impl std::future::Future<Output = Result<TaskData, Box<dyn std::error::Error>>>;
    /// Will write the task and return the TaskData written
    fn write_tasks(
        data: &TaskData,
    ) -> impl std::future::Future<Output = Result<(), Box<dyn std::error::Error>>>;

    /// Load up to limit undos
    fn load_undos(
        limit: usize,
    ) -> impl std::future::Future<Output = Result<Vec<ActionUndo>, Box<dyn std::error::Error>>>;

    /// Replace the last count undos with updated_undos.
    fn log_undo(
        count: usize,
        updated_undos: Vec<ActionUndo>,
    ) -> impl std::future::Future<Output = Result<(), Box<dyn std::error::Error>>>;
}
