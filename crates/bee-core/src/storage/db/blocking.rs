//! Blocking status management for task dependencies.
//!
//! This module maintains the invariant that a task's status reflects its dependency state:
//! - A task is `BLOCKED` if it has at least one active (non-completed, non-deleted) dependency
//! - A task is `PENDING` (or returns to it) when all its dependencies are satisfied
//!
//! # When This Runs
//!
//! [`update_blocking_status`] is called after any mutation that could affect blocking:
//! - A task is marked done (may unblock dependents)
//! - A task is deleted (may unblock dependents)
//! - A new dependency link is created (may block the dependent)
//!
//! # Performance
//!
//! All status updates happen in a single UPDATE statement using a SQL CASE expression,
//! avoiding per-task updates.

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
struct StatusStrings {
    pub blocked: String,
    pub pending: String,
    pub active: String,
    pub completed: String,
    pub deleted: String,
}

impl StatusStrings {
    /// Construct a new cache of uppercase status strings.
    fn new() -> Self {
        Self {
            blocked: TaskStatus::Blocked.to_db_string(),
            pending: TaskStatus::Pending.to_db_string(),
            active: TaskStatus::Active.to_db_string(),
            completed: TaskStatus::Completed.to_db_string(),
            deleted: TaskStatus::Deleted.to_db_string(),
        }
    }

