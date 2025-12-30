use super::{sync_relations::resolve_uuid_to_db_id, tables};
use crate::external_links::ExternalLink;
use chrono::{DateTime, Utc};
use sea_orm::{
    ActiveModelTrait,
    ActiveValue::{NotSet, Set},
    ColumnTrait, DatabaseConnection, DbErr, EntityTrait, IntoActiveModel, QueryFilter,
};
use std::collections::HashMap;
use uuid::Uuid;

fn parse_rfc3339(value: &Option<String>) -> Option<DateTime<Utc>> {
    value
        .as_ref()
        .and_then(|v| DateTime::parse_from_rfc3339(v).ok())
        .map(|dt| dt.with_timezone(&Utc))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::db::connection::get_database;
    use chrono::Local;
    use sea_orm::ActiveValue::Set;
    use uuid::Uuid;

    #[tokio::test]
    async fn insert_and_list_external_links() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        let task_uuid = Uuid::new_v4();

        let task = tables::tasks::ActiveModel {
            id: Set(None),
            status: Set("PENDING".to_string()),
            uuid: Set(task_uuid.to_string()),
            summary: Set("demo".to_string()),
            date_created: Set(Local::now().to_rfc3339()),
            date_completed: Set(None),
            date_due: Set(None),
            urgency: Set(None),
            project_id: Set(None),
            ..Default::default()
        };

        tables::tasks::Entity::insert(task)
            .exec(&db)
            .await
            .unwrap();

        let inserted = insert_link(
            &db,
            task_uuid,
            "jira".to_string(),
            "https://jira.example.com/browse/ABC-1".to_string(),
            "ABC-1".to_string(),
        )
        .await
        .unwrap();

        let links = list_by_task_uuid(&db, task_uuid).await.unwrap();
        assert_eq!(links.len(), 1);
        assert_eq!(links[0].id, inserted.id);
        assert_eq!(links[0].provider, "jira");
    }
}

async fn load_task_uuid_map(
    db: &DatabaseConnection,
    task_ids: &[i32],
) -> Result<HashMap<i32, Uuid>, DbErr> {
    if task_ids.is_empty() {
        return Ok(HashMap::new());
    }

    let rows = tables::tasks::Entity::find()
        .filter(tables::tasks::Column::DbId.is_in(task_ids.to_vec()))
        .all(db)
        .await?;

    let mut map = HashMap::new();
    for row in rows {
        if let Ok(uuid) = Uuid::parse_str(&row.uuid) {
            map.insert(row.db_id, uuid);
        }
    }
    Ok(map)
}

fn model_to_external_link(model: tables::external_links::Model, task_uuid: Uuid) -> ExternalLink {
    ExternalLink {
        id: model.id,
        task_uuid,
        provider: model.provider,
        url: model.url,
        external_key: model.external_key,
        cached_response: model.cached_response,
        last_synced_at: parse_rfc3339(&model.last_synced_at),
        sync_error: model.sync_error,
    }
}

pub(super) async fn list_by_task_uuid(
    db: &DatabaseConnection,
    task_uuid: Uuid,
) -> Result<Vec<ExternalLink>, DbErr> {
    let task_id = resolve_uuid_to_db_id(db, task_uuid).await?;
    let Some(task_id) = task_id else {
        return Ok(Vec::new());
    };

    let rows = tables::external_links::Entity::find()
        .filter(tables::external_links::Column::TaskId.eq(task_id))
        .all(db)
        .await?;

    Ok(rows
        .into_iter()
        .map(|row| model_to_external_link(row, task_uuid))
        .collect())
}

