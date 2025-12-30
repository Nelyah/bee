use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .table(ExternalLinks::Table)
                    .name("idx_external_links_provider_key")
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .table(ExternalLinks::Table)
                    .name("idx_external_links_task_provider_key")
                    .col(ExternalLinks::TaskId)
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
                    .name("idx_external_links_task_provider_key")
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
}

#[derive(Iden)]
enum ExternalLinks {
    Table,
    TaskId,
    Provider,
    ExternalKey,
}
