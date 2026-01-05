use async_std::test;
use migration::sea_orm::{
    ConnectionTrait, Database, DatabaseBackend, DatabaseConnection, Statement,
};
use migration::{Migrator, MigratorTrait};

use std::collections::hash_map::RandomState;
use std::hash::{BuildHasher, Hasher};
use std::time::{SystemTime, UNIX_EPOCH};

/// Builds a unique SQLite file URL for a test database.
///
/// Uses both nanosecond timestamp AND a random component to ensure uniqueness
/// even when tests run in parallel and start at the same nanosecond.
fn temp_sqlite_url() -> String {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("time went backwards")
        .as_nanos();
    // RandomState provides per-process randomness, making collisions extremely unlikely
    let random = RandomState::new().build_hasher().finish();
    let path = std::env::temp_dir().join(format!("bee-migration-{}-{}.sqlite", nanos, random));
    format!("sqlite://{}?mode=rwc", path.display())
}

/// Enables foreign key enforcement for the SQLite connection.
async fn enable_foreign_keys(db: &DatabaseConnection) {
    db.execute(Statement::from_string(
        DatabaseBackend::Sqlite,
        "PRAGMA foreign_keys = ON",
    ))
    .await
    .expect("failed to enable foreign keys");
}

/// Inserts a task and returns its db_id.
async fn insert_task(db: &DatabaseConnection, uuid: &str) -> i64 {
    let insert = Statement::from_string(
        DatabaseBackend::Sqlite,
        format!(
            "INSERT INTO tasks (status, uuid, summary, date_created) \
             VALUES ('PENDING', '{}', 'summary', '2020-01-01T00:00:00+00:00')",
            uuid
        ),
    );
    db.execute(insert).await.expect("failed to insert task");

    let query = Statement::from_string(
        DatabaseBackend::Sqlite,
        format!("SELECT db_id FROM tasks WHERE uuid = '{}'", uuid),
    );
    let row = db
        .query_one(query)
        .await
        .expect("failed to query task")
        .expect("task row missing");
    row.try_get("", "db_id").expect("failed to read db_id")
}

/// Verifies foreign key enforcement rejects invalid references.
#[test]
async fn foreign_keys_are_enforced() {
    let db = Database::connect(temp_sqlite_url())
        .await
        .expect("failed to connect");
    Migrator::up(&db, None).await.expect("migration failed");
    enable_foreign_keys(&db).await;

    let insert = Statement::from_string(
        DatabaseBackend::Sqlite,
        "INSERT INTO history (value, datetime, task_id) \
         VALUES ('event', '2020-01-01T00:00:00+00:00', 999)",
    );
    let result = db.execute(insert).await;
    assert!(result.is_err(), "expected FK violation on history.task_id");
}

/// Verifies task UUIDs are unique.
#[test]
async fn task_uuid_is_unique() {
    let db = Database::connect(temp_sqlite_url())
        .await
        .expect("failed to connect");
    Migrator::up(&db, None).await.expect("migration failed");

    insert_task(&db, "dup-uuid").await;
    let insert_dup = Statement::from_string(
        DatabaseBackend::Sqlite,
        "INSERT INTO tasks (status, uuid, summary, date_created) \
         VALUES ('PENDING', 'dup-uuid', 'summary', '2020-01-01T00:00:00+00:00')",
    );
    let result = db.execute(insert_dup).await;
    assert!(result.is_err(), "expected unique constraint on tasks.uuid");
}

/// Verifies link types are restricted to the supported enum values.
#[test]
async fn link_type_is_restricted() {
    let db = Database::connect(temp_sqlite_url())
        .await
        .expect("failed to connect");
    Migrator::up(&db, None).await.expect("migration failed");
    enable_foreign_keys(&db).await;

    let from_id = insert_task(&db, "link-from").await;
    let to_id = insert_task(&db, "link-to").await;
    let insert = Statement::from_string(
        DatabaseBackend::Sqlite,
        format!(
            "INSERT INTO links (from_task_id, to_task_id, type) VALUES ({}, {}, 'Invalid')",
            from_id, to_id
        ),
    );
    let result = db.execute(insert).await;
    assert!(result.is_err(), "expected check constraint on links.type");
}
