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
    /// Custom column widths as JSON object: {"column_key": width}
    pub column_widths: Option<Value>,
    /// Column key to sort by (e.g., "status"). None means default urgency sort.
    pub sort_column: Option<String>,
    /// Sort direction: "ascending" or "descending"
    pub sort_direction: Option<String>,
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

/// Parse column widths JSON from optional string.
fn parse_column_widths(value: &Option<String>) -> Option<Value> {
    value.as_ref().and_then(|s| {
        if s.is_empty() {
            None
        } else {
            serde_json::from_str(s).ok()
        }
    })
}

/// Serialize column widths to JSON string.
fn serialize_column_widths(widths: &Option<Value>) -> Option<String> {
    widths
        .as_ref()
        .map(|v| serde_json::to_string(v).unwrap_or_default())
}

fn model_to_user_report(model: tables::user_reports::Model) -> UserReport {
    UserReport {
        id: model.id,
        name: model.name,
        filter: parse_filter_json(&model.filters),
        columns: parse_json_array(&model.columns),
        column_names: parse_json_array(&model.column_names),
        column_widths: parse_column_widths(&model.column_widths),
        sort_column: model.sort_column,
        sort_direction: model.sort_direction,
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

/// Parameters for creating or updating a user report.
#[derive(Debug, Clone, Default)]
pub struct UserReportParams {
    pub filter: Option<Value>,
    pub columns: Vec<String>,
    pub column_names: Vec<String>,
    pub column_widths: Option<Value>,
    pub sort_column: Option<String>,
    pub sort_direction: Option<String>,
}

pub(super) async fn insert(
    db: &DatabaseConnection,
    name: String,
    params: UserReportParams,
) -> Result<UserReport, DbErr> {
    let now = Utc::now().to_rfc3339();

    let active = tables::user_reports::ActiveModel {
        id: NotSet,
        name: Set(name),
        filters: Set(serialize_filter_json(&params.filter)),
        columns: Set(serialize_json_array(&params.columns)),
        column_names: Set(serialize_json_array(&params.column_names)),
        column_widths: Set(serialize_column_widths(&params.column_widths)),
        sort_column: Set(params.sort_column),
        sort_direction: Set(params.sort_direction),
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
    params: UserReportParams,
) -> Result<UserReport, DbErr> {
    let existing = tables::user_reports::Entity::find()
        .filter(tables::user_reports::Column::Name.eq(name))
        .one(db)
        .await?
        .ok_or_else(|| DbErr::RecordNotFound(format!("User report '{name}' not found")))?;

    let now = Utc::now().to_rfc3339();

    let mut active: tables::user_reports::ActiveModel = existing.into();
    active.filters = Set(serialize_filter_json(&params.filter));
    active.columns = Set(serialize_json_array(&params.columns));
    active.column_names = Set(serialize_json_array(&params.column_names));
    active.column_widths = Set(serialize_column_widths(&params.column_widths));
    active.sort_column = Set(params.sort_column);
    active.sort_direction = Set(params.sort_direction);
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
        let params = UserReportParams {
            filter: filter.clone(),
            columns: vec!["id".to_string(), "summary".to_string()],
            column_names: vec!["ID".to_string(), "Summary".to_string()],
            ..Default::default()
        };
        let inserted = insert(&db, "my-report".to_string(), params).await.unwrap();

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
        let params = UserReportParams {
            filter: filter.clone(),
            columns: vec!["id".to_string()],
            column_names: vec!["ID".to_string()],
            ..Default::default()
        };
        insert(&db, "test-report".to_string(), params)
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

        let initial_params = UserReportParams {
            filter: Some(json!({"type": "StatusFilter", "status": "pending"})),
            columns: vec!["id".to_string()],
            column_names: vec!["ID".to_string()],
            ..Default::default()
        };
        insert(&db, "update-test".to_string(), initial_params)
            .await
            .unwrap();

        let new_filter = Some(json!({
            "type": "AndFilter",
            "filters": [
                {"type": "StatusFilter", "status": "active"},
                {"type": "ProjectFilter", "project": "foo"}
            ]
        }));
        let update_params = UserReportParams {
            filter: new_filter.clone(),
            columns: vec!["id".to_string(), "summary".to_string()],
            column_names: vec!["ID".to_string(), "Summary".to_string()],
            sort_column: Some("status".to_string()),
            sort_direction: Some("ascending".to_string()),
            ..Default::default()
        };
        let updated = update(&db, "update-test", update_params).await.unwrap();

        assert_eq!(updated.filter, new_filter);
        assert_eq!(updated.columns, vec!["id", "summary"]);
        assert_eq!(updated.sort_column, Some("status".to_string()));
        assert_eq!(updated.sort_direction, Some("ascending".to_string()));
    }

    #[tokio::test]
    async fn test_delete_user_report() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        insert(&db, "delete-test".to_string(), UserReportParams::default())
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

        insert(&db, "report-a".to_string(), UserReportParams::default())
            .await
            .unwrap();
        insert(&db, "report-b".to_string(), UserReportParams::default())
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
        let inserted = insert(&db, "no-filter".to_string(), UserReportParams::default())
            .await
            .unwrap();
        assert!(inserted.filter.is_none());

        // Read back
        let found = get_by_name(&db, "no-filter").await.unwrap().unwrap();
        assert!(found.filter.is_none());
    }

    #[tokio::test]
    async fn test_column_settings_roundtrip() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let column_widths = Some(json!({"id": 80, "summary": 300}));
        let params = UserReportParams {
            filter: None,
            columns: vec!["id".to_string(), "summary".to_string()],
            column_names: vec!["ID".to_string(), "Summary".to_string()],
            column_widths: column_widths.clone(),
            sort_column: Some("urgency".to_string()),
            sort_direction: Some("descending".to_string()),
        };
        let inserted = insert(&db, "sorted-report".to_string(), params)
            .await
            .unwrap();

        assert_eq!(inserted.column_widths, column_widths);
        assert_eq!(inserted.sort_column, Some("urgency".to_string()));
        assert_eq!(inserted.sort_direction, Some("descending".to_string()));

        // Read back
        let found = get_by_name(&db, "sorted-report").await.unwrap().unwrap();
        assert_eq!(found.column_widths, column_widths);
        assert_eq!(found.sort_column, Some("urgency".to_string()));
        assert_eq!(found.sort_direction, Some("descending".to_string()));
    }
}
