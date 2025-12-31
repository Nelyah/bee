// pub use sea_orm_migration::prelude::*;

pub use sea_orm_migration::prelude::sea_orm;
pub use sea_orm_migration::{MigrationTrait, MigratorTrait, async_trait};

mod m20250329_212639_create_task_schema;
mod m20251230_000001_create_external_links;
mod m20251230_000002_update_external_links_unique;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(m20250329_212639_create_task_schema::Migration),
            Box::new(m20251230_000001_create_external_links::Migration),
            Box::new(m20251230_000002_update_external_links_unique::Migration),
        ]
    }
}
