//! Storage layer for file attachments.
//!
//! Attachments are stored as BLOBs directly in the database.
//! List operations return metadata only (without BLOB data) for performance.

use super::{sync_relations::resolve_uuid_to_db_id, tables};
use crate::attachment::Attachment;
use chrono::{DateTime, Local};
use sea_orm::{
    ActiveValue::{NotSet, Set},
    ColumnTrait, DatabaseConnection, DbErr, EntityTrait, QueryFilter,
};
use uuid::Uuid;

/// Parse RFC3339 timestamp string into DateTime<Local>.
fn parse_rfc3339_local(value: &str) -> Option<DateTime<Local>> {
    DateTime::parse_from_rfc3339(value)
        .ok()
        .map(|dt| dt.with_timezone(&Local))
}

/// Convert database model to domain Attachment (without data blob).
fn model_to_attachment(model: &tables::attachments::Model, task_uuid: Uuid) -> Option<Attachment> {
    let uuid = Uuid::parse_str(&model.uuid).ok()?;
    let created_at = parse_rfc3339_local(&model.created_at)?;

    Some(Attachment {
        id: model.id,
        task_uuid,
        uuid,
        filename: model.filename.clone(),
        mime_type: model.mime_type.clone(),
        size_bytes: model.size_bytes,
        created_at,
    })
}

/// List all attachments for a task (metadata only, no BLOB data).
pub(super) async fn list_by_task_uuid(
    db: &DatabaseConnection,
    task_uuid: Uuid,
) -> Result<Vec<Attachment>, DbErr> {
    let task_id = resolve_uuid_to_db_id(db, task_uuid).await?;
    let Some(task_id) = task_id else {
        return Ok(Vec::new());
    };

    let rows = tables::attachments::Entity::find()
        .filter(tables::attachments::Column::TaskId.eq(task_id))
        .all(db)
        .await?;

    Ok(rows
        .iter()
        .filter_map(|row| model_to_attachment(row, task_uuid))
        .collect())
}

/// Get attachment metadata by ID (no BLOB data).
pub(super) async fn get_by_id(
    db: &DatabaseConnection,
    attachment_id: i32,
) -> Result<Option<Attachment>, DbErr> {
    let row = tables::attachments::Entity::find_by_id(attachment_id)
        .one(db)
        .await?;
    let Some(row) = row else {
        return Ok(None);
    };

    // Look up task UUID
    let task_uuid = tables::tasks::Entity::find_by_id(row.task_id)
        .one(db)
        .await?
        .and_then(|t| Uuid::parse_str(&t.uuid).ok());
    let Some(task_uuid) = task_uuid else {
        return Ok(None);
    };

    Ok(model_to_attachment(&row, task_uuid))
}

/// Get the raw file data (BLOB) for an attachment by ID.
pub(super) async fn get_data_by_id(
    db: &DatabaseConnection,
    attachment_id: i32,
) -> Result<Option<Vec<u8>>, DbErr> {
    let row = tables::attachments::Entity::find_by_id(attachment_id)
        .one(db)
        .await?;
    Ok(row.map(|r| r.data))
}

/// Insert a new attachment with file data.
///
/// Returns the created attachment metadata (without the BLOB data).
pub(super) async fn insert_attachment(
    db: &DatabaseConnection,
    task_uuid: Uuid,
    filename: String,
    mime_type: String,
    data: Vec<u8>,
) -> Result<Attachment, DbErr> {
    let task_id = resolve_uuid_to_db_id(db, task_uuid).await?;
    let Some(task_id) = task_id else {
        return Err(DbErr::RecordNotFound(format!(
            "Task not found for uuid {task_uuid}"
        )));
    };

    let attachment_uuid = Uuid::new_v4();
    let size_bytes = data.len() as i64;
    let created_at = Local::now();

    let active = tables::attachments::ActiveModel {
        id: NotSet,
        task_id: Set(task_id),
        uuid: Set(attachment_uuid.to_string()),
        filename: Set(filename),
        mime_type: Set(mime_type),
        size_bytes: Set(size_bytes),
        data: Set(data),
        created_at: Set(created_at.to_rfc3339()),
    };

    let result = tables::attachments::Entity::insert(active).exec(db).await?;

    let inserted = tables::attachments::Entity::find_by_id(result.last_insert_id)
        .one(db)
        .await?
        .ok_or_else(|| DbErr::RecordNotFound("Inserted attachment not found".to_string()))?;

    model_to_attachment(&inserted, task_uuid)
        .ok_or_else(|| DbErr::Custom("Failed to parse inserted attachment".to_string()))
}

