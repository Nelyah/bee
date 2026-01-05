//! Migration to create the important_links table for user-defined URLs on tasks.
//!
//! Important links allow users to attach relevant URLs to tasks for quick
//! access to documentation, tickets, or other web resources.

use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(ImportantLinks::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(ImportantLinks::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(ColumnDef::new(ImportantLinks::TaskId).unsigned().not_null())
                    .col(
                        ColumnDef::new(ImportantLinks::Uuid)
                            .string()
                            .not_null()
                            .unique_key(),
                    )
                    .col(ColumnDef::new(ImportantLinks::Url).string().not_null())
                    .col(ColumnDef::new(ImportantLinks::Title).string().not_null())
                    .col(
                        ColumnDef::new(ImportantLinks::CreatedAt)
                            .string()
                            .not_null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_important_links_task")
                            .from(ImportantLinks::Table, ImportantLinks::TaskId)
                            .to(Tasks::Table, Tasks::DbId)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // Index for efficient lookup by task
        manager
            .create_index(
                Index::create()
                    .table(ImportantLinks::Table)
                    .name("idx_important_links_task")
                    .col(ImportantLinks::TaskId)
                    .to_owned(),
            )
            .await?;

        // Unique index on (task_id, url) to prevent duplicate links
        manager
            .create_index(
                Index::create()
                    .table(ImportantLinks::Table)
                    .name("idx_important_links_task_url")
                    .col(ImportantLinks::TaskId)
                    .col(ImportantLinks::Url)
                    .unique()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .table(ImportantLinks::Table)
                    .name("idx_important_links_task_url")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .table(ImportantLinks::Table)
                    .name("idx_important_links_task")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_table(Table::drop().table(ImportantLinks::Table).to_owned())
            .await?;
        Ok(())
    }
}

#[derive(Iden)]
enum ImportantLinks {
    Table,
    Id,
    TaskId,
    Uuid,
    Url,
    Title,
    CreatedAt,
}

#[derive(Iden)]
enum Tasks {
    Table,
    DbId,
}
