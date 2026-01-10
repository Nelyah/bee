//! Migration to add emoji and color columns to projects.
//!
//! Adds two new columns:
//! - `emoji`: Optional single emoji character for visual identification
//! - `color`: Optional hex color string (e.g., "#FF5733") for project theming

use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // Add emoji column - stores single emoji character
        manager
            .alter_table(
                Table::alter()
                    .table(Projects::Table)
                    .add_column(ColumnDef::new(Projects::Emoji).string().null())
                    .to_owned(),
            )
            .await?;

        // Add color column - stores hex color (e.g., "#FF5733")
        manager
            .alter_table(
                Table::alter()
                    .table(Projects::Table)
                    .add_column(ColumnDef::new(Projects::Color).string().null())
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(Projects::Table)
                    .drop_column(Projects::Color)
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Projects::Table)
                    .drop_column(Projects::Emoji)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}

#[derive(Iden)]
enum Projects {
    Table,
    Emoji,
    Color,
}
