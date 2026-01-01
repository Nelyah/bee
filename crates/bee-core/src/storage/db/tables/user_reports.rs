//! `SeaORM` Entity for user_reports table

use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Eq)]
#[sea_orm(table_name = "user_reports")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    #[sea_orm(unique)]
    pub name: String,
    pub filters: String,
    pub columns: String,
    pub column_names: String,
    /// JSON object storing custom column widths: {"column_key": width_in_pixels}
    pub column_widths: Option<String>,
    /// Column key to sort by (e.g., "status"). None means default urgency sort.
    pub sort_column: Option<String>,
    /// Sort direction: "ascending" or "descending"
    pub sort_direction: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}