/// Delete an attachment by ID.
pub(super) async fn delete_by_id(db: &DatabaseConnection, attachment_id: i32) -> Result<(), DbErr> {
    tables::attachments::Entity::delete_by_id(attachment_id)
        .exec(db)
        .await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::db::connection::get_database;
    use sea_orm::ActiveValue::Set;

    #[tokio::test]
    async fn insert_and_list_attachments() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        let task_uuid = Uuid::new_v4();

        // Create a task first
        let task = tables::tasks::ActiveModel {
            id: Set(None),
            status: Set("PENDING".to_string()),
            uuid: Set(task_uuid.to_string()),
            summary: Set("test task".to_string()),
            date_created: Set(Local::now().to_rfc3339()),
            date_completed: Set(None),
            date_due: Set(None),
            urgency: Set(None),
            project_id: Set(None),
            ..Default::default()
        };
        tables::tasks::Entity::insert(task).exec(&db).await.unwrap();

        // Insert an attachment
        let data = b"Hello, world!".to_vec();
        let inserted = insert_attachment(
            &db,
            task_uuid,
            "test.txt".to_string(),
            "text/plain".to_string(),
            data.clone(),
        )
        .await
        .unwrap();

        assert_eq!(inserted.filename, "test.txt");
        assert_eq!(inserted.mime_type, "text/plain");
        assert_eq!(inserted.size_bytes, 13);
        assert_eq!(inserted.task_uuid, task_uuid);

        // List attachments
        let attachments = list_by_task_uuid(&db, task_uuid).await.unwrap();
        assert_eq!(attachments.len(), 1);
        assert_eq!(attachments[0].id, inserted.id);

        // Get data
        let retrieved_data = get_data_by_id(&db, inserted.id).await.unwrap();
        assert_eq!(retrieved_data, Some(data));

        // Delete
        delete_by_id(&db, inserted.id).await.unwrap();
        let attachments = list_by_task_uuid(&db, task_uuid).await.unwrap();
        assert!(attachments.is_empty());
    }

    #[tokio::test]
    async fn test_cascade_delete() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        let task_uuid = Uuid::new_v4();

        // Create a task
        let task = tables::tasks::ActiveModel {
            id: Set(None),
            status: Set("PENDING".to_string()),
            uuid: Set(task_uuid.to_string()),
            summary: Set("test task".to_string()),
            date_created: Set(Local::now().to_rfc3339()),
            date_completed: Set(None),
            date_due: Set(None),
            urgency: Set(None),
            project_id: Set(None),
            ..Default::default()
        };
        let task_result = tables::tasks::Entity::insert(task).exec(&db).await.unwrap();

        // Insert attachment
        insert_attachment(
            &db,
            task_uuid,
            "cascade-test.txt".to_string(),
            "text/plain".to_string(),
            b"test".to_vec(),
        )
        .await
        .unwrap();

        // Verify attachment exists
        let attachments = list_by_task_uuid(&db, task_uuid).await.unwrap();
        assert_eq!(attachments.len(), 1);

        // Delete task - should cascade delete attachment
        tables::tasks::Entity::delete_by_id(task_result.last_insert_id)
            .exec(&db)
            .await
            .unwrap();

        // Verify attachment is gone (list returns empty since task doesn't exist)
        let attachments = list_by_task_uuid(&db, task_uuid).await.unwrap();
        assert!(attachments.is_empty());
    }
}
