use super::tables;
use crate::task::{LinkType, TaskStatus};
use tables::{links, tasks};

use log::debug;
use std::collections::HashSet;

use sea_orm::{
    ColumnTrait, Condition, DatabaseTransaction, DbErr, EntityTrait, JoinType, QueryFilter,
    QuerySelect, RelationTrait, prelude::Expr, sea_query::SimpleExpr,
};

/// Pre-computed uppercase string representations of task statuses used by
/// `update_blocking_status`.
pub(super) struct StatusStrings {
    pub blocked: String,
    pub pending: String,
    pub active: String,
    pub completed: String,
    pub deleted: String,
}

impl StatusStrings {
    /// Construct a new cache of uppercase status strings.
    pub fn new() -> Self {
        Self {
            blocked: TaskStatus::Blocked.to_db_string(),
            pending: TaskStatus::Pending.to_db_string(),
            active: TaskStatus::Active.to_db_string(),
            completed: TaskStatus::Completed.to_db_string(),
            deleted: TaskStatus::Deleted.to_db_string(),
        }
    }

    /// Return the statuses that participate in dependency tracking queries.
    pub fn tracked_statuses(&self) -> Vec<String> {
        vec![
            self.pending.clone(),
            self.active.clone(),
            self.blocked.clone(),
        ]
    }
}

/// Fetch the `(dependent, dependency)` pairs for active `DependsOn` links.
///
/// We join through `links::Relation::Tasks1` so that we can filter dependents by their current
/// status.
pub(super) async fn fetch_dependency_pairs(
    db: &DatabaseTransaction,
    tracked_statuses: &[String],
) -> Result<Vec<(i32, i32)>, DbErr> {
    let statuses: Vec<String> = tracked_statuses.to_vec();
    links::Entity::find()
        .select_only()
        .column(links::Column::FromTaskId)
        .column(links::Column::ToTaskId)
        .distinct()
        .join(JoinType::InnerJoin, links::Relation::Tasks1.def())
        .filter(links::Column::Type.eq(LinkType::DependsOn.to_string()))
        .filter(Expr::col((tasks::Entity, tasks::Column::Status)).is_in(statuses))
        .into_tuple::<(i32, i32)>()
        .all(db)
        .await
}

/// Determine which tasks should transition between blocked and pending states
/// based on dependency information.
pub(super) fn determine_status_transitions(
    dependency_pairs: &[(i32, i32)],
    currently_blocked: &HashSet<i32>,
    dependents: &HashSet<i32>,
    blockers_done: &HashSet<i32>,
) -> (HashSet<i32>, HashSet<i32>) {
    let mut to_unblock: HashSet<i32> = currently_blocked.difference(dependents).copied().collect();
    let mut to_block: HashSet<i32> = HashSet::new();

    for (dependent, blocker) in dependency_pairs {
        if blockers_done.contains(blocker) {
            to_unblock.insert(*dependent);
        } else {
            to_block.insert(*dependent);
        }
    }

    to_unblock.retain(|id| !to_block.contains(id));

    (to_block, to_unblock)
}

/// Build the CASE expression used to update task statuses. Returns the existing
/// status column if no transitions are detected.
pub(super) fn build_status_case_expr(
    to_block: &[i32],
    to_unblock: &[i32],
    statuses: &StatusStrings,
) -> SimpleExpr {
    let mut cases = Vec::new();

    if !to_block.is_empty() {
        cases.push((
            Expr::col(tasks::Column::DbId).is_in(to_block.to_vec()),
            Expr::value(statuses.blocked.clone()),
        ));
    }

    if !to_unblock.is_empty() {
        cases.push((
            Expr::col(tasks::Column::DbId).is_in(to_unblock.to_vec()),
            Expr::value(statuses.pending.clone()),
        ));
    }
    match cases.len() {
        0 => Expr::col(tasks::Column::Status).into(),
        1 => Expr::case(cases[0].0.clone(), cases[0].1.clone())
            .finally(Expr::col(tasks::Column::Status))
            .into(),
        _ => {
            let mut case = Expr::case(cases[0].0.clone(), cases[0].1.clone());
            for (cond, then) in cases.iter().skip(1) {
                case = case.case(cond.clone(), then.clone());
            }
            case.finally(Expr::col(tasks::Column::Status)).into()
        }
    }
}

