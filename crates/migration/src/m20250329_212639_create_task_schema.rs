use sea_orm_migration::prelude::*;
use sea_query::Expr;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    // Up migration: create all tables and the unique index.
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 1. Create the projects table.
        manager
            .create_table(
                Table::create()
                    .table(Projects::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Projects::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(
                        ColumnDef::new(Projects::Name)
                            .string()
                            .not_null()
                            .unique_key(),
                    )
                    .to_owned(),
            )
            .await?;

        // 2. Create the tasks table.
        // "db_id" is the primary key and "id" is the business identifier.
        manager
            .create_table(
                Table::create()
                    .table(Tasks::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Tasks::DbId)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(
                        ColumnDef::new(Tasks::Id).unsigned().unique_key(), // Ensure this business id is unique.
                    )
                    .col(
                        ColumnDef::new(Tasks::Status)
                            .string()
                            .not_null()
                            .check(Expr::cust(
                                "status IN ('PENDING','COMPLETED','ACTIVE','DELETED','BLOCKED')",
                            )),
                    )
                    .col(ColumnDef::new(Tasks::Uuid).string().not_null())
                    .col(ColumnDef::new(Tasks::Summary).string().not_null())
                    .col(ColumnDef::new(Tasks::DateCreated).string().not_null())
                    .col(ColumnDef::new(Tasks::DateCompleted).string().null())
                    .col(ColumnDef::new(Tasks::DateDue).string().null())
                    .col(ColumnDef::new(Tasks::Urgency).double().null())
                    .col(ColumnDef::new(Tasks::ProjectId).unsigned().null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_tasks_project")
                            .from(Tasks::Table, Tasks::ProjectId)
                            .to(Projects::Table, Projects::Id),
                    )
                    .to_owned(),
            )
            .await?;

        // 3. Create the history table, referencing tasks(id).
        manager
            .create_table(
                Table::create()
                    .table(History::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(History::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(ColumnDef::new(History::Value).string().not_null())
                    .col(ColumnDef::new(History::Datetime).string().not_null())
                    .col(ColumnDef::new(History::TaskId).unsigned().not_null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_history_task")
                            .from(History::Table, History::TaskId)
                            // Reference the business id from tasks.
                            .to(Tasks::Table, Tasks::DbId)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 4. Create the annotations table, referencing tasks(id).
        manager
            .create_table(
                Table::create()
                    .table(Annotations::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Annotations::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(ColumnDef::new(Annotations::Value).string().not_null())
                    .col(ColumnDef::new(Annotations::Datetime).string().not_null())
                    .col(ColumnDef::new(Annotations::TaskId).unsigned().not_null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_annotations_task")
                            .from(Annotations::Table, Annotations::TaskId)
                            .to(Tasks::Table, Tasks::DbId)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 5. Create the links table, referencing tasks(id) for both columns.
        manager
            .create_table(
                Table::create()
                    .table(Links::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Links::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(ColumnDef::new(Links::FromTaskId).unsigned().not_null())
                    .col(ColumnDef::new(Links::ToTaskId).unsigned().not_null())
                    .col(ColumnDef::new(Links::Type).string().not_null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_links_from_task")
                            .from(Links::Table, Links::FromTaskId)
                            .to(Tasks::Table, Tasks::DbId)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_links_to_task")
                            .from(Links::Table, Links::ToTaskId)
                            .to(Tasks::Table, Tasks::DbId)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(Tags::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Tags::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(ColumnDef::new(Tags::Name).string().not_null().unique_key())
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(TasksTags::Table)
                    .if_not_exists()
                    .col(ColumnDef::new(TasksTags::TagId).unsigned().not_null())
                    .col(ColumnDef::new(TasksTags::TaskId).unsigned().not_null())
                    .primary_key(Index::create().col(TasksTags::TagId).col(TasksTags::TaskId))
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_task_tags_task")
                            .from(TasksTags::Table, TasksTags::TaskId)
                            .to(Tasks::Table, Tasks::DbId)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_task_tags_tags")
                            .from(TasksTags::Table, TasksTags::TagId)
                            .to(Tags::Table, Tags::Id)
                            .on_delete(ForeignKeyAction::Cascade)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(UndoActions::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(UndoActions::Id)
                            .unsigned()
                            .not_null()
                            .primary_key()
                            .auto_increment(),
                    )
                    .col(ColumnDef::new(UndoActions::ActionType).string().not_null())
                    .col(ColumnDef::new(UndoActions::Payload).text().not_null())
                    .col(
                        ColumnDef::new(UndoActions::CreatedAt)
                            .string()
                            .not_null()
                            .default(Expr::cust("CURRENT_TIMESTAMP")),
                    )
                    .to_owned(),
            )
            .await?;

        // 6. Create a unique index on the links table.
        manager
            .create_index(
                Index::create()
                    .table(Links::Table)
                    .name("idx_unique_link")
                    .col(Links::FromTaskId)
                    .col(Links::ToTaskId)
                    .col(Links::Type)
                    .unique()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    // Down migration: drop index and tables in reverse order.
    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .table(Links::Table)
                    .name("idx_unique_link")
                    .to_owned(),
            )
            .await?;
        manager
            .drop_table(Table::drop().table(Links::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Annotations::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(History::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Tasks::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Projects::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(UndoActions::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Tags::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(TasksTags::Table).to_owned())
            .await?;
        Ok(())
    }
}

// Table and column identifiers

#[derive(Iden)]
enum Projects {
    Table,
    Id,
    Name,
}

#[derive(Iden)]
enum Tags {
    Table,
    Id,
    Name,
}

#[derive(Iden)]
enum Tasks {
    Table,
    DbId, // Internal primary key.
    Id,   // Business identifier, referenced by other tables.
    Status,
    Uuid,
    Summary,
    DateCreated,
    DateCompleted,
    DateDue,
    Urgency,
    ProjectId,
}

#[derive(Iden)]
enum TasksTags {
    Table,
    TagId,
    TaskId,
}

#[derive(Iden)]
enum UndoActions {
    Table,
    Id,
    ActionType,
    Payload,
    CreatedAt,
}

#[derive(Iden)]
enum History {
    Table,
    Id,
    Value,
    Datetime,
    TaskId, // References Tasks::Id.
}

#[derive(Iden)]
enum Annotations {
    Table,
    Id,
    Value,
    Datetime,
    TaskId, // References Tasks::Id.
}

#[derive(Iden)]
enum Links {
    Table,
    Id,
    FromTaskId, // References Tasks::DbId.
    ToTaskId,   // References Tasks::DbId.
    Type,
}
