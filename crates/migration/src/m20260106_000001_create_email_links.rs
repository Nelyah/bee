//! Migration to create the email_links table for linking emails to tasks.
//!
//! Email links store references to emails in Apple Mail, allowing users
//! to quickly access related emails from their tasks. The `message://` URL
//! scheme is used to open emails in Mail.app.

use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(EmailLinks::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(EmailLinks::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(ColumnDef::new(EmailLinks::TaskId).unsigned().not_null())
                    .col(
                        ColumnDef::new(EmailLinks::Uuid)
                            .string()
                            .not_null()
                            .unique_key(),
                    )
                    .col(ColumnDef::new(EmailLinks::MessageId).string().not_null())
                    .col(ColumnDef::new(EmailLinks::Subject).string().not_null())
                    .col(ColumnDef::new(EmailLinks::Sender).string().not_null())
                    .col(ColumnDef::new(EmailLinks::SentDate).string().null())
                    .col(ColumnDef::new(EmailLinks::CreatedAt).string().not_null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_email_links_task")
                            .from(EmailLinks::Table, EmailLinks::TaskId)
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
                    .table(EmailLinks::Table)
                    .name("idx_email_links_task")
                    .col(EmailLinks::TaskId)
                    .to_owned(),
            )
            .await?;

        // Unique index on (task_id, message_id) to prevent duplicate links
        manager
            .create_index(
                Index::create()
                    .table(EmailLinks::Table)
                    .name("idx_email_links_task_message")
                    .col(EmailLinks::TaskId)
                    .col(EmailLinks::MessageId)
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
                    .table(EmailLinks::Table)
                    .name("idx_email_links_task_message")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .table(EmailLinks::Table)
                    .name("idx_email_links_task")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_table(Table::drop().table(EmailLinks::Table).to_owned())
            .await?;
        Ok(())
    }
}

#[derive(Iden)]
enum EmailLinks {
    Table,
    Id,
    TaskId,
    Uuid,
    MessageId,
    Subject,
    Sender,
    SentDate,
    CreatedAt,
}

#[derive(Iden)]
enum Tasks {
    Table,
    DbId,
}
