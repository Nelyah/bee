use migration::{Migrator, MigratorTrait, sea_orm::Database};
use sea_orm::{ConnectionTrait, DatabaseBackend, DatabaseConnection, Statement};
use std::path::PathBuf;

use crate::CoreResult;

const SQLITE_BUSY_TIMEOUT_MS: u64 = 5_000;

/// Returns the database URL using a fallback chain:
/// 1. `BEE_DATABASE_URL` env var (full connection string)
/// 2. `BEE_DATA_HOME` env var + `/bee.sqlite`
/// 3. `XDG_DATA_HOME/bee/bee.sqlite`
/// 4. `~/.local/share/bee/bee.sqlite`
/// 5. `./bee.sqlite` (fallback)
fn get_database_url() -> String {
    // 1. Check BEE_DATABASE_URL for a full connection string
    if let Ok(url) = std::env::var("BEE_DATABASE_URL") {
        return url;
    }

    // Helper to build SQLite URL from path
    let build_url = |path: PathBuf| -> String { format!("sqlite://{}?mode=rwc", path.display()) };

    // 2. Check BEE_DATA_HOME
    if let Ok(data_home) = std::env::var("BEE_DATA_HOME") {
        let path = PathBuf::from(data_home).join("bee.sqlite");
        return build_url(path);
    }

    // 3. Check XDG_DATA_HOME
    if let Ok(xdg_data) = std::env::var("XDG_DATA_HOME") {
        let path = PathBuf::from(xdg_data).join("bee").join("bee.sqlite");
        return build_url(path);
    }

    // 4. Use ~/.local/share/bee/bee.sqlite
    if let Some(home) = std::env::var_os("HOME") {
        let path = PathBuf::from(home)
            .join(".local")
            .join("share")
            .join("bee")
            .join("bee.sqlite");
        return build_url(path);
    }

    // 5. Fallback to current directory
    build_url(PathBuf::from("bee.sqlite"))
}

/// Creates parent directories for the database file if they don't exist.
fn ensure_parent_directories(db_url: &str) -> CoreResult<()> {
    // Extract path from SQLite URL (sqlite://path?mode=rwc)
    if let Some(path_str) = db_url
        .strip_prefix("sqlite://")
        .and_then(|s| s.split('?').next())
    {
        let path = PathBuf::from(path_str);
        if let Some(parent) = path.parent()
            && !parent.as_os_str().is_empty()
            && !parent.exists()
        {
            std::fs::create_dir_all(parent)?;
        }
    }
    Ok(())
}

pub(super) async fn get_database(db_address: Option<&str>) -> CoreResult<DatabaseConnection> {
    let url = match db_address {
        Some(addr) => addr.to_string(),
        None => get_database_url(),
    };

    // Ensure parent directories exist
    ensure_parent_directories(&url)?;

    let db = Database::connect(&url).await?;

    if url.starts_with("sqlite:") {
        apply_sqlite_pragmas(&db).await?;
    }

    Migrator::up(&db, None).await?;

    Ok(db)
}

/// Apply SQLite pragmas that improve concurrency and integrity.
async fn apply_sqlite_pragmas(db: &DatabaseConnection) -> CoreResult<()> {
    db.execute(Statement::from_string(
        DatabaseBackend::Sqlite,
        "PRAGMA foreign_keys = ON",
    ))
    .await?;
    db.execute(Statement::from_string(
        DatabaseBackend::Sqlite,
        format!("PRAGMA busy_timeout = {}", SQLITE_BUSY_TIMEOUT_MS),
    ))
    .await?;
    db.execute(Statement::from_string(
        DatabaseBackend::Sqlite,
        "PRAGMA journal_mode = WAL",
    ))
    .await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use sea_orm::Database;
    use std::time::{SystemTime, UNIX_EPOCH};

    /// Build a unique SQLite database URL under the OS temp directory.
    fn temp_db_url() -> String {
        let suffix = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("time should be after epoch")
            .as_nanos();
        let mut path = std::env::temp_dir();
        path.push(format!("bee_test_{}.sqlite", suffix));
        format!("sqlite://{}?mode=rwc", path.display())
    }

    #[tokio::test]
    async fn apply_sqlite_pragmas_sets_busy_timeout_and_foreign_keys() {
        let url = temp_db_url();
        let db = Database::connect(&url).await.unwrap();
        apply_sqlite_pragmas(&db).await.unwrap();

        let timeout_row = db
            .query_one(Statement::from_string(
                DatabaseBackend::Sqlite,
                "PRAGMA busy_timeout",
            ))
            .await
            .unwrap()
            .expect("busy_timeout row");
        let timeout: i64 = timeout_row.try_get("", "timeout").unwrap();
        assert_eq!(timeout, SQLITE_BUSY_TIMEOUT_MS as i64);

        let fk_row = db
            .query_one(Statement::from_string(
                DatabaseBackend::Sqlite,
                "PRAGMA foreign_keys",
            ))
            .await
            .unwrap()
            .expect("foreign_keys row");
        let foreign_keys: i64 = fk_row.try_get("", "foreign_keys").unwrap();
        assert_eq!(foreign_keys, 1);
    }
}