pub(super) async fn list_all(
    db: &DatabaseConnection,
    provider: Option<&str>,
    task_uuid: Option<Uuid>,
) -> Result<Vec<ExternalLink>, DbErr> {
    let mut query = tables::external_links::Entity::find();

    if let Some(provider) = provider {
        query = query.filter(tables::external_links::Column::Provider.eq(provider));
    }

    if let Some(task_uuid) = task_uuid {
        let task_id = resolve_uuid_to_db_id(db, task_uuid).await?;
        if let Some(task_id) = task_id {
            query = query.filter(tables::external_links::Column::TaskId.eq(task_id));
        } else {
            return Ok(Vec::new());
        }
    }

    let rows = query.all(db).await?;
    let task_ids: Vec<i32> = rows.iter().map(|row| row.task_id).collect();
    let uuid_map = load_task_uuid_map(db, &task_ids).await?;

    let mut links = Vec::with_capacity(rows.len());
    for row in rows {
        if let Some(task_uuid) = uuid_map.get(&row.task_id) {
            links.push(model_to_external_link(row, *task_uuid));
        }
    }
    Ok(links)
}

pub(super) async fn insert_link(
    db: &DatabaseConnection,
    task_uuid: Uuid,
    provider: String,
    url: String,
    external_key: String,
) -> Result<ExternalLink, DbErr> {
    let task_id = resolve_uuid_to_db_id(db, task_uuid).await?;
    let Some(task_id) = task_id else {
        return Err(DbErr::RecordNotFound(format!(
            "Task not found for uuid {task_uuid}"
        )));
    };

    let active = tables::external_links::ActiveModel {
        id: NotSet,
        task_id: Set(task_id),
        provider: Set(provider),
        url: Set(url),
        external_key: Set(external_key),
        cached_response: Set(None),
        last_synced_at: Set(None),
        sync_error: Set(None),
    };

    let result = tables::external_links::Entity::insert(active)
        .exec(db)
        .await?;

    let inserted = tables::external_links::Entity::find_by_id(result.last_insert_id)
        .one(db)
        .await?
        .ok_or_else(|| DbErr::RecordNotFound("Inserted link not found".to_string()))?;

    Ok(model_to_external_link(inserted, task_uuid))
}

pub(super) async fn get_by_id(
    db: &DatabaseConnection,
    link_id: i32,
) -> Result<Option<ExternalLink>, DbErr> {
    let row = tables::external_links::Entity::find_by_id(link_id)
        .one(db)
        .await?;
    let Some(row) = row else {
        return Ok(None);
    };

    let task_uuid = tables::tasks::Entity::find_by_id(row.task_id)
        .one(db)
        .await?
        .and_then(|t| Uuid::parse_str(&t.uuid).ok());
    let Some(task_uuid) = task_uuid else {
        return Ok(None);
    };

    Ok(Some(model_to_external_link(row, task_uuid)))
}

pub(super) async fn delete_by_id(db: &DatabaseConnection, link_id: i32) -> Result<(), DbErr> {
    tables::external_links::Entity::delete_by_id(link_id)
        .exec(db)
        .await?;
    Ok(())
}

pub(super) async fn update_cache_success(
    db: &DatabaseConnection,
    link_id: i32,
    cached_response: String,
    last_synced_at: DateTime<Utc>,
) -> Result<(), DbErr> {
    let Some(model) = tables::external_links::Entity::find_by_id(link_id)
        .one(db)
        .await?
    else {
        return Err(DbErr::RecordNotFound(format!(
            "External link {link_id} not found"
        )));
    };

    let mut active = model.into_active_model();
    active.cached_response = Set(Some(cached_response));
    active.last_synced_at = Set(Some(last_synced_at.to_rfc3339()));
    active.sync_error = Set(None);
    active.save(db).await?;
    Ok(())
}

pub(super) async fn update_sync_error(
    db: &DatabaseConnection,
    link_id: i32,
    sync_error: String,
) -> Result<(), DbErr> {
    let Some(model) = tables::external_links::Entity::find_by_id(link_id)
        .one(db)
        .await?
    else {
        return Err(DbErr::RecordNotFound(format!(
            "External link {link_id} not found"
        )));
    };

    let mut active = model.into_active_model();
    active.sync_error = Set(Some(sync_error));
    active.save(db).await?;
    Ok(())
}
