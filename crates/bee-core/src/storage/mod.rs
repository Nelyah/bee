use crate::{
    CoreResult,
    filters::Filter,
    task::{ActionUndo, TaskData, TaskProperties},
};

pub mod db;

pub trait Store {
    fn load_tasks(
        filter: Option<Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> CoreResult<TaskData>;
    /// Will write the task and return the TaskData written
    fn write_tasks(data: &TaskData) -> CoreResult<()>;

    /// Load up to limit undos
    fn load_undos(limit: usize) -> Vec<ActionUndo>;

    /// Replace the last count undos with updated_undos.
    fn log_undo(count: usize, updated_undos: Vec<ActionUndo>);
}

pub trait AsyncStore {
    fn load_tasks(
        filter: Option<Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> impl std::future::Future<Output = CoreResult<TaskData>> + Send;
    /// Will write the task and return the TaskData written
    fn write_tasks(data: &TaskData) -> impl std::future::Future<Output = CoreResult<()>> + Send;

    /// Load up to limit undos
    fn load_undos(
        limit: usize,
    ) -> impl std::future::Future<Output = CoreResult<Vec<ActionUndo>>> + Send;

    /// Replace the last count undos with updated_undos.
    fn log_undo(
        count: usize,
        updated_undos: Vec<ActionUndo>,
    ) -> impl std::future::Future<Output = CoreResult<()>> + Send;
}
