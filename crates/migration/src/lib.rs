// pub use sea_orm_migration::prelude::*;

pub use sea_orm_migration::prelude::sea_orm;
pub use sea_orm_migration::{async_trait, MigrationTrait, MigratorTrait};

mod m20250329_212639_create_task_schema;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![Box::new(m20250329_212639_create_task_schema::Migration)]
    }
}
