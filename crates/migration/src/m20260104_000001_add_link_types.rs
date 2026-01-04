//! Migration to add new link types: ParentOf, RelatedTo, Duplicates
//!
//! This migration updates the CHECK constraint on the `links.type` column
//! to allow the new link types beyond the original DependsOn and Blocking.
//!
//! Note: SQLite doesn't support ALTER TABLE to modify constraints, so we must
//! recreate the table with the new CHECK constraint.

use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let db = manager.get_connection();

        // SQLite table recreation pattern to update CHECK constraint
        // 1. Create new table with updated CHECK constraint
        // 2. Copy data from old table
        // 3. Drop old table
        // 4. Rename new table to original name

        db.execute_unprepared(
            r#"
            PRAGMA foreign_keys=OFF;

            CREATE TABLE links_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                from_task_id INTEGER NOT NULL,
                to_task_id INTEGER NOT NULL,
                type TEXT NOT NULL CHECK(type IN ('DependsOn', 'ParentOf', 'RelatedTo', 'Duplicates')),
                FOREIGN KEY (from_task_id) REFERENCES tasks(db_id) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (to_task_id) REFERENCES tasks(db_id) ON DELETE CASCADE ON UPDATE CASCADE
            );

            INSERT INTO links_new (id, from_task_id, to_task_id, type)
            SELECT id, from_task_id, to_task_id, type FROM links;

            DROP TABLE links;

            ALTER TABLE links_new RENAME TO links;

            CREATE UNIQUE INDEX idx_unique_link ON links (from_task_id, to_task_id, type);

            PRAGMA foreign_keys=ON;
            "#,
        )
        .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let db = manager.get_connection();

        // Revert to original CHECK constraint (only DependsOn allowed in storage)
        // Note: This will fail if there's data with new link types
        db.execute_unprepared(
            r#"
            PRAGMA foreign_keys=OFF;

            CREATE TABLE links_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                from_task_id INTEGER NOT NULL,
                to_task_id INTEGER NOT NULL,
                type TEXT NOT NULL CHECK(type IN ('DependsOn', 'Blocking')),
                FOREIGN KEY (from_task_id) REFERENCES tasks(db_id) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (to_task_id) REFERENCES tasks(db_id) ON DELETE CASCADE ON UPDATE CASCADE
            );

            INSERT INTO links_new (id, from_task_id, to_task_id, type)
            SELECT id, from_task_id, to_task_id, type FROM links
            WHERE type IN ('DependsOn', 'Blocking');

            DROP TABLE links;

            ALTER TABLE links_new RENAME TO links;

            CREATE UNIQUE INDEX idx_unique_link ON links (from_task_id, to_task_id, type);

            PRAGMA foreign_keys=ON;
            "#,
        )
        .await?;

        Ok(())
    }
}