/// Reconcile task statuses with their dependency relationships.
///
/// Invariants enforced:
/// - Only `PENDING`, `ACTIVE`, and `BLOCKED` tasks participate because completed/deleted entries
///   no longer have user-visible IDs.
/// - When a task loses every unfinished dependency, it returns to `PENDING`.
/// - Dependencies in `COMPLETED` or `DELETED` states are treated as satisfied blockers.
pub(super) async fn update_blocking_status(db: &DatabaseTransaction) -> Result<(), DbErr> {
    debug!("Enter update_blocking_status");
    let statuses = StatusStrings::new();
    let dependency_pairs = fetch_dependency_pairs(db, &statuses.tracked_statuses()).await?;
    let dependents: HashSet<i32> = dependency_pairs
        .iter()
        .map(|(dependent, _)| *dependent)
        .collect();
    let blockers: HashSet<i32> = dependency_pairs
        .iter()
        .map(|(_, blocker)| *blocker)
        .collect();
    let currently_blocked: HashSet<i32> = tasks::Entity::find()
        .select_only()
        .column(tasks::Column::DbId)
        .filter(tasks::Column::Status.eq(&statuses.blocked))
        .into_tuple::<i32>()
        .all(db)
        .await?
        .into_iter()
        .collect();
    let blockers_to_check: Vec<i32> = blockers.iter().copied().collect();
    let blocking_done: HashSet<i32> = if blockers_to_check.is_empty() {
        HashSet::new()
    } else {
        tasks::Entity::find()
            .select_only()
            .column(tasks::Column::DbId)
            .filter(tasks::Column::DbId.is_in(blockers_to_check))
            .filter(
                Condition::any()
                    .add(tasks::Column::Status.eq(&statuses.completed))
                    .add(tasks::Column::Status.eq(&statuses.deleted)),
            )
            .into_tuple::<i32>()
            .all(db)
            .await?
            .into_iter()
            .collect()
    };

    let (to_block, to_unblock) = determine_status_transitions(
        &dependency_pairs,
        &currently_blocked,
        &dependents,
        &blocking_done,
    );

    let targets: HashSet<i32> = to_block.union(&to_unblock).copied().collect();

    if targets.is_empty() {
        return Ok(());
    }

    let to_block_vec: Vec<i32> = to_block.iter().copied().collect();
    let to_unblock_vec: Vec<i32> = to_unblock.iter().copied().collect();
    let targets_vec: Vec<i32> = targets.iter().copied().collect();

    let case_expr = build_status_case_expr(&to_block_vec, &to_unblock_vec, &statuses);

    tables::tasks::Entity::update_many()
        .col_expr(tasks::Column::Status, case_expr)
        .filter(tasks::Column::DbId.is_in(targets_vec))
        .exec(db)
        .await?;

    Ok(())
}

/// Execute the task ID resequencing logic within an existing transaction.
///
/// The transaction should already encompass any writes that require the IDs to be rebalanced.
pub(super) async fn resequence_task_ids_txn(db: &DatabaseTransaction) -> Result<(), DbErr> {
    use sea_orm::{ConnectionTrait, DatabaseBackend, Statement};

    let clear_inactive_ids = Statement::from_string(
        DatabaseBackend::Sqlite,
        "UPDATE tasks SET id = NULL WHERE status IN ('COMPLETED','DELETED')",
    );

    db.execute(clear_inactive_ids).await?;

    let resequence_ids = Statement::from_string(
        DatabaseBackend::Sqlite,
        r#"WITH ranked AS (
             SELECT db_id, ROW_NUMBER() OVER (ORDER BY date_created) AS new_id
             FROM tasks
             WHERE status IN ('PENDING','ACTIVE', 'BLOCKED')
         )
         UPDATE tasks
         SET id = (SELECT new_id FROM ranked WHERE ranked.db_id = tasks.db_id)
         WHERE db_id IN (SELECT db_id FROM ranked)"#,
    );

    db.execute(resequence_ids).await?;

    Ok(())
}