    /// Return the statuses that participate in dependency tracking queries.
    fn tracked_statuses(&self) -> Vec<String> {
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
async fn fetch_dependency_pairs(
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
fn determine_status_transitions(
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
fn build_status_case_expr(
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

/// Reconcile task statuses based on current dependency relationships.
///
/// # Algorithm
///
/// 1. **Fetch dependencies**: Load all (dependent_id, blocker_id) pairs where the
///    dependent is in a tracked status (PENDING, ACTIVE, BLOCKED)
///
/// 2. **Build sets**:
///    - `dependents`: All tasks that have at least one dependency
///    - `blockers_done`: Blocker tasks that are COMPLETED or DELETED
///    - `currently_blocked`: Tasks currently in BLOCKED status
///
/// 3. **Determine transitions**:
///    - **Unblock**: Tasks in `currently_blocked` where all blockers are in `blockers_done`
///    - **Block**: Tasks in `dependents` with at least one blocker NOT in `blockers_done`
///    - If a task appears in both sets, unblock wins (edge case resolution)
///
/// 4. **Execute update**: Build a single UPDATE with CASE expression
///
/// # Invariants
///
/// - Only tasks in PENDING, ACTIVE, or BLOCKED participate
/// - COMPLETED and DELETED tasks are considered "done" (they satisfy dependencies)
/// - A task can go BLOCKED → PENDING but never directly to ACTIVE
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

#[cfg(test)]
mod tests {
    use super::super::{
        connection::get_database, tables, task_read::load_tasks_impl, task_write::write_tasks_impl,
    };
    use super::*;
    use crate::{
        filters::{
            Filter,
            filters_impl::{StatusFilter, UuidFilter},
        },
        task::{Link, LinkType, Task, TaskStatus},
    };
    use all_asserts::assert_false;
    use chrono::{Duration, Local, TimeZone};
    use log::debug;
    use sea_orm::sea_query::Query;
    use sea_orm::{DatabaseConnection, DbErr, EntityTrait, QueryOrder, TransactionTrait};
    use sea_orm_migration::prelude::SqliteQueryBuilder;
    use std::collections::HashSet;
    use uuid::Uuid;

    /// Compare the filtered results against a single expected task.
    async fn assert_single_match(
        db: &sea_orm::DatabaseConnection,
        filter: Box<dyn Filter>,
        expected_task: &Task,
    ) {
        let results_data = load_tasks_impl(db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1, "expected a single matching task");
        let result = results[0];
        let mut expected_task_mut = expected_task.clone();
        expected_task_mut.db_id = result.db_id;
        if let Some(proj) = &mut expected_task_mut.project {
            proj.id = result.project.to_owned().unwrap().id;
        }
        for ann_idx in 0..expected_task_mut.annotations.len() {
            expected_task_mut.annotations[ann_idx].id = result.annotations[ann_idx].id;
        }
        for link_idx in 0..expected_task_mut.links.len() {
            expected_task_mut.links[link_idx].id = result.links[link_idx].id;
        }
        for history_idx in 0..expected_task_mut.history.len() {
            expected_task_mut.history[history_idx].id = result.history[history_idx].id;
        }

        expected_task_mut.id = result.id;
        assert_eq!(result, &expected_task_mut);
    }

    /// Initialize a test logger once for noisy DB tests.
    fn init_logger() {
        let _ = env_logger::builder()
            .is_test(true)
            .filter_module("sqlx", log::LevelFilter::Off)
            .try_init();
    }

    async fn refresh_task_state(db: &DatabaseConnection) -> Result<(), DbErr> {
        let txn = db.begin().await?;
        resequence_task_ids_txn(&txn).await?;
        update_blocking_status(&txn).await?;
        txn.commit().await?;
        Ok(())
    }

    #[test]
    fn test_determine_status_transitions_assigns_correct_sets() {
        let dependency_pairs = vec![(1, 2), (3, 4)];
        let currently_blocked: HashSet<i32> = HashSet::from([1, 5]);
        let dependents: HashSet<i32> = HashSet::from([1, 3]);
        let blockers_done: HashSet<i32> = HashSet::from([2]);

        let (to_block, to_unblock) = determine_status_transitions(
            &dependency_pairs,
            &currently_blocked,
            &dependents,
            &blockers_done,
        );

        let expected_block: HashSet<i32> = HashSet::from([3]);
        let expected_unblock: HashSet<i32> = HashSet::from([1, 5]);

        assert_eq!(to_block, expected_block);
        assert_eq!(to_unblock, expected_unblock);
    }

    #[test]
    fn test_build_status_case_expr_generates_case_when_targets_present() {
        let statuses = StatusStrings::new();
        let case_expr = build_status_case_expr(&[1, 2], &[3], &statuses);
        let sql = Query::select()
            .expr(case_expr)
            .from(tables::tasks::Entity)
            .to_string(SqliteQueryBuilder);

        assert!(sql.contains("CASE"));
        assert!(sql.contains(&statuses.blocked));
        assert!(sql.contains(&statuses.pending));
    }

    #[test]
    fn test_build_status_case_expr_falls_back_to_status_column() {
        let statuses = StatusStrings::new();
        let case_expr = build_status_case_expr(&[], &[], &statuses);
        let sql = Query::select()
            .expr(case_expr)
            .from(tables::tasks::Entity)
            .to_string(SqliteQueryBuilder);

        assert!(!sql.contains("CASE"));
        assert!(sql.contains("\"status\""));
    }

    #[tokio::test]
    async fn test_resequence_task_ids_orders_active_and_pending() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        let base = Local.with_ymd_and_hms(2024, 6, 1, 8, 0, 0).unwrap();

        let pending_early = Task {
            summary: "pending-early".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            date_created: base,
            ..Default::default()
        };
        write_tasks_impl(&db, &pending_early).await.unwrap();

        let active_late = Task {
            summary: "active-late".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            date_created: base + Duration::days(1),
            ..Default::default()
        };
        write_tasks_impl(&db, &active_late).await.unwrap();

        let completed_latest = Task {
            summary: "completed".to_string(),
            status: TaskStatus::Completed,
            uuid: Uuid::new_v4(),
            date_created: base + Duration::days(2),
            ..Default::default()
        };
        write_tasks_impl(&db, &completed_latest).await.unwrap();
        refresh_task_state(&db).await.unwrap();

        let rows = tables::tasks::Entity::find()
            .order_by_asc(tables::tasks::Column::DateCreated)
            .all(&db)
            .await
            .unwrap();
        assert_false!(rows.is_empty());
        debug!("{:?}", rows);

        let mut sequential = Vec::new();
        for row in &rows {
            match TaskStatus::from_string(row.status.as_str()).unwrap() {
                TaskStatus::Pending | TaskStatus::Active => sequential.push(row.id),
                TaskStatus::Completed => {
                    assert!(row.id.is_none(), "completed task should not have an id")
                }
                other => panic!("unexpected status {other}"),
            }
        }

        assert_eq!(sequential, vec![Some(1), Some(2)]);
    }

    #[tokio::test]
    async fn test_update_blocking_status_blocked_has_no_links() {
        init_logger();
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut blocked_task = Task {
            summary: "blocked-task".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };

        let mut blocking_task = Task {
            summary: "blocking-task".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };

        blocking_task.links.push(Link {
            from: blocking_task.uuid,
            to: blocked_task.uuid,
            link_type: LinkType::Blocking,
            id: None,
        });

        write_tasks_impl(&db, &blocked_task).await.unwrap();
        write_tasks_impl(&db, &blocking_task).await.unwrap();
        blocked_task.links.push(Link {
            from: blocked_task.uuid,
            to: blocking_task.uuid,
            link_type: LinkType::DependsOn,
            id: None,
        });
        write_tasks_impl(&db, &blocked_task).await.unwrap();
        refresh_task_state(&db).await.unwrap();

        let all_tasks = tables::tasks::Entity::find().all(&db).await.unwrap();
        assert_eq!(all_tasks.len(), 2);
        let statuses: Vec<_> = all_tasks.iter().map(|t| t.status.clone()).collect();
        assert!(statuses.contains(&TaskStatus::Active.to_db_string()));
        assert!(statuses.contains(&TaskStatus::Blocked.to_db_string()));

        blocked_task.status = TaskStatus::Blocked;
        assert_single_match(
            &db,
            Box::new(StatusFilter {
                status: TaskStatus::Blocked,
            }),
            &blocked_task,
        )
        .await;

        blocking_task.status = TaskStatus::Completed;
        write_tasks_impl(&db, &blocking_task).await.unwrap();
        refresh_task_state(&db).await.unwrap();
        let blocked_task_filter: Box<dyn Filter> = Box::new(UuidFilter {
            uuid: blocked_task.uuid.to_owned(),
        });
        let results_data = load_tasks_impl(&db, Some(blocked_task_filter.clone()), None)
            .await
            .unwrap();
        assert_eq!(results_data.to_vec()[0].uuid, blocked_task.uuid);
        assert_eq!(results_data.to_vec()[0].status, TaskStatus::Pending);
    }

    #[tokio::test]
    async fn test_delete_link_blocking() {
        init_logger();
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut blocked_task = Task {
            summary: "blocked-task".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };

        let mut blocking_task = Task {
            summary: "blocking-task".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };

        blocking_task.links.push(Link {
            from: blocking_task.uuid,
            to: blocked_task.uuid,
            link_type: LinkType::Blocking,
            id: None,
        });

        write_tasks_impl(&db, &blocked_task).await.unwrap();
        write_tasks_impl(&db, &blocking_task).await.unwrap();
        blocked_task.links.push(Link {
            from: blocked_task.uuid,
            to: blocking_task.uuid,
            link_type: LinkType::DependsOn,
            id: None,
        });
        blocked_task.db_id = Some(1);
        write_tasks_impl(&db, &blocked_task).await.unwrap();
        refresh_task_state(&db).await.unwrap();

        let all_links = tables::links::Entity::find().all(&db).await.unwrap();
        assert_eq!(all_links.len(), 1);

        let all_tasks = tables::tasks::Entity::find().all(&db).await.unwrap();
        assert_eq!(all_tasks.len(), 2);
        let statuses: Vec<_> = all_tasks.iter().map(|t| t.status.clone()).collect();
        assert!(statuses.contains(&TaskStatus::Active.to_db_string()));
        assert!(statuses.contains(&TaskStatus::Blocked.to_db_string()));

        let blocked_task_filter: Box<dyn Filter> = Box::new(UuidFilter {
            uuid: blocked_task.uuid.to_owned(),
        });
        blocked_task.status = TaskStatus::Blocked;

        blocked_task.links = [].to_vec();
        blocking_task.links = [].to_vec();
        write_tasks_impl(&db, &blocking_task).await.unwrap();
        write_tasks_impl(&db, &blocked_task).await.unwrap();
        refresh_task_state(&db).await.unwrap();
        let all_links = tables::links::Entity::find().all(&db).await.unwrap();
        assert_eq!(all_links.len(), 0);

        let results_data = load_tasks_impl(&db, Some(blocked_task_filter), None)
            .await
            .unwrap();
        assert_eq!(results_data.to_vec()[0].uuid, blocked_task.uuid);
        assert_eq!(results_data.to_vec()[0].status, TaskStatus::Pending);
    }
}
