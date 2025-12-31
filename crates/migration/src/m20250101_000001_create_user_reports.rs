use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(UserReports::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(UserReports::Id)
                            .integer()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(
                        ColumnDef::new(UserReports::Name)
                            .string()
                            .not_null()
                            .unique_key(),
                    )
                    .col(ColumnDef::new(UserReports::Filters).text().not_null())
                    .col(ColumnDef::new(UserReports::Columns).text().not_null())
                    .col(ColumnDef::new(UserReports::ColumnNames).text().not_null())
                    .col(ColumnDef::new(UserReports::CreatedAt).string().not_null())
                    .col(ColumnDef::new(UserReports::UpdatedAt).string().not_null())
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .table(UserReports::Table)
                    .name("idx_user_reports_name")
                    .col(UserReports::Name)
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
                    .table(UserReports::Table)
                    .name("idx_user_reports_name")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_table(Table::drop().table(UserReports::Table).to_owned())
            .await?;
        Ok(())
    }
}

#[derive(Iden)]
enum UserReports {
    Table,
    Id,
    Name,
    Filters,
    Columns,
    ColumnNames,
    CreatedAt,
    UpdatedAt,
}
