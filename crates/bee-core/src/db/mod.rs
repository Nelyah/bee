mod tables;

use crate::{
    filters::Filter,
    task::{
        ActionUndo, ActionUndoType, Link, LinkType, Project, Task, TaskAnnotation, TaskHistory,
    },
};
use migration::{Migrator, MigratorTrait, sea_orm::Database};
use serde_json;
use tables::{annotations, history, links, projects, tags, tasks, tasks_tags, undo_actions};

use log::debug;
use uuid::Uuid;

use sea_orm::{
    ActiveModelTrait,
    ActiveValue::{self, Set},
    ColumnTrait, Condition, ConnectionTrait, DatabaseConnection, DatabaseTransaction, DbErr,
    EntityTrait, IntoActiveModel, QueryFilter, QueryOrder, QuerySelect, TransactionTrait,
};
use std::collections::{HashMap, HashSet};

async fn get_database(
    db_address: Option<&str>,
) -> Result<DatabaseConnection, Box<dyn std::error::Error>> {
    let db = Database::connect(db_address.unwrap_or("sqlite://db.sqlite?mode=rwc"))
        .await
        .unwrap();

    Migrator::up(&db, None).await?;

    Ok(db)
}

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

pub async fn load_tasks(_filter: &Box<dyn Filter>) -> Result<(), Box<dyn std::error::Error>> {
    Ok(())
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

pub async fn fetch_undos(
    limit: usize,
) -> Result<Vec<ActionUndo>, Box<dyn std::error::Error>> {
    if limit == 0 {
        return Ok(Vec::new());
    }

    let db = get_database(None).await?;
    fetch_undos_impl(&db, limit).await
}


async fn append_undo_action_impl(
    db: &DatabaseConnection,
    undo: &ActionUndo,
) -> Result<(), Box<dyn std::error::Error>> {
    let payload = serde_json::to_string(undo)?;
    let active = undo_actions::ActiveModel {
        action_type: Set(match undo.action_type {
            ActionUndoType::Add => "ADD".to_string(),
            ActionUndoType::Modify => "MODIFY".to_string(),
        }),
        payload: Set(payload),
        ..Default::default()
    };
    active.insert(db).await?;
    Ok(())
}

async fn fetch_undos_impl(
    db: &DatabaseConnection,
    limit: usize,
) -> Result<Vec<ActionUndo>, Box<dyn std::error::Error>> {
    if limit == 0 {
        return Ok(Vec::new());
    }

    let mut records = undo_actions::Entity::find()
        .order_by_desc(undo_actions::Column::CreatedAt)
        .order_by_desc(undo_actions::Column::Id)
        .limit(limit as u64)
        .all(db)
        .await?;

    records.reverse();

    let mut undos: Vec<ActionUndo> = Vec::with_capacity(records.len());
    for record in records {
        let mut undo: ActionUndo = serde_json::from_str(&record.payload)?;
        undo.action_type = match record.action_type.as_str() {
            "ADD" => ActionUndoType::Add,
            "MODIFY" => ActionUndoType::Modify,
            other => return Err(format!("Unknown undo action type '{}'", other).into()),
        };
        undos.push(undo);
    }
    Ok(undos)
}

// Macro to diff fields into an ActiveModel
macro_rules! diff_active_model {
    ($am:ident, $old:ident, $new:ident, { $($field:ident),+ $(,)? }) => {
        $(
            if $old.$field != $new.$field {
                $am.$field = Set($new.$field.clone());
            }
        )+
    };
}

async fn insert_task_impl(
    db: &DatabaseConnection,
    task: &Task,
) -> Result<(), Box<dyn std::error::Error>> {
    debug!("Enter in insert_task_impl");
    let txn = db.begin().await?;
    let project_id = persist_project(&txn, task.project.as_ref()).await?;
    let model_task_active = task_to_active_model(&txn, task, project_id).await?;
    let model_task = insert_or_update_task(&txn, &model_task_active).await?;

    sync_annotations(&txn, &model_task, &task.annotations).await?;
    sync_history(&txn, &model_task, &task.history).await?;
    sync_links(&txn, &model_task, &task.links).await?;
    sync_tags(&txn, &model_task, &task.tags).await?;

    txn.commit().await?;
    Ok(())
}

async fn insert_or_update_task(
    db: &DatabaseTransaction,
    task_model_active: &tasks::ActiveModel,
) -> Result<tasks::Model, DbErr> {
    debug!("Enter insert_or_update_task");
    let db_id_option: Option<i32> = match &task_model_active.db_id {
        sea_orm::ActiveValue::Set(val) | sea_orm::ActiveValue::Unchanged(val) => Some(*val),
        ActiveValue::NotSet => None,
    };

    if let Some(db_id) = db_id_option {
        if let Ok(Some(_)) = tables::tasks::Entity::find_by_id(db_id).one(db).await {
            debug!("We are updating the task entry with db_id={}", db_id);
            return task_model_active.clone().update(db).await;
        }
    }
    task_model_active.clone().insert(db).await
}

async fn project_to_active_model<C>(
    db: &C,
    project_obj: &Project,
) -> Result<projects::ActiveModel, DbErr>
where
    C: ConnectionTrait,
{
    // 1. Fetch existing Model if we have an ID
    let project_model: Option<projects::Model> = projects::Entity::find()
        .filter(projects::Column::Name.eq(&project_obj.name))
        .one(db)
        .await?;

    // 2. Start from existing.into_active_model() or default
    let mut project_active = project_model
        .clone()
        .map(|m| m.into_active_model())
        .unwrap_or_default();

    // 3. Ensure PK is set for update (leaving it NotSet for insert)
    if let Some(id) = project_obj.id {
        project_active.id = Set(id);
    }

    // 4. Diff the `name` field if updating, or set it on insert
    if let Some(old) = &project_model {
        diff_active_model!(project_active, old, project_obj, { name });
    } else {
        project_active.name = Set(project_obj.name.clone());
    }

    debug!("End of project_to_active_model {:?}", project_active);
    Ok(project_active)
}

async fn persist_project(
    txn: &DatabaseTransaction,
    project: Option<&Project>,
) -> Result<Option<i32>, DbErr> {
    if let Some(project_obj) = project {
        let project_active = project_to_active_model(txn, project_obj).await?;
        let saved = project_active.save(txn).await?;
        Ok(Some(saved.id.unwrap()))
    } else {
        Ok(None)
    }
}

async fn sync_annotations(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_annotations: &[TaskAnnotation],
) -> Result<(), DbErr> {
    let existing_rows: Vec<annotations::Model> = annotations::Entity::find()
        .filter(annotations::Column::TaskId.eq(task_model.db_id))
        .all(db)
        .await?;

    let mut existing_map: HashMap<i32, annotations::Model> = HashMap::new();
    let mut existing_ids = Vec::new();
    for row in existing_rows {
        existing_ids.push(row.id);
        existing_map.insert(row.id, row);
    }

    let desired_ids: HashSet<i32> = desired_annotations
        .iter()
        .filter_map(|ann| ann.id)
        .collect();

    let to_delete: Vec<i32> = existing_ids
        .into_iter()
        .filter(|id| !desired_ids.contains(id))
        .collect();
    if !to_delete.is_empty() {
        annotations::Entity::delete_many()
            .filter(
                Condition::all()
                    .add(annotations::Column::TaskId.eq(task_model.db_id))
                    .add(annotations::Column::Id.is_in(to_delete)),
            )
            .exec(db)
            .await?;
    }

    for ann in desired_annotations {
        let datetime = ann.time.to_rfc3339();
        if let Some(id) = ann.id {
            if let Some(existing_model) = existing_map.get(&id) {
                let mut active = existing_model.clone().into_active_model();
                let mut changed = false;

                if existing_model.value != ann.value {
                    active.value = Set(ann.value.clone());
                    changed = true;
                } else {
                    active.value = ActiveValue::Unchanged(existing_model.value.clone());
                }

                if existing_model.datetime != datetime {
                    active.datetime = Set(datetime.clone());
                    changed = true;
                } else {
                    active.datetime = ActiveValue::Unchanged(existing_model.datetime.clone());
                }

                if existing_model.task_id != task_model.db_id {
                    active.task_id = Set(task_model.db_id);
                    changed = true;
                } else {
                    active.task_id = ActiveValue::Unchanged(existing_model.task_id);
                }

                if changed {
                    active.save(db).await?;
                }
                continue;
            }
        }

        annotations::ActiveModel {
            id: ActiveValue::NotSet,
            value: Set(ann.value.clone()),
            datetime: Set(datetime.clone()),
            task_id: Set(task_model.db_id),
        }
        .save(db)
        .await?;
    }
    Ok(())
}

async fn sync_history(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_history: &[TaskHistory],
) -> Result<(), DbErr> {
    let existing_rows: Vec<history::Model> = history::Entity::find()
        .filter(history::Column::TaskId.eq(task_model.db_id))
        .all(db)
        .await?;

    let mut existing_map: HashMap<i32, history::Model> = HashMap::new();
    let mut existing_ids = Vec::new();
    for row in existing_rows {
        existing_ids.push(row.id);
        existing_map.insert(row.id, row);
    }

    let desired_ids: HashSet<i32> = desired_history.iter().filter_map(|evt| evt.id).collect();

    let to_delete: Vec<i32> = existing_ids
        .into_iter()
        .filter(|id| !desired_ids.contains(id))
        .collect();
    if !to_delete.is_empty() {
        history::Entity::delete_many()
            .filter(
                Condition::all()
                    .add(history::Column::TaskId.eq(task_model.db_id))
                    .add(history::Column::Id.is_in(to_delete)),
            )
            .exec(db)
            .await?;
    }

    for evt in desired_history {
        let datetime = evt.datetime.to_rfc3339();
        if let Some(id) = evt.id {
            if let Some(existing_model) = existing_map.get(&id) {
                let mut active = existing_model.clone().into_active_model();
                let mut changed = false;

                if existing_model.value != evt.value {
                    active.value = Set(evt.value.clone());
                    changed = true;
                } else {
                    active.value = ActiveValue::Unchanged(existing_model.value.clone());
                }

                if existing_model.datetime != datetime {
                    active.datetime = Set(datetime.clone());
                    changed = true;
                } else {
                    active.datetime = ActiveValue::Unchanged(existing_model.datetime.clone());
                }

                if existing_model.task_id != task_model.db_id {
                    active.task_id = Set(task_model.db_id);
                    changed = true;
                } else {
                    active.task_id = ActiveValue::Unchanged(existing_model.task_id);
                }

                if changed {
                    active.save(db).await?;
                }
                continue;
            }
        }

        history::ActiveModel {
            id: ActiveValue::NotSet,
            value: Set(evt.value.clone()),
            datetime: Set(datetime.clone()),
            task_id: Set(task_model.db_id),
            ..Default::default()
        }
        .save(db)
        .await?;
    }
    Ok(())
}

async fn sync_links(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_links: &[Link],
) -> Result<(), DbErr> {
    let existing_rows: Vec<links::Model> = links::Entity::find()
        .filter(
            Condition::any()
                .add(links::Column::FromTaskId.eq(task_model.db_id))
                .add(links::Column::ToTaskId.eq(task_model.db_id)),
        )
        .all(db)
        .await?;

    let mut existing_map: HashMap<i32, links::Model> = HashMap::new();
    let mut existing_ids = Vec::new();
    for row in existing_rows {
        existing_ids.push(row.id);
        existing_map.insert(row.id, row);
    }

    let desired_ids: HashSet<i32> = desired_links.iter().filter_map(|link| link.id).collect();

    let to_delete: Vec<i32> = existing_ids
        .into_iter()
        .filter(|id| !desired_ids.contains(id))
        .collect();
    if !to_delete.is_empty() {
        links::Entity::delete_many()
            .filter(links::Column::Id.is_in(to_delete))
            .exec(db)
            .await?;
    }

    let mut target_cache: HashMap<Uuid, Option<i32>> = HashMap::new();
    for link in desired_links {
        target_cache
            .entry(link.to)
            .or_insert(resolve_uuid_to_db_id(db, link.to).await?);
    }

    for link in desired_links {
        let to_db_id = target_cache
            .get(&link.to)
            .and_then(|id| *id)
            .ok_or_else(|| DbErr::RecordNotFound(format!("Unknown target {}", link.to)))?;

        if let Some(id) = link.id {
            if let Some(existing_model) = existing_map.get(&id) {
                let mut active = existing_model.clone().into_active_model();
                let mut changed = false;

                if existing_model.from_task_id != task_model.db_id {
                    active.from_task_id = Set(task_model.db_id);
                    changed = true;
                } else {
                    active.from_task_id = ActiveValue::Unchanged(existing_model.from_task_id);
                }

                if existing_model.to_task_id != to_db_id {
                    active.to_task_id = Set(to_db_id);
                    changed = true;
                } else {
                    active.to_task_id = ActiveValue::Unchanged(existing_model.to_task_id);
                }

                let link_type_string = match link.link_type {
                    LinkType::DependsOn => "DependsOn".to_owned(),
                    LinkType::Blocking => "Blocking".to_owned(),
                };
                if existing_model.r#type != link_type_string {
                    active.r#type = Set(link_type_string);
                    changed = true;
                } else {
                    active.r#type = ActiveValue::Unchanged(existing_model.r#type.clone());
                }

                if changed {
                    active.save(db).await?;
                }
                continue;
            }
        }

        links::ActiveModel {
            id: ActiveValue::NotSet,
            from_task_id: Set(task_model.db_id),
            to_task_id: Set(to_db_id),
            r#type: Set(match link.link_type {
                LinkType::DependsOn => "DependsOn".to_owned(),
                LinkType::Blocking => "Blocking".to_owned(),
            }),
        }
        .save(db)
        .await?;
    }
    Ok(())
}

