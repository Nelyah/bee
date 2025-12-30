use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(ExternalLinks::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(ExternalLinks::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(ColumnDef::new(ExternalLinks::TaskId).unsigned().not_null())
                    .col(ColumnDef::new(ExternalLinks::Provider).string().not_null())
                    .col(ColumnDef::new(ExternalLinks::Url).string().not_null())
                    .col(
                        ColumnDef::new(ExternalLinks::ExternalKey)
                            .string()
                            .not_null(),
                    )
                    .col(ColumnDef::new(ExternalLinks::CachedResponse).text().null())
                    .col(ColumnDef::new(ExternalLinks::LastSyncedAt).string().null())
                    .col(ColumnDef::new(ExternalLinks::SyncError).string().null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_external_links_task")
                            .from(ExternalLinks::Table, ExternalLinks::TaskId)
                            .to(Tasks::Table, Tasks::DbId)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .table(ExternalLinks::Table)
                    .name("idx_external_links_task")
                    .col(ExternalLinks::TaskId)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .table(ExternalLinks::Table)
                    .name("idx_external_links_provider_key")
                    .col(ExternalLinks::Provider)
                    .col(ExternalLinks::ExternalKey)
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
                    .table(ExternalLinks::Table)
                    .name("idx_external_links_provider_key")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .table(ExternalLinks::Table)
                    .name("idx_external_links_task")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_table(Table::drop().table(ExternalLinks::Table).to_owned())
            .await?;
        Ok(())
    }
}

#[derive(Iden)]
enum ExternalLinks {
    Table,
    Id,
    TaskId,
    Provider,
    Url,
    ExternalKey,
    CachedResponse,
    LastSyncedAt,
    SyncError,
}

#[derive(Iden)]
enum Tasks {
    Table,
    DbId,
}
