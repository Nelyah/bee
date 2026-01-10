//! Database migrations for bee's SQLite schema.
//!
//! This crate uses SeaORM's migration framework to manage schema evolution.
//! Migrations are automatically applied at application startup via the [`Migrator`] struct.
//!
//! # Migration Naming
//!
//! Files follow the pattern `m<YYYYMMDD>_<HHMMSS>_<description>.rs`, e.g.:
//! - `m20250329_212639_create_task_schema.rs`
//! - `m20251230_000001_create_external_links.rs`
//!
//! # Adding a New Migration
//!
//! 1. Create a new file in `src/` following the naming pattern above
//! 2. Define a `Migration` struct and implement `MigrationTrait`:
//!    ```ignore
//!    pub struct Migration;
//!
//!    #[async_trait::async_trait]
//!    impl MigrationTrait for Migration {
//!        async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
//!            // Create tables, add columns, etc.
//!        }
//!
//!        async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
//!            // Reverse the up migration
//!        }
//!    }
//!    ```
//! 3. Add the module to this file and include it in the `migrations()` vec
//!
//! # Current Migrations
//!
//! - `m20250329_212639_create_task_schema`: Core task tables (tasks, projects, tags, annotations, history)
//! - `m20251230_000001_create_external_links`: External link tracking (GitLab, Jira)
//! - `m20251230_000002_update_external_links_unique`: Unique constraint on external links
//! - `m20250101_000001_create_user_reports`: User-defined saved reports
//! - `m20260101_000001_add_column_settings`: Column widths and sort settings for reports
//! - `m20260104_000001_add_link_types`: Add new link types (ParentOf, RelatedTo, Duplicates)
//! - `m20260105_000001_create_attachments`: File attachments stored as BLOBs
//! - `m20260106_000001_create_email_links`: Email links for Apple Mail integration
//! - `m20260107_000001_create_important_links`: Important URL links on tasks
//! - `m20260110_000001_add_project_emoji_color`: Emoji and color for projects

pub use sea_orm_migration::prelude::sea_orm;
pub use sea_orm_migration::{async_trait, MigrationTrait, MigratorTrait};

mod m20250101_000001_create_user_reports;
mod m20250329_212639_create_task_schema;
mod m20251230_000001_create_external_links;
mod m20251230_000002_update_external_links_unique;
mod m20260101_000001_add_column_settings;
mod m20260104_000001_add_link_types;
mod m20260105_000001_create_attachments;
mod m20260106_000001_create_email_links;
mod m20260107_000001_create_important_links;
mod m20260110_000001_add_project_emoji_color;

/// The migration runner that applies all schema migrations.
///
/// Call `Migrator::up()` to apply pending migrations, or `Migrator::down()` to roll back.
/// Typically invoked at application startup.
pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(m20250329_212639_create_task_schema::Migration),
            Box::new(m20251230_000001_create_external_links::Migration),
            Box::new(m20251230_000002_update_external_links_unique::Migration),
            Box::new(m20250101_000001_create_user_reports::Migration),
            Box::new(m20260101_000001_add_column_settings::Migration),
            Box::new(m20260104_000001_add_link_types::Migration),
            Box::new(m20260105_000001_create_attachments::Migration),
            Box::new(m20260106_000001_create_email_links::Migration),
            Box::new(m20260107_000001_create_important_links::Migration),
            Box::new(m20260110_000001_add_project_emoji_color::Migration),
        ]
    }
}