async fn sync_tags(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_tags: &[String],
) -> Result<(), DbErr> {
    let existing_task_tags: Vec<tasks_tags::Model> = tasks_tags::Entity::find()
        .filter(tasks_tags::Column::TaskId.eq(task_model.db_id))
        .all(db)
        .await?;

    let existing_tag_ids: HashSet<i32> = existing_task_tags.iter().map(|row| row.tag_id).collect();

    let mut desired_tag_ids = HashSet::new();
    for tag_name in desired_tags {
        let tag_model = match tags::Entity::find()
            .filter(tags::Column::Name.eq(tag_name.clone()))
            .one(db)
            .await?
        {
            Some(model) => model,
            None => {
                tags::ActiveModel {
                    id: ActiveValue::NotSet,
                    name: Set(tag_name.clone()),
                }
                .insert(db)
                .await?
            }
        };

        desired_tag_ids.insert(tag_model.id);

        if !existing_tag_ids.contains(&tag_model.id) {
            tasks_tags::ActiveModel {
                task_id: Set(task_model.db_id),
                tag_id: Set(tag_model.id),
            }
            .insert(db)
            .await?;
        }
    }

    let stale_tag_ids: Vec<i32> = existing_tag_ids
        .difference(&desired_tag_ids)
        .copied()
        .collect();
    if !stale_tag_ids.is_empty() {
        tasks_tags::Entity::delete_many()
            .filter(
                Condition::all()
                    .add(tasks_tags::Column::TaskId.eq(task_model.db_id))
                    .add(tasks_tags::Column::TagId.is_in(stale_tag_ids)),
            )
            .exec(db)
            .await?;
    }

    Ok(())
}

