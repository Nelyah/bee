//! Migration to create the attachments table for storing file attachments.
//!
//! Files are stored as BLOBs directly in the database for simplicity:
//! - Single file backup (database contains everything)
//! - Atomic transactions - file save and metadata are one operation
//! - Portable - just copy the .db file

use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Attachments::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Attachments::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(ColumnDef::new(Attachments::TaskId).unsigned().not_null())
                    .col(
                        ColumnDef::new(Attachments::Uuid)
                            .string()
                            .not_null()
                            .unique_key(),
                    )
                    .col(ColumnDef::new(Attachments::Filename).string().not_null())
                    .col(ColumnDef::new(Attachments::MimeType).string().not_null())
                    .col(
                        ColumnDef::new(Attachments::SizeBytes)
                            .big_integer()
                            .not_null(),
                    )
                    .col(ColumnDef::new(Attachments::Data).blob().not_null())
                    .col(ColumnDef::new(Attachments::CreatedAt).string().not_null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_attachments_task")
                            .from(Attachments::Table, Attachments::TaskId)
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
                    .table(Attachments::Table)
                    .name("idx_attachments_task")
                    .col(Attachments::TaskId)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .table(Attachments::Table)
                    .name("idx_attachments_task")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_table(Table::drop().table(Attachments::Table).to_owned())
            .await?;
        Ok(())
    }
}

#[derive(Iden)]
enum Attachments {
    Table,
    Id,
    TaskId,
    Uuid,
    Filename,
    MimeType,
    SizeBytes,
    Data,
    CreatedAt,
}

#[derive(Iden)]
enum Tasks {
    Table,
    DbId,
}
