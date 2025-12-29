mod blocking;
mod connection;
mod filter_sql;
mod sync_relations;
mod tables;
mod task_read;
mod task_write;
mod undo;

use crate::{
    filters::Filter,
    storage::{
        AsyncStore,
        db::{
            connection::get_database,
            task_read::{get_projects_with_counts, get_tags_with_counts, load_tasks_impl},
            task_write::write_tasks_impl,
            undo::{append_undo_action_impl, load_undos_impl},
        },
    },
    task::{ActionUndo, TaskData, TaskProperties},
};

pub use task_read::CompletionRow;

// TODO: Need to update SeaORM to use the newer related entities and subtypes
// https://www.sea-ql.org/blog/2025-10-20-sea-orm-2.0/
// sea-orm-cli generate entity --output-dir ./src/entity --entity-format dense

/// Async store backed by the sqlite database.
pub struct DbStore {}

impl DbStore {
    /// Get all unique projects with task counts.
    pub async fn get_projects() -> Result<Vec<CompletionRow>, Box<dyn std::error::Error>> {
        let db = get_database(None).await?;
        get_projects_with_counts(&db).await
    }

    /// Get all unique tags with task counts.
    pub async fn get_tags() -> Result<Vec<CompletionRow>, Box<dyn std::error::Error>> {
        let db = get_database(None).await?;
        get_tags_with_counts(&db).await
    }
}

impl AsyncStore for DbStore {
    async fn load_tasks(
        filter: Option<Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> Result<TaskData, Box<dyn std::error::Error>> {
        let db = get_database(None).await?;
        load_tasks_impl(&db, filter, props).await
    }
    async fn write_tasks(data: &TaskData) -> Result<(), Box<dyn std::error::Error>> {
        let db = get_database(None).await?;
        for task in data.to_vec().iter() {
            write_tasks_impl(&db, task).await?;
        }
        Ok(())
    }

    async fn log_undo(
        count: usize,
        undos: Vec<ActionUndo>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let db = get_database(None).await?;
        append_undo_action_impl(&db, count, undos).await
    }

    async fn load_undos(limit: usize) -> Result<Vec<ActionUndo>, Box<dyn std::error::Error>> {
        if limit == 0 {
            return Ok(Vec::new());
        }

        let db = get_database(None).await?;
        load_undos_impl(&db, limit).await
    }
}