async fn task_to_active_model<C>(
    db: &C,
    task_obj: &Task,
    project_dbid_option: Option<i32>,
) -> Result<tasks::ActiveModel, Box<dyn std::error::Error>>
where
    C: ConnectionTrait,
{
    let status_str = task_obj.status.to_string().to_uppercase();

    let existing_db_task = tasks::Entity::find()
        .filter(tasks::Column::Uuid.eq(task_obj.uuid.to_string()))
        .one(db)
        .await?;

    let mut task_active = tasks::ActiveModel {
        db_id: match task_obj.db_id {
            Some(id) => ActiveValue::Set(id),
            None => ActiveValue::NotSet,
        },
        id: ActiveValue::Set(task_obj.id),
        status: ActiveValue::Set(status_str.clone()),
        uuid: ActiveValue::Set(task_obj.uuid.to_string()),
        summary: ActiveValue::Set(task_obj.summary.clone()),
        date_created: ActiveValue::Set(task_obj.date_created.to_rfc3339()),
        date_completed: match task_obj.date_completed {
            Some(dt) => ActiveValue::Set(Some(dt.to_rfc3339())),
            None => ActiveValue::Set(None),
        },
        date_due: match task_obj.date_due {
            Some(dt) => ActiveValue::Set(Some(dt.to_rfc3339())),
            None => ActiveValue::Set(None),
        },
        urgency: match task_obj.urgency {
            Some(u) => ActiveValue::Set(Some(u as f64)),
            None => ActiveValue::Set(None),
        },
        project_id: match project_dbid_option {
            Some(pid) => ActiveValue::Set(Some(pid)),
            None => ActiveValue::Set(None),
        },
        ..Default::default()
    };

    if let Some(db_id) = &task_obj.db_id {
        if let Ok(Some(existing)) = tables::tasks::Entity::find_by_id(db_id.clone())
            .one(db)
            .await
        {
            if existing.id == task_obj.id {
                task_active.id = ActiveValue::Unchanged(existing.id);
            }
            if existing.status.to_uppercase() == status_str {
                task_active.status = ActiveValue::Unchanged(existing.status);
            }
            if existing.uuid == task_obj.uuid.to_string() {
                task_active.uuid = ActiveValue::Unchanged(existing.uuid);
            }
            if existing.summary == task_obj.summary {
                task_active.summary = ActiveValue::Unchanged(existing.summary);
            }
            if existing.date_created == task_obj.date_created.to_rfc3339() {
                task_active.date_created = ActiveValue::Unchanged(existing.date_created);
            }
            if existing.date_completed == task_obj.date_completed.map(|dt| dt.to_rfc3339()) {
                task_active.date_completed = ActiveValue::Unchanged(existing.date_completed);
            }
            if existing.date_due == task_obj.date_due.map(|dt| dt.to_rfc3339()) {
                task_active.date_due = ActiveValue::Unchanged(existing.date_due);
            }
            if existing.urgency == task_obj.urgency.map(|u| u as f64) {
                task_active.urgency = ActiveValue::Unchanged(existing.urgency);
            }
        }
    }

    if let Some(existing) = existing_db_task {
        task_active.db_id = ActiveValue::Set(existing.db_id);
        // Preserve existing user-visible id if task.id is None (so we don't null it unintentionally)
        if task_obj.id.is_none() && existing.id.is_some() {
            task_active.id = ActiveValue::Set(existing.id);
        }
    }

    Ok(task_active)
}

