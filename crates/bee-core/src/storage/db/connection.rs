use migration::{Migrator, MigratorTrait, sea_orm::Database};
use sea_orm::{ConnectionTrait, DatabaseBackend, DatabaseConnection, Statement};
use std::path::PathBuf;

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
fn ensure_parent_directories(db_url: &str) -> Result<(), Box<dyn std::error::Error>> {
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

pub(super) async fn get_database(
    db_address: Option<&str>,
) -> Result<DatabaseConnection, Box<dyn std::error::Error>> {
    let url = match db_address {
        Some(addr) => addr.to_string(),
        None => get_database_url(),
    };

    // Ensure parent directories exist
    ensure_parent_directories(&url)?;

    let db = Database::connect(&url).await?;

    if url.starts_with("sqlite:") {
        db.execute(Statement::from_string(
            DatabaseBackend::Sqlite,
            "PRAGMA foreign_keys = ON",
        ))
        .await?;
    }

    Migrator::up(&db, None).await?;

    Ok(db)
}
