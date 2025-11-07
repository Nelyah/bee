mod inserts_update;
mod tables;

use crate::{
    db::{inserts_update::{
        append_undo_action_impl, fetch_undos_impl, get_database, insert_task_impl, load_tasks_impl,
    }, tables::tasks}, filters::Filter, task::{
        ActionUndo, Task
    }
};

// TODO: 'Load' function to get tasks from DB
// This will require being able to construct the query using filters implementation
// I will probably need to make the filters pub(crate) to access their fields here
//  AndFilter,
//  OrFilter,
//  RootFilter,
//  ProjectFilter,
//  StatusFilter,
//  DateEndFilter,
//  DateCreatedFilter,
//  DateDueFilter,
//  StringFilter,
//  TagFilter,
//  TaskIdFilter,
//  DependsOnFilter,
//  UuidFilter,
//  XorFilter

// TODO: Once the Load function is done, I can make tests and checks that things in the DB
// are correctly being added

// TODO: Need to update SeaORM to use the newer related entities and subtypes
// https://www.sea-ql.org/blog/2025-10-20-sea-orm-2.0/
// sea-orm-cli generate entity --output-dir ./src/entity --entity-format dense

pub async fn load_tasks(filter: &Box<dyn Filter>) -> Result<Vec<Task>, Box<dyn std::error::Error>> {
    let db = get_database(None).await.unwrap();
    load_tasks_impl(&db, filter).await
}
pub async fn insert_tasks(tasks: &[Task]) -> Result<(), Box<dyn std::error::Error>> {
    let db = get_database(None).await.unwrap();
    for task in tasks.iter() {
        insert_task_impl(&db, task).await?;
    }
    Ok(())
}

pub async fn insert_task(task: &Task) -> Result<(), Box<dyn std::error::Error>> {
    let db = get_database(None).await.unwrap();
    insert_task_impl(&db, task).await
}

pub async fn append_undo_action(undo: &ActionUndo) -> Result<(), Box<dyn std::error::Error>> {
    let db = get_database(None).await?;
    append_undo_action_impl(&db, undo).await
}

pub async fn fetch_undos(limit: usize) -> Result<Vec<ActionUndo>, Box<dyn std::error::Error>> {
    if limit == 0 {
        return Ok(Vec::new());
    }

    let db = get_database(None).await?;
    fetch_undos_impl(&db, limit).await
}