/// Placeholder function for converting a Uuid to the corresponding database id.
async fn resolve_uuid_to_db_id<C>(db: &C, id: Uuid) -> Result<Option<i32>, DbErr>
where
    C: ConnectionTrait,
{
    let task = tasks::Entity::find()
        .filter(tasks::Column::Uuid.eq(id.to_string()))
        .one(db)
        .await?;

    Ok(task.map(|model| model.db_id))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Ensure undo actions are persisted and the most recent entry is fetched.
    #[tokio::test]
    async fn test_append_undo_action_persists_and_fetches_latest() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut first_task = Task::default();
        first_task.set_summary("First undo task");
        let first_undo = ActionUndo {
            action_type: ActionUndoType::Add,
            tasks: vec![first_task],
        };

        let mut second_task = Task::default();
        second_task.set_summary("Second undo task");
        let second_undo = ActionUndo {
            action_type: ActionUndoType::Modify,
            tasks: vec![second_task],
        };
        let expected_latest = second_undo.clone();

        append_undo_action_impl(&db, &first_undo).await.unwrap();
        append_undo_action_impl(&db, &second_undo).await.unwrap();

        let recent = fetch_undos_impl(&db, 1).await.unwrap();
        assert_eq!(recent.len(), 1, "Expected a single undo action returned");
        let latest = &recent[0];

        assert_eq!(latest.action_type, expected_latest.action_type);
        assert_eq!(latest.tasks, expected_latest.tasks);
    }

    #[tokio::test]
    async fn test_insert_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        // 1. Create an in-memory task and save its UUID
        let mut t = Task::default();
        let saved_uuid = t.uuid; // UUID auto-generated in default impl

        // 2. First insert
        insert_task_impl(&db, &t).await.unwrap();

        // 3. Retrieve task by saved UUID
        let initial_db_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(saved_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should have been inserted");
        assert_eq!(saved_uuid.to_string(), initial_db_task.uuid);

        // Ensure there are currently no annotations linked
        let annotations_before = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(initial_db_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            annotations_before.is_empty(),
            "Expected no annotations after first insert"
        );

        // 4. Add annotation to in-memory task (value + current time)
        t.annotations.push(TaskAnnotation {
            id: None,
            value: "Test annotation".to_string(),
            time: chrono::Local::now(),
        });

        // 5. Re-insert (should update existing row by UUID, not duplicate)
        insert_task_impl(&db, &t).await.unwrap();

        // Fetch task again to ensure we are still referencing same db_id
        let updated_db_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(saved_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should still exist after update");
        assert_eq!(
            initial_db_task.db_id, updated_db_task.db_id,
            "Task update should not create a new row"
        );

        let annotations_after = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(updated_db_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            !annotations_after.is_empty(),
            "Expected at least one annotation row after update"
        );
    }

    #[tokio::test]
    async fn test_annotation_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        task.annotations.push(TaskAnnotation {
            id: None,
            value: "Initial annotation".to_string(),
            time: chrono::Local::now(),
        });

        insert_task_impl(&db, &task).await.unwrap();

        let persisted_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        let annotations_before = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(
            annotations_before.len(),
            1,
            "Expected one annotation after initial insert"
        );

        task.annotations.clear();
        insert_task_impl(&db, &task).await.unwrap();

        let annotations_after = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            annotations_after.is_empty(),
            "Annotation should be removed after sync with empty annotations"
        );
    }

    #[tokio::test]
    async fn test_history_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        task.history.push(TaskHistory {
            id: None,
            value: "Created".to_string(),
            datetime: chrono::Local::now(),
        });

        insert_task_impl(&db, &task).await.unwrap();

        let persisted_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        let history_before = history::Entity::find()
            .filter(history::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(
            history_before.len(),
            1,
            "Expected one history event after initial insert"
        );

        task.history.clear();
        insert_task_impl(&db, &task).await.unwrap();

        let history_after = history::Entity::find()
            .filter(history::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            history_after.is_empty(),
            "History should be removed after sync with empty events"
        );
    }

    #[tokio::test]
    async fn test_links_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let target_task = Task::default();
        let target_uuid = target_task.uuid;
        insert_task_impl(&db, &target_task).await.unwrap();

        let mut source_task = Task::default();
        let source_uuid = source_task.uuid;
        source_task.links.push(Link {
            id: None,
            from: source_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });

        insert_task_impl(&db, &source_task).await.unwrap();

        let persisted_source = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(source_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Source task should exist after insert");

        let links_before = links::Entity::find()
            .filter(links::Column::FromTaskId.eq(persisted_source.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(
            links_before.len(),
            1,
            "Expected one link after initial insert"
        );

        source_task.links.clear();
        insert_task_impl(&db, &source_task).await.unwrap();

        let links_after = links::Entity::find()
            .filter(links::Column::FromTaskId.eq(persisted_source.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            links_after.is_empty(),
            "Links should be removed after sync with empty collection"
        );
    }

    #[tokio::test]
    async fn test_project_cleared_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        let project_name = "sync-project".to_string();
        task.project = Some(Project {
            id: None,
            name: project_name.clone(),
        });

        insert_task_impl(&db, &task).await.unwrap();

        let persisted_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");
        assert!(
            persisted_task.project_id.is_some(),
            "Project should be set after initial insert"
        );

        task.project = None;
        insert_task_impl(&db, &task).await.unwrap();

        let updated_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should still exist after project removal");
        assert!(
            updated_task.project_id.is_none(),
            "Project should be cleared after sync with None"
        );
    }

    #[tokio::test]
    async fn test_tags_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        task.tags.push("alpha".to_string());

        insert_task_impl(&db, &task).await.unwrap();

        let persisted_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        let tags_before = tasks_tags::Entity::find()
            .filter(tasks_tags::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(
            tags_before.len(),
            1,
            "Expected one task-tag link after initial insert"
        );

        let tag_ids: Vec<i32> = tags_before.iter().map(|t| t.tag_id).collect();
        let tag_alpha = tags::Entity::find()
            .filter(tags::Column::Id.is_in(tag_ids))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(tag_alpha.len(), 1, "Expected matching tag row to exist");
        assert_eq!(
            tag_alpha.first().unwrap().name,
            "alpha",
            "Tag should still have the same name"
        );

        task.tags.clear();
        insert_task_impl(&db, &task).await.unwrap();

        let tags_after = tasks_tags::Entity::find()
            .filter(tasks_tags::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            tags_after.is_empty(),
            "Task-tag links should be removed after sync with empty tags"
        );
    }
}
