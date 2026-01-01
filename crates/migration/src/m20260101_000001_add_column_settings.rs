//! Migration to add column customization settings to user_reports.
//!
//! Adds three new columns:
//! - `column_widths`: JSON object storing custom widths (e.g., `{"id": 80, "status": 100}`)
//! - `sort_column`: Column key to sort by (e.g., "status"), null means default urgency sort
//! - `sort_direction`: "ascending" or "descending"

use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // Add column_widths - JSON string storing custom column widths
        manager
            .alter_table(
                Table::alter()
                    .table(UserReports::Table)
                    .add_column(ColumnDef::new(UserReports::ColumnWidths).text().null())
                    .to_owned(),
            )
            .await?;

        // Add sort_column - which column to sort by (null = urgency default)
        manager
            .alter_table(
                Table::alter()
                    .table(UserReports::Table)
                    .add_column(ColumnDef::new(UserReports::SortColumn).string().null())
                    .to_owned(),
            )
            .await?;

        // Add sort_direction - "ascending" or "descending"
        manager
            .alter_table(
                Table::alter()
                    .table(UserReports::Table)
                    .add_column(ColumnDef::new(UserReports::SortDirection).string().null())
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // SQLite doesn't support DROP COLUMN directly, so we need to recreate the table
        // For simplicity in rollback, we'll just drop the columns if the DB supports it
        // Most modern SQLite versions (3.35+) support ALTER TABLE DROP COLUMN

        manager
            .alter_table(
                Table::alter()
                    .table(UserReports::Table)
                    .drop_column(UserReports::SortDirection)
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(UserReports::Table)
                    .drop_column(UserReports::SortColumn)
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(UserReports::Table)
                    .drop_column(UserReports::ColumnWidths)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}

#[derive(Iden)]
enum UserReports {
    Table,
    ColumnWidths,
    SortColumn,
    SortDirection,
}
