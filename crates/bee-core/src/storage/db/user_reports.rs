use super::tables;
use chrono::{DateTime, Utc};
use sea_orm::{
    ActiveModelTrait,
    ActiveValue::{NotSet, Set},
    ColumnTrait, DatabaseConnection, DbErr, EntityTrait, QueryFilter,
};
use serde_json::Value;

/// User-created report stored in database
#[derive(Debug, Clone)]
pub struct UserReport {
    pub id: i32,
    pub name: String,
    /// Serialized filter JSON from parse API (replaces filter expression strings)
    pub filter: Option<Value>,
    pub columns: Vec<String>,
    pub column_names: Vec<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

fn parse_rfc3339(value: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}

fn parse_json_array(value: &str) -> Vec<String> {
    serde_json::from_str(value).unwrap_or_default()
}

fn serialize_json_array(values: &[String]) -> String {
    serde_json::to_string(values).unwrap_or_else(|_| "[]".to_string())
}

/// Parse the filter column from JSON string back to Value.
/// Returns None if empty string, empty object, or null.
fn parse_filter_json(value: &str) -> Option<Value> {
    if value.is_empty() {
        return None;
    }
    match serde_json::from_str::<Value>(value) {
        Ok(v) if v.is_null() => None,
        Ok(v) if v.as_object().is_some_and(|o| o.is_empty()) => None,
        Ok(v) => Some(v),
        Err(_) => None,
    }
}

/// Serialize filter to JSON string for storage.
fn serialize_filter_json(filter: &Option<Value>) -> String {
    match filter {
        Some(v) => serde_json::to_string(v).unwrap_or_default(),
        None => String::new(),
    }
}

fn model_to_user_report(model: tables::user_reports::Model) -> UserReport {
    UserReport {
        id: model.id,
        name: model.name,
        filter: parse_filter_json(&model.filters),
        columns: parse_json_array(&model.columns),
        column_names: parse_json_array(&model.column_names),
        created_at: parse_rfc3339(&model.created_at).unwrap_or_else(Utc::now),
        updated_at: parse_rfc3339(&model.updated_at).unwrap_or_else(Utc::now),
    }
}

pub(super) async fn list_all(db: &DatabaseConnection) -> Result<Vec<UserReport>, DbErr> {
    let rows = tables::user_reports::Entity::find().all(db).await?;
    Ok(rows.into_iter().map(model_to_user_report).collect())
}

pub(super) async fn get_by_name(
    db: &DatabaseConnection,
    name: &str,
) -> Result<Option<UserReport>, DbErr> {
    let row = tables::user_reports::Entity::find()
        .filter(tables::user_reports::Column::Name.eq(name))
        .one(db)
        .await?;
    Ok(row.map(model_to_user_report))
}

pub(super) async fn insert(
    db: &DatabaseConnection,
    name: String,
    filter: Option<Value>,
    columns: Vec<String>,
    column_names: Vec<String>,
) -> Result<UserReport, DbErr> {
    let now = Utc::now().to_rfc3339();

    let active = tables::user_reports::ActiveModel {
        id: NotSet,
        name: Set(name),
        filters: Set(serialize_filter_json(&filter)),
        columns: Set(serialize_json_array(&columns)),
        column_names: Set(serialize_json_array(&column_names)),
        created_at: Set(now.clone()),
        updated_at: Set(now),
    };

    let result = tables::user_reports::Entity::insert(active)
        .exec(db)
        .await?;

    let inserted = tables::user_reports::Entity::find_by_id(result.last_insert_id)
        .one(db)
        .await?
        .ok_or_else(|| DbErr::RecordNotFound("Inserted user report not found".to_string()))?;

    Ok(model_to_user_report(inserted))
}

pub(super) async fn update(
    db: &DatabaseConnection,
    name: &str,
    filter: Option<Value>,
    columns: Vec<String>,
    column_names: Vec<String>,
) -> Result<UserReport, DbErr> {
    let existing = tables::user_reports::Entity::find()
        .filter(tables::user_reports::Column::Name.eq(name))
        .one(db)
        .await?
        .ok_or_else(|| DbErr::RecordNotFound(format!("User report '{name}' not found")))?;

    let now = Utc::now().to_rfc3339();

    let mut active: tables::user_reports::ActiveModel = existing.into();
    active.filters = Set(serialize_filter_json(&filter));
    active.columns = Set(serialize_json_array(&columns));
    active.column_names = Set(serialize_json_array(&column_names));
    active.updated_at = Set(now);

    let updated = active.update(db).await?;
    Ok(model_to_user_report(updated))
}

pub(super) async fn delete_by_name(db: &DatabaseConnection, name: &str) -> Result<(), DbErr> {
    let result = tables::user_reports::Entity::delete_many()
        .filter(tables::user_reports::Column::Name.eq(name))
        .exec(db)
        .await?;

    if result.rows_affected == 0 {
        return Err(DbErr::RecordNotFound(format!(
            "User report '{name}' not found"
        )));
    }

    Ok(())
}

/// Get all user report names (used for collision detection at startup)
pub(super) async fn list_names(db: &DatabaseConnection) -> Result<Vec<String>, DbErr> {
    let rows = tables::user_reports::Entity::find().all(db).await?;
    Ok(rows.into_iter().map(|r| r.name).collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::db::connection::get_database;
    use serde_json::json;

    #[tokio::test]
    async fn test_insert_and_list_user_reports() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let filter = Some(json!({"type": "StatusFilter", "status": "pending"}));
        let inserted = insert(
            &db,
            "my-report".to_string(),
            filter.clone(),
            vec!["id".to_string(), "summary".to_string()],
            vec!["ID".to_string(), "Summary".to_string()],
        )
        .await
        .unwrap();

        assert_eq!(inserted.name, "my-report");
        assert_eq!(inserted.filter, filter);
        assert_eq!(inserted.columns, vec!["id", "summary"]);
        assert_eq!(inserted.column_names, vec!["ID", "Summary"]);

        let all = list_all(&db).await.unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].name, "my-report");
    }

    #[tokio::test]
    async fn test_get_by_name() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let filter = Some(json!({"type": "ProjectFilter", "project": "acme"}));
        insert(
            &db,
            "test-report".to_string(),
            filter.clone(),
            vec!["id".to_string()],
            vec!["ID".to_string()],
        )
        .await
        .unwrap();

        let found = get_by_name(&db, "test-report").await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().filter, filter);

        let not_found = get_by_name(&db, "nonexistent").await.unwrap();
        assert!(not_found.is_none());
    }

    #[tokio::test]
    async fn test_update_user_report() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        insert(
            &db,
            "update-test".to_string(),
            Some(json!({"type": "StatusFilter", "status": "pending"})),
            vec!["id".to_string()],
            vec!["ID".to_string()],
        )
        .await
        .unwrap();

        let new_filter = Some(json!({
            "type": "AndFilter",
            "filters": [
                {"type": "StatusFilter", "status": "active"},
                {"type": "ProjectFilter", "project": "foo"}
            ]
        }));
        let updated = update(
            &db,
            "update-test",
            new_filter.clone(),
            vec!["id".to_string(), "summary".to_string()],
            vec!["ID".to_string(), "Summary".to_string()],
        )
        .await
        .unwrap();

        assert_eq!(updated.filter, new_filter);
        assert_eq!(updated.columns, vec!["id", "summary"]);
    }

    #[tokio::test]
    async fn test_delete_user_report() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        insert(&db, "delete-test".to_string(), None, vec![], vec![])
            .await
            .unwrap();

        let before = list_all(&db).await.unwrap();
        assert_eq!(before.len(), 1);

        delete_by_name(&db, "delete-test").await.unwrap();

        let after = list_all(&db).await.unwrap();
        assert!(after.is_empty());
    }

    #[tokio::test]
    async fn test_delete_nonexistent_returns_error() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let result = delete_by_name(&db, "nonexistent").await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_list_names() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        insert(&db, "report-a".to_string(), None, vec![], vec![])
            .await
            .unwrap();
        insert(&db, "report-b".to_string(), None, vec![], vec![])
            .await
            .unwrap();

        let names = list_names(&db).await.unwrap();
        assert_eq!(names.len(), 2);
        assert!(names.contains(&"report-a".to_string()));
        assert!(names.contains(&"report-b".to_string()));
    }

    #[tokio::test]
    async fn test_null_filter_roundtrip() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        // Insert with None filter
        let inserted = insert(&db, "no-filter".to_string(), None, vec![], vec![])
            .await
            .unwrap();
        assert!(inserted.filter.is_none());

        // Read back
        let found = get_by_name(&db, "no-filter").await.unwrap().unwrap();
        assert!(found.filter.is_none());
    }
}
