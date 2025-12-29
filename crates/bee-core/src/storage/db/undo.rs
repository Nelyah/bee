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

#[cfg(test)]
mod tests {
    use super::super::connection::get_database;
    use super::*;
    use crate::task::{ActionUndo, ActionUndoType, Task};
    use all_asserts::assert_true;

    /// Ensure undo actions are persisted and the most recent entry is fetched.
    #[tokio::test]
    async fn test_append_undo_action_persists_and_fetches_latest() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut first_task = Task::default();
        first_task.set_summary("First undo task");
        let first_undo = ActionUndo {
            action_type: ActionUndoType::Add,
            tasks: vec![first_task],
        };

        let mut second_task = Task::default();
        second_task.set_summary("Second undo task");
        let second_undo = ActionUndo {
            action_type: ActionUndoType::Modify,
            tasks: vec![second_task],
        };
        let expected_latest = second_undo.clone();

        append_undo_action_impl(&db, 1, vec![first_undo])
            .await
            .unwrap();
        append_undo_action_impl(&db, 1, vec![second_undo.to_owned()])
            .await
            .unwrap();

        let recent = load_undos_impl(&db, 1).await.unwrap();
        assert_eq!(recent.len(), 1, "Expected a single undo action returned");
        let latest = &recent[0];

        assert_eq!(latest.action_type, expected_latest.action_type);
        assert_eq!(latest.tasks, expected_latest.tasks);

        let mut third_task = Task::default();
        third_task.set_summary("Third undo task");
        let third_undo = ActionUndo {
            action_type: ActionUndoType::Modify,
            tasks: vec![third_task],
        };

        append_undo_action_impl(&db, 2, vec![third_undo.to_owned()])
            .await
            .unwrap();
        let undos = load_undos_impl(&db, 10).await.unwrap();
        assert_eq!(undos.len(), 1);
        assert_eq!(undos[0], third_undo);

        append_undo_action_impl(&db, 0, vec![second_undo.to_owned()])
            .await
            .unwrap();
        let undos = load_undos_impl(&db, 2).await.unwrap();
        assert_eq!(undos.len(), 2);
        assert_eq!(undos[0], third_undo);
        assert_eq!(undos[1], second_undo);

        append_undo_action_impl(&db, 1, vec![second_undo.to_owned()])
            .await
            .unwrap();
        let undos = load_undos_impl(&db, 2).await.unwrap();
        assert_eq!(undos.len(), 2);
        assert_eq!(undos[0], third_undo);
        assert_eq!(undos[1], second_undo);

        append_undo_action_impl(&db, 100, vec![]).await.unwrap();
        let undos = load_undos_impl(&db, 100).await.unwrap();
        assert_true!(undos.is_empty());
    }
}
