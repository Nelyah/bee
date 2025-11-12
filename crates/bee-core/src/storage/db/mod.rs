mod inserts_update;
mod tables;

use crate::{
    filters::Filter,
    storage::{
        AsyncStore,
        db::inserts_update::{
            append_undo_action_impl, get_database, load_tasks_impl, load_undos_impl,
            write_tasks_impl,
        },
    },
    task::{ActionUndo, Task, TaskData, TaskProperties},
};

// TODO: Need to update SeaORM to use the newer related entities and subtypes
// https://www.sea-ql.org/blog/2025-10-20-sea-orm-2.0/
// sea-orm-cli generate entity --output-dir ./src/entity --entity-format dense

// TODO: implement the Store trait

struct DbStore {}
pub async fn insert_task(task: &Task) -> Result<(), Box<dyn std::error::Error>> {
    let db = get_database(None).await.unwrap();
    write_tasks_impl(&db, task).await
}

impl AsyncStore for DbStore {
    async fn load_tasks(
        filter: Option<&Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> Result<TaskData, Box<dyn std::error::Error>> {
        let db = get_database(None).await.unwrap();
        load_tasks_impl(&db, filter, props).await
    }
    async fn write_tasks(data: &TaskData) -> Result<(), Box<dyn std::error::Error>> {
        let db = get_database(None).await.unwrap();
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
