use super::tables;
use crate::task::{ActionUndo, ActionUndoType};
use tables::undo_actions;

use chrono::Local;
use std::str::FromStr;

use sea_orm::{
    ActiveValue::Set, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter, QueryOrder,
    QuerySelect,
};

pub(super) async fn append_undo_action_impl(
    db: &DatabaseConnection,
    count: usize,
    undos: Vec<ActionUndo>,
) -> Result<(), Box<dyn std::error::Error>> {
    let count_u64: u64 = count.try_into().unwrap();
    let last_undos_ids: Vec<i32> = undo_actions::Entity::find()
        .order_by_desc(undo_actions::Column::CreatedAt)
        .limit(count_u64)
        .all(db)
        .await?
        .into_iter()
        .map(|model| model.id)
        .collect();
    if !last_undos_ids.is_empty() {
        undo_actions::Entity::delete_many()
            .filter(undo_actions::Column::Id.is_in(last_undos_ids))
            .exec(db)
            .await?;
    }

    // TODO: Need to not rewrite the created_at if some undos were already present in the DB
    // Although this is not too bad since the created_at only exists inside the DB and this is
    // the only place we're using it.
    let undo_to_model =
        |u: ActionUndo| -> Result<undo_actions::ActiveModel, Box<dyn std::error::Error>> {
            let payload = serde_json::to_string(&u)?;
            Ok(undo_actions::ActiveModel {
                action_type: Set(u.action_type.to_string()),
                payload: Set(payload),
                created_at: Set(Local::now().to_rfc3339()),
                ..Default::default()
            })
        };

    let mut undo_active_models = Vec::new();
    for undo in undos {
        undo_active_models.push(undo_to_model(undo)?);
    }

    if undo_active_models.is_empty() {
        return Ok(());
    }

    undo_actions::Entity::insert_many(undo_active_models)
        .exec(db)
        .await?;
    Ok(())
}

pub(super) async fn load_undos_impl(
    db: &DatabaseConnection,
    limit: usize,
) -> Result<Vec<ActionUndo>, Box<dyn std::error::Error>> {
    if limit == 0 {
        return Ok(Vec::new());
    }

    let mut records = undo_actions::Entity::find()
        .order_by_desc(undo_actions::Column::CreatedAt)
        .order_by_desc(undo_actions::Column::Id)
        .limit(limit as u64)
        .all(db)
        .await?;

    records.reverse();

    let mut undos: Vec<ActionUndo> = Vec::with_capacity(records.len());
    for record in records {
        let mut undo: ActionUndo = serde_json::from_str(&record.payload)?;
        undo.action_type = ActionUndoType::from_str(&record.action_type)?;
        undos.push(undo);
    }
    Ok(undos)
}
