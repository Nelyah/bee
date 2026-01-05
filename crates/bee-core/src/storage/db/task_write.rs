use super::blocking::{resequence_task_ids_txn, update_blocking_status};
use super::sync_relations::{
    sync_annotations, sync_email_links, sync_history, sync_links, sync_tags,
};
use super::tables;
use crate::{
    CoreResult,
    task::{Project, Task},
};
use tables::{projects, tasks};

use log::debug;

use sea_orm::{
    ActiveModelTrait,
    ActiveValue::{self, Set},
    ColumnTrait, ConnectionTrait, DatabaseConnection, DatabaseTransaction, DbErr, EntityTrait,
    IntoActiveModel, QueryFilter, TransactionTrait,
};

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

pub(super) async fn write_tasks_impl(db: &DatabaseConnection, task: &Task) -> CoreResult<()> {
    debug!("Enter in insert_task_impl");
    let txn = db.begin().await?;
    let project_id = persist_project(&txn, task.project.as_ref()).await?;
    let model_task_active = task_to_active_model(&txn, task, project_id).await?;
    let model_task = insert_or_update_task(&txn, &model_task_active).await?;

    sync_annotations(&txn, &model_task, &task.annotations).await?;
    sync_history(&txn, &model_task, &task.history).await?;
    sync_links(&txn, &model_task, &task.links).await?;
    sync_tags(&txn, &model_task, &task.tags).await?;
    sync_email_links(&txn, &model_task, &task.email_links).await?;
    resequence_task_ids_txn(&txn).await?;
    update_blocking_status(&txn).await?;

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

    if let Some(db_id) = db_id_option
        && let Ok(Some(_)) = tables::tasks::Entity::find_by_id(db_id).one(db).await
    {
        debug!("We are updating the task entry with db_id={}", db_id);
        return task_model_active.clone().update(db).await;
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

async fn task_to_active_model<C>(
    db: &C,
    task_obj: &Task,
    project_dbid_option: Option<i32>,
) -> Result<tasks::ActiveModel, DbErr>
where
    C: ConnectionTrait,
{
    let status_str = task_obj.status.to_db_string();

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
    };

    if let Some(db_id) = &task_obj.db_id
        && let Ok(Some(existing)) = tables::tasks::Entity::find_by_id(*db_id).one(db).await
    {
        if existing.id == task_obj.id {
            task_active.id = ActiveValue::Unchanged(existing.id);
        }
        if existing.status == status_str {
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

    if let Some(existing) = existing_db_task {
        task_active.db_id = ActiveValue::Set(existing.db_id);
        // Preserve existing user-visible id if task.id is None (so we don't null it unintentionally)
        if task_obj.id.is_none() && existing.id.is_some() {
            task_active.id = ActiveValue::Set(existing.id);
        }
    }

    Ok(task_active)
}

#[cfg(test)]
mod tests {
    use super::super::{connection::get_database, tables};
    use super::*;
    use crate::task::{Link, LinkType, Project, Task, TaskAnnotation, TaskHistory};
    use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};
    use uuid::Uuid;

    #[tokio::test]
    async fn test_insert_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        let mut t = Task::default();
        let saved_uuid = t.uuid;

        write_tasks_impl(&db, &t).await.unwrap();

        let initial_db_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(saved_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should have been inserted");
        assert_eq!(saved_uuid.to_string(), initial_db_task.uuid);

        let annotations_before = tables::annotations::Entity::find()
            .filter(tables::annotations::Column::TaskId.eq(initial_db_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(annotations_before.is_empty(), "Expected no annotations");

        t.annotations.push(TaskAnnotation {
            id: None,
            value: "Test annotation".to_string(),
            time: chrono::Local::now(),
        });

        write_tasks_impl(&db, &t).await.unwrap();

        let updated_db_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(saved_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should still exist after update");
        assert_eq!(
            initial_db_task.db_id, updated_db_task.db_id,
            "Task update should not create a new row"
        );

        let annotations_after = tables::annotations::Entity::find()
            .filter(tables::annotations::Column::TaskId.eq(updated_db_task.db_id))
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

        write_tasks_impl(&db, &task).await.unwrap();

        let persisted_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        let annotations_before = tables::annotations::Entity::find()
            .filter(tables::annotations::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(annotations_before.len(), 1, "Expected one annotation");

        task.annotations.clear();
        write_tasks_impl(&db, &task).await.unwrap();

        let annotations_after = tables::annotations::Entity::find()
            .filter(tables::annotations::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(annotations_after.is_empty(), "Annotation should be removed");
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

        write_tasks_impl(&db, &task).await.unwrap();

        let persisted_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        let history_before = tables::history::Entity::find()
            .filter(tables::history::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(history_before.len(), 1, "Expected one history event");

        task.history.clear();
        write_tasks_impl(&db, &task).await.unwrap();

        let history_after = tables::history::Entity::find()
            .filter(tables::history::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(history_after.is_empty(), "History should be removed");
    }

    #[tokio::test]
    async fn test_links_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let target_task = Task {
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        let target_uuid = target_task.uuid;
        write_tasks_impl(&db, &target_task).await.unwrap();

        let mut source_task = Task {
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        let source_uuid = source_task.uuid;
        source_task.links.push(Link {
            id: None,
            from: source_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });

        write_tasks_impl(&db, &source_task).await.unwrap();

        let persisted_source = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(source_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Source task should exist after insert");

        let links_before = tables::links::Entity::find()
            .filter(tables::links::Column::FromTaskId.eq(persisted_source.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(links_before.len(), 1, "Expected one link");

        source_task.links.clear();
        write_tasks_impl(&db, &source_task).await.unwrap();

        let links_after = tables::links::Entity::find()
            .filter(tables::links::Column::FromTaskId.eq(persisted_source.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(links_after.is_empty(), "Links should be removed");
    }

    #[tokio::test]
    async fn test_project_cleared_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let project_name = "sync-project".to_string();
        let mut task = Task {
            project: Some(Project {
                id: None,
                name: project_name.clone(),
            }),
            ..Default::default()
        };
        let task_uuid = task.uuid;

        write_tasks_impl(&db, &task).await.unwrap();

        let persisted_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");
        assert!(persisted_task.project_id.is_some(), "Project should be set");

        task.project = None;
        write_tasks_impl(&db, &task).await.unwrap();

        let updated_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should still exist after project removal");
        assert!(
            updated_task.project_id.is_none(),
            "Project should be cleared"
        );
    }

    #[tokio::test]
    async fn test_tags_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        task.tags.push("alpha".to_string());

        write_tasks_impl(&db, &task).await.unwrap();

        let persisted_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        let tags_before = tables::tasks_tags::Entity::find()
            .filter(tables::tasks_tags::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(tags_before.len(), 1, "Expected one task-tag link");

        let tag_ids: Vec<i32> = tags_before.iter().map(|t| t.tag_id).collect();
        let tag_alpha = tables::tags::Entity::find()
            .filter(tables::tags::Column::Id.is_in(tag_ids))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(tag_alpha.len(), 1, "Expected matching tag row to exist");
        assert_eq!(tag_alpha.first().unwrap().name, "alpha");

        task.tags.clear();
        write_tasks_impl(&db, &task).await.unwrap();

        let tags_after = tables::tasks_tags::Entity::find()
            .filter(tables::tasks_tags::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(tags_after.is_empty(), "Task-tag links should be removed");
    }

    /// Test that reproduces the attachment history bug:
    /// When uploading an attachment, history should be persisted to the DB.
    #[tokio::test]
    async fn test_attachment_add_history_persisted() {
        use crate::attachment::AttachmentAddInput;
        use crate::task::{TaskData, TaskProperties};

        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        // Step 1: Create a task and write to DB (simulates existing task)
        let task = Task {
            summary: "Test task".to_string(),
            ..Default::default()
        };
        let task_uuid = task.uuid;
        write_tasks_impl(&db, &task).await.unwrap();

        // Get the db_id for the persisted task
        let persisted_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        // Step 2: Simulate loading task back (with db_id set, like get_task_by_uuid)
        let loaded_task = Task {
            uuid: task_uuid,
            summary: "Test task".to_string(),
            db_id: Some(persisted_task.db_id),
            ..Default::default()
        };

        // Step 3: Create TaskData, add loaded task, apply attachment_add
        // (This is exactly what upload_attachment_handler does)
        let mut task_data = TaskData::default();
        task_data.add_task_object(loaded_task);

        let mut props = TaskProperties::default();
        props.set_attachment_add(AttachmentAddInput::new("document.pdf".to_string()));

        task_data.apply(&task_uuid, &props).unwrap();

        // Verify history was added in memory
        let task_after_apply = task_data.get_owned(&task_uuid).unwrap();
        assert_eq!(
            task_after_apply.history.len(),
            1,
            "History should be added in memory after apply"
        );

        // Step 4: Write back to DB (simulates DbStore::write_tasks)
        for t in task_data.to_vec() {
            write_tasks_impl(&db, t).await.unwrap();
        }

        // Step 5: Verify history is in DB by querying directly
        let history_rows = tables::history::Entity::find()
            .filter(tables::history::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();

        assert_eq!(
            history_rows.len(),
            1,
            "Expected one history entry for attachment add in DB"
        );
        assert!(
            history_rows[0].value.contains("Added attachment"),
            "History should contain 'Added attachment'"
        );
        assert!(
            history_rows[0].value.contains("document.pdf"),
            "History should contain filename"
        );
    }
}
