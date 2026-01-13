//! Task loading and hydration from the database.
//!
//! This module handles loading tasks with all their related data (projects, tags,
//! annotations, history, dependencies). The key optimization is batched hydration—
//! all related data is loaded in a fixed number of queries regardless of task count,
//! avoiding the N+1 query problem.
//!
//! # Key Functions
//!
//! - [`load_tasks_impl`]: Main entry point for loading tasks with optional filtering
//! - [`task_models_to_objects`]: Hydrates database models into domain Task objects
//!
//! # Performance
//!
//! Loading 100 tasks requires ~7 queries (not 700+). This is achieved by:
//! 1. Collecting all task IDs upfront
//! 2. Batch-loading each relationship type with `WHERE task_id IN (...)`
//! 3. Building in-memory HashMaps for O(1) lookup during construction

use super::filter_sql::{condition_expression_to_condition, filter_to_condition_expr};
use super::tables;
use crate::{
    CoreError, CoreResult,
    email_link::EmailLink,
    filters::{
        self, Filter,
        filters_impl::{OrFilter, TaskIdFilter, UuidFilter},
    },
    important_link::ImportantLink,
    task::{
        DependsOnIdentifier, Link, LinkType, Project, Task, TaskAnnotation, TaskData, TaskHistory,
        TaskProperties, TaskStatus,
    },
};
use tables::{
    annotations, email_links, history, important_links, links, projects, tags, tasks, tasks_tags,
};

use chrono::{DateTime, Local};
use std::collections::{HashMap, HashSet};
use uuid::Uuid;

use sea_orm::{
    ColumnTrait, ConnectionTrait, DatabaseConnection, DbBackend, EntityTrait, FromQueryResult,
    QueryFilter, QueryOrder, Statement,
};

/// A completion item with value and count.
#[derive(Debug, Clone, FromQueryResult)]
pub struct CompletionRow {
    pub value: String,
    pub count: i64,
}

/// Get all unique projects with task counts, sorted by count descending.
pub async fn get_projects_with_counts(db: &DatabaseConnection) -> CoreResult<Vec<CompletionRow>> {
    let results = CompletionRow::find_by_statement(Statement::from_sql_and_values(
        DbBackend::Sqlite,
        r#"
            SELECT p.name as value, COUNT(t.db_id) as count
            FROM projects p
            LEFT JOIN tasks t ON t.project_id = p.id
            GROUP BY p.id, p.name
            ORDER BY count DESC, p.name ASC
        "#,
        [],
    ))
    .all(db)
    .await?;
    Ok(results)
}

/// Get all unique tags with task counts, sorted by count descending.
pub async fn get_tags_with_counts(db: &DatabaseConnection) -> CoreResult<Vec<CompletionRow>> {
    let results = CompletionRow::find_by_statement(Statement::from_sql_and_values(
        DbBackend::Sqlite,
        r#"
            SELECT tg.name as value, COUNT(tt.task_id) as count
            FROM tags tg
            LEFT JOIN tasks_tags tt ON tt.tag_id = tg.id
            GROUP BY tg.id, tg.name
            ORDER BY count DESC, tg.name ASC
        "#,
        [],
    ))
    .all(db)
    .await?;
    Ok(results)
}

// ============================================================================
// Project Overview Queries
// ============================================================================

/// A row representing project statistics with status breakdown.
#[derive(Debug, Clone, FromQueryResult)]
pub struct ProjectStatusRow {
    /// Project name (full path with dots).
    pub project_name: String,
    /// Number of pending tasks.
    pub pending_count: i64,
    /// Number of active tasks.
    pub active_count: i64,
    /// Number of completed tasks.
    pub completed_count: i64,
    /// Number of overdue tasks (pending/active with past due date).
    pub overdue_count: i64,
    /// Total task count.
    pub total_count: i64,
    /// Optional emoji for visual identification.
    pub emoji: Option<String>,
    /// Optional hex color for project theming.
    pub color: Option<String>,
}

/// Get all projects with status breakdown counts.
///
/// Returns a flat list of projects with counts by status. The caller is
/// responsible for building the hierarchy from the project names.
pub async fn get_projects_with_status_breakdown(
    db: &DatabaseConnection,
) -> CoreResult<Vec<ProjectStatusRow>> {
    let results = ProjectStatusRow::find_by_statement(Statement::from_sql_and_values(
        DbBackend::Sqlite,
        r#"
            SELECT
                p.name as project_name,
                SUM(CASE WHEN t.status = 'pending' THEN 1 ELSE 0 END) as pending_count,
                SUM(CASE WHEN t.status = 'active' THEN 1 ELSE 0 END) as active_count,
                SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) as completed_count,
                SUM(CASE
                    WHEN t.status IN ('pending', 'active')
                         AND t.date_due IS NOT NULL
                         AND datetime(t.date_due) < datetime('now')
                    THEN 1 ELSE 0
                END) as overdue_count,
                COUNT(t.db_id) as total_count,
                p.emoji as emoji,
                p.color as color
            FROM projects p
            LEFT JOIN tasks t ON t.project_id = p.id
            GROUP BY p.id, p.name
            ORDER BY total_count DESC, p.name ASC
        "#,
        [],
    ))
    .all(db)
    .await?;
    Ok(results)
}

/// A row representing a single day's burndown data.
#[derive(Debug, Clone, FromQueryResult)]
pub struct BurndownRow {
    /// Date in YYYY-MM-DD format.
    pub date: String,
    /// Number of tasks completed on this day.
    pub completed_on_day: i64,
}

/// Get burndown data for a specific project (and its subprojects).
///
/// Returns daily completion counts over the past `days` days.
/// Uses prefix matching so "backend" includes "backend.api", "backend.db", etc.
pub async fn get_project_burndown(
    db: &DatabaseConnection,
    project_name: &str,
    days: u32,
) -> CoreResult<Vec<BurndownRow>> {
    // Escape special characters in the project name for LIKE pattern
    let escaped_name = project_name.replace('%', "\\%").replace('_', "\\_");
    // Match exact project OR subprojects (project.*)
    let like_pattern = format!("{}%", escaped_name);

    let results = BurndownRow::find_by_statement(Statement::from_sql_and_values(
        DbBackend::Sqlite,
        r#"
            SELECT
                date(t.date_completed) as date,
                COUNT(*) as completed_on_day
            FROM tasks t
            JOIN projects p ON t.project_id = p.id
            WHERE p.name LIKE ?
                AND t.date_completed IS NOT NULL
                AND date(t.date_completed) >= date('now', '-' || ? || ' days')
            GROUP BY date(t.date_completed)
            ORDER BY date ASC
        "#,
        [like_pattern.into(), days.into()],
    ))
    .all(db)
    .await?;
    Ok(results)
}

/// Get total task counts for a project (for burndown chart baseline).
///
/// Returns (total_tasks, total_completed) for the project and its subprojects.
pub async fn get_project_task_totals(
    db: &DatabaseConnection,
    project_name: &str,
) -> CoreResult<(i64, i64)> {
    #[derive(Debug, FromQueryResult)]
    struct TotalRow {
        total: i64,
        completed: i64,
    }

    let escaped_name = project_name.replace('%', "\\%").replace('_', "\\_");
    let like_pattern = format!("{}%", escaped_name);

    let result = TotalRow::find_by_statement(Statement::from_sql_and_values(
        DbBackend::Sqlite,
        r#"
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) as completed
            FROM tasks t
            JOIN projects p ON t.project_id = p.id
            WHERE p.name LIKE ?
        "#,
        [like_pattern.into()],
    ))
    .one(db)
    .await?
    .unwrap_or(TotalRow {
        total: 0,
        completed: 0,
    });

    Ok((result.total, result.completed))
}

pub(super) async fn load_tasks_impl(
    db: &DatabaseConnection,
    filter_opt: Option<Box<dyn Filter>>,
    props: Option<TaskProperties>,
) -> CoreResult<TaskData> {
    let filter = filter_opt.unwrap_or_else(filters::new_empty);
    let tasks_obj = tasks_from_filter(db, filter.as_ref()).await?;

    let mut task_data = TaskData::default();
    for t in tasks_obj {
        task_data.add_task_object(t);
    }
    if let Some(props) = props {
        let mut extra_task_filter = OrFilter::default();

        for task_identifier in props.get_referenced_tasks() {
            match task_identifier {
                DependsOnIdentifier::Uuid(uuid) => {
                    extra_task_filter
                        .children
                        .push(Box::new(UuidFilter { uuid }));
                }
                DependsOnIdentifier::Id(id) => {
                    extra_task_filter
                        .children
                        .push(Box::new(TaskIdFilter { id }));
                }
            }
        }
        let f: Box<dyn Filter> = Box::new(extra_task_filter);
        let extra_tasks_obj = tasks_from_filter(db, f.as_ref()).await?;
        for t in extra_tasks_obj {
            task_data.insert_extra_task(t);
        }
    }

    Ok(task_data)
}

async fn tasks_from_filter(db: &DatabaseConnection, filter: &dyn Filter) -> CoreResult<Vec<Task>> {
    let models = tables::tasks::Entity::find()
        .filter(condition_expression_to_condition(filter_to_condition_expr(
            filter,
        )))
        .all(db)
        .await?;
    task_models_to_objects(db, models).await
}

fn parse_datetime(value: &str) -> CoreResult<DateTime<Local>> {
    DateTime::parse_from_rfc3339(value)
        .map(|dt| dt.with_timezone(&Local))
        .map_err(CoreError::from)
}

/// Hydrate task database models into fully-populated Task domain objects.
///
/// This function solves the N+1 query problem by batching all relationship lookups.
/// Instead of loading relationships per-task (which would be O(n) queries), it loads
/// all relationships for all tasks in a fixed number of queries.
///
/// # Query Phases
///
/// 1. **Projects**: Single query for all referenced project IDs → `HashMap<project_id, Project>`
/// 2. **Tags**: Query task_tag links, then tag names → `HashMap<task_id, Vec<Tag>>`
/// 3. **Annotations**: Single query ordered by datetime → `HashMap<task_id, Vec<Annotation>>`
/// 4. **History**: Single query ordered by datetime → `HashMap<task_id, Vec<HistoryEntry>>`
/// 5. **Links (outgoing)**: DependsOn relationships from these tasks
/// 6. **Links (incoming)**: Tasks that depend on these tasks (for Blocking display)
/// 7. **Missing UUIDs**: Any task IDs referenced in links but not in the input set
///
/// # Construction
///
/// After all data is cached in HashMaps, a single pass constructs Task objects
/// by looking up each relationship from the appropriate map.
async fn task_models_to_objects<C>(db: &C, models: Vec<tasks::Model>) -> CoreResult<Vec<Task>>
where
    C: ConnectionTrait,
{
    if models.is_empty() {
        return Ok(Vec::new());
    }

    let task_ids: Vec<i32> = models.iter().map(|model| model.db_id).collect();

    let mut uuid_map: HashMap<i32, Uuid> = HashMap::new();
    for model in &models {
        uuid_map.insert(model.db_id, Uuid::parse_str(&model.uuid)?);
    }

    let project_ids: Vec<i32> = models.iter().filter_map(|model| model.project_id).collect();
    let projects_map: HashMap<i32, Project> = if project_ids.is_empty() {
        HashMap::new()
    } else {
        projects::Entity::find()
            .filter(projects::Column::Id.is_in(project_ids))
            .all(db)
            .await?
            .into_iter()
            .map(|model| {
                (
                    model.id,
                    Project {
                        id: Some(model.id),
                        name: model.name,
                        emoji: model.emoji,
                        color: model.color,
                    },
                )
            })
            .collect()
    };

    let tag_links = tasks_tags::Entity::find()
        .filter(tasks_tags::Column::TaskId.is_in(task_ids.clone()))
        .all(db)
        .await?;
    let tag_ids: Vec<i32> = tag_links.iter().map(|link| link.tag_id).collect();
    let tag_name_map: HashMap<i32, String> = if tag_ids.is_empty() {
        HashMap::new()
    } else {
        tags::Entity::find()
            .filter(tags::Column::Id.is_in(tag_ids))
            .all(db)
            .await?
            .into_iter()
            .map(|model| (model.id, model.name))
            .collect()
    };
    let mut tags_by_task: HashMap<i32, Vec<String>> = HashMap::new();
    for link in tag_links {
        if let Some(name) = tag_name_map.get(&link.tag_id) {
            tags_by_task
                .entry(link.task_id)
                .or_default()
                .push(name.to_owned());
        }
    }
    for tags in tags_by_task.values_mut() {
        tags.sort();
    }

    let annotation_models = annotations::Entity::find()
        .filter(annotations::Column::TaskId.is_in(task_ids.clone()))
        .order_by_asc(annotations::Column::Datetime)
        .all(db)
        .await?;
    let mut annotations_by_task: HashMap<i32, Vec<TaskAnnotation>> = HashMap::new();
    for model in annotation_models {
        annotations_by_task
            .entry(model.task_id)
            .or_default()
            .push(TaskAnnotation {
                id: Some(model.id),
                value: model.value,
                time: parse_datetime(&model.datetime)?,
            });
    }

    let history_models = history::Entity::find()
        .filter(history::Column::TaskId.is_in(task_ids.clone()))
        .order_by_asc(history::Column::Datetime)
        .all(db)
        .await?;
    let mut history_by_task: HashMap<i32, Vec<TaskHistory>> = HashMap::new();
    for model in history_models {
        history_by_task
            .entry(model.task_id)
            .or_default()
            .push(TaskHistory {
                id: Some(model.id),
                value: model.value,
                datetime: parse_datetime(&model.datetime)?,
            });
    }

    // Load email links
    let email_link_models = email_links::Entity::find()
        .filter(email_links::Column::TaskId.is_in(task_ids.clone()))
        .order_by_asc(email_links::Column::CreatedAt)
        .all(db)
        .await?;
    let mut email_links_by_task: HashMap<i32, Vec<EmailLink>> = HashMap::new();
    for model in email_link_models {
        let sent_date = model
            .sent_date
            .as_ref()
            .and_then(|s| parse_datetime(s).ok());
        let created_at = parse_datetime(&model.created_at)?;
        let uuid = Uuid::parse_str(&model.uuid)?;

        email_links_by_task
            .entry(model.task_id)
            .or_default()
            .push(EmailLink {
                id: Some(model.id),
                uuid,
                message_id: model.message_id,
                subject: model.subject,
                sender: model.sender,
                sent_date,
                created_at,
            });
    }

    // Load important links
    let important_link_models = important_links::Entity::find()
        .filter(important_links::Column::TaskId.is_in(task_ids.clone()))
        .order_by_asc(important_links::Column::CreatedAt)
        .all(db)
        .await?;
    let mut important_links_by_task: HashMap<i32, Vec<ImportantLink>> = HashMap::new();
    for model in important_link_models {
        let created_at = parse_datetime(&model.created_at)?;
        let uuid = Uuid::parse_str(&model.uuid)?;

        important_links_by_task
            .entry(model.task_id)
            .or_default()
            .push(ImportantLink {
                id: Some(model.id),
                uuid,
                url: model.url,
                title: model.title,
                created_at,
            });
    }

    // === Load all outgoing canonical links ===
    // Canonical types: DependsOn, ParentOf, RelatedTo, Duplicates
    let outgoing_links = links::Entity::find()
        .filter(links::Column::FromTaskId.is_in(task_ids.clone()))
        .all(db)
        .await?;

    // === Load incoming links for constructing inverse/symmetric views ===
    let incoming_links = links::Entity::find()
        .filter(links::Column::ToTaskId.is_in(task_ids.clone()))
        .all(db)
        .await?;

    let mut referenced_ids: HashSet<i32> = HashSet::new();
    referenced_ids.extend(outgoing_links.iter().map(|link| link.to_task_id));
    referenced_ids.extend(incoming_links.iter().map(|link| link.from_task_id));

    let missing_ids: Vec<i32> = referenced_ids
        .into_iter()
        .filter(|id| !uuid_map.contains_key(id))
        .collect();
    if !missing_ids.is_empty() {
        let missing_models = tasks::Entity::find()
            .filter(tasks::Column::DbId.is_in(missing_ids))
            .all(db)
            .await?;
        for model in missing_models {
            uuid_map.insert(model.db_id, Uuid::parse_str(&model.uuid)?);
        }
    }

    let mut links_by_task: HashMap<i32, Vec<Link>> = HashMap::new();

    // Process outgoing links - these are stored as-is with their canonical type
    for link in outgoing_links {
        let from_uuid = *uuid_map.get(&link.from_task_id).ok_or_else(|| {
            CoreError::not_found(format!(
                "Could not resolve linked task id {} to a UUID",
                link.from_task_id
            ))
        })?;
        let to_uuid = *uuid_map.get(&link.to_task_id).ok_or_else(|| {
            CoreError::not_found(format!(
                "Could not resolve linked task id {} to a UUID",
                link.to_task_id
            ))
        })?;

        let link_type = link
            .r#type
            .parse::<LinkType>()
            .map_err(|_| CoreError::not_found(format!("Unknown link type: {}", link.r#type)))?;

        links_by_task
            .entry(link.from_task_id)
            .or_default()
            .push(Link {
                id: Some(link.id),
                from: from_uuid,
                to: to_uuid,
                link_type,
            });
    }

    // Process incoming links - construct inverse/symmetric links
    for link in incoming_links {
        let current_uuid = *uuid_map.get(&link.to_task_id).ok_or_else(|| {
            CoreError::not_found(format!(
                "Could not resolve linked task id {} to a UUID",
                link.to_task_id
            ))
        })?;
        let source_uuid = *uuid_map.get(&link.from_task_id).ok_or_else(|| {
            CoreError::not_found(format!(
                "Could not resolve linked task id {} to a UUID",
                link.from_task_id
            ))
        })?;

        let stored_type = link
            .r#type
            .parse::<LinkType>()
            .map_err(|_| CoreError::not_found(format!("Unknown link type: {}", link.r#type)))?;

        // Determine the link type to show on this (target) task
        let display_type = match stored_type {
            // Asymmetric canonical → inferred inverse
            LinkType::DependsOn => LinkType::Blocking,
            LinkType::ParentOf => LinkType::ChildOf,
            // Symmetric types display the same on both sides
            LinkType::RelatedTo => LinkType::RelatedTo,
            LinkType::Duplicates => LinkType::Duplicates,
            // Inferred types should never be stored
            LinkType::Blocking | LinkType::ChildOf => continue,
        };

        links_by_task
            .entry(link.to_task_id)
            .or_default()
            .push(Link {
                id: None, // Inferred links don't have their own ID
                from: current_uuid,
                to: source_uuid,
                link_type: display_type,
            });
    }

    let mut tasks_obj = Vec::with_capacity(models.len());
    for task_model in models {
        let uuid = *uuid_map.get(&task_model.db_id).ok_or_else(|| {
            CoreError::not_found(format!(
                "Could not resolve linked task id {} to a UUID",
                task_model.db_id
            ))
        })?;
        let status = TaskStatus::from_string(&task_model.status)?;
        let date_created = parse_datetime(&task_model.date_created)?;
        let date_completed = task_model
            .date_completed
            .as_ref()
            .map(|value| parse_datetime(value))
            .transpose()?;
        let date_due = task_model
            .date_due
            .as_ref()
            .map(|value| parse_datetime(value))
            .transpose()?;
        let date_planned = task_model
            .date_planned
            .as_ref()
            .map(|value| parse_datetime(value))
            .transpose()?;
        let urgency = task_model.urgency.map(|value| value as i64);

        let project = task_model
            .project_id
            .and_then(|project_id| projects_map.get(&project_id).cloned());

        let tags = tags_by_task.remove(&task_model.db_id).unwrap_or_default();
        let annotations = annotations_by_task
            .remove(&task_model.db_id)
            .unwrap_or_default();
        let history = history_by_task
            .remove(&task_model.db_id)
            .unwrap_or_default();
        let links = links_by_task.remove(&task_model.db_id).unwrap_or_default();
        let email_links = email_links_by_task
            .remove(&task_model.db_id)
            .unwrap_or_default();
        let important_links = important_links_by_task
            .remove(&task_model.db_id)
            .unwrap_or_default();

        tasks_obj.push(Task {
            db_id: Some(task_model.db_id),
            id: task_model.id,
            status,
            uuid,
            summary: task_model.summary.to_owned(),
            annotations,
            tags,
            date_created,
            date_completed,
            links,
            project,
            date_due,
            date_planned,
            urgency,
            history,
            email_links,
            important_links,
        });
    }

    Ok(tasks_obj)
}

#[cfg(test)]
mod tests {
    use super::super::{connection::get_database, tables, task_write::write_tasks_impl};
    use super::*;
    use crate::{
        filters::{
            Filter,
            filters_impl::{
                AndFilter, DateCreatedFilter, DateDueFilter, DateDueFilterType, DateEndFilter,
                DependsOnFilter, OrFilter, ProjectFilter, StatusFilter, StringFilter, TagFilter,
                TaskIdFilter, UuidFilter, XorFilter,
            },
        },
        task::{DependsOnIdentifier, Link, LinkType, Project, Task, TaskProperties, TaskStatus},
    };
    use all_asserts::assert_true;
    use chrono::{Duration, Local, TimeZone};
    use log::debug;
    use sea_orm::{
        ColumnTrait, DatabaseConnection, DbErr, EntityTrait, QueryFilter, TransactionTrait,
    };
    use uuid::Uuid;

    /// Compare the filtered results against a single expected task.
    async fn assert_single_match(
        db: &DatabaseConnection,
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

    async fn refresh_blocking_status(db: &DatabaseConnection) -> Result<(), DbErr> {
        let txn = db.begin().await?;
        crate::storage::db::blocking::update_blocking_status(&txn).await?;
        txn.commit().await?;
        Ok(())
    }

    #[tokio::test]
    async fn test_insert_load_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        let t = Task {
            summary: "foo bar cafe".to_string(),
            ..Default::default()
        };
        let saved_uuid = t.uuid;

        write_tasks_impl(&db, &t).await.unwrap();

        let initial_db_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(saved_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should have been inserted");
        assert_eq!(saved_uuid.to_string(), initial_db_task.uuid);

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "foo bar cafe".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 1, "Should have one task retrieved");

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "FOO".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 1, "Should be case insensitive");

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "cafe".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 1, "Should be case insensitive");

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "CAFE".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(
            loaded.to_vec().len(),
            1,
            "Should be case insensitive with non-ascii char"
        );

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "NO".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 0, "Should not be matching");
    }

    #[tokio::test]
    async fn test_filter_status_matches_single_task() {
        init_logger();
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let active_task = Task {
            summary: "active-task".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &active_task).await.unwrap();

        let pending_task = Task {
            summary: "pending-task".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &pending_task).await.unwrap();

        let all_tasks = tables::tasks::Entity::find().all(&db).await.unwrap();
        debug!("FOO {:?}", &all_tasks);
        assert_eq!(all_tasks.len(), 2);
        let statuses: Vec<_> = all_tasks.iter().map(|t| t.status.clone()).collect();
        assert!(statuses.contains(&TaskStatus::Active.to_db_string()));
        assert!(statuses.contains(&TaskStatus::Pending.to_db_string()));

        assert_single_match(
            &db,
            Box::new(StatusFilter {
                status: TaskStatus::Active,
            }),
            &active_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_string_matches_single_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_task = Task {
            summary: "Alpha Project".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_task).await.unwrap();

        let beta_task = Task {
            summary: "Beta Project".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &beta_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(StringFilter {
                value: "alpha".to_string(),
            }),
            &alpha_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_task_id_matches_only_exact_id() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let task_one = Task {
            summary: "Task-1".to_string(),
            id: Some(1),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &task_one).await.unwrap();

        let task_two = Task {
            summary: "Task-2".to_string(),
            id: Some(2),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &task_two).await.unwrap();

        assert_single_match(&db, Box::new(TaskIdFilter { id: 1 }), &task_one).await;
    }

    #[tokio::test]
    async fn test_filter_uuid_matches_single_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let matched = Task {
            summary: "Uuid-Match".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &matched).await.unwrap();

        let other = Task {
            summary: "Uuid-Other".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &other).await.unwrap();

        assert_single_match(&db, Box::new(UuidFilter { uuid: matched.uuid }), &matched).await;
    }

    #[tokio::test]
    async fn test_filter_project_matches_prefix() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_task = Task {
            summary: "Alpha Task".to_string(),
            project: Some(Project::from("alpha.core".to_string())),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_task).await.unwrap();

        let beta_task = Task {
            summary: "Beta Task".to_string(),
            project: Some(Project::from("beta.core".to_string())),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &beta_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(ProjectFilter {
                name: Project::from("alpha".to_string()),
            }),
            &alpha_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_tag_include_matches_only_tagged_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let tagged_task = Task {
            summary: "Tagged Task".to_string(),
            tags: vec!["urgent".to_string()],
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &tagged_task).await.unwrap();

        let untagged_task = Task {
            summary: "Untagged Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &untagged_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(TagFilter {
                include: true,
                tag_name: "urgent".to_string(),
            }),
            &tagged_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_tag_exclude_omits_tagged_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let tagged_task = Task {
            summary: "Tagged Task".to_string(),
            tags: vec!["chore".to_string()],
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &tagged_task).await.unwrap();

        let clean_task = Task {
            summary: "Clean Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &clean_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(TagFilter {
                include: false,
                tag_name: "chore".to_string(),
            }),
            &clean_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_created_before() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early = Local.with_ymd_and_hms(2024, 1, 1, 9, 0, 0).unwrap();
        let late = Local.with_ymd_and_hms(2024, 1, 3, 9, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 1, 2, 9, 0, 0).unwrap();

        let early_task = Task {
            summary: "Early Task".to_string(),
            date_created: early,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &early_task).await.unwrap();

        let late_task = Task {
            summary: "Late Task".to_string(),
            date_created: late,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &late_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateCreatedFilter {
                time: threshold,
                before: true,
            }),
            &early_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_created_after_or_equal() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early = Local.with_ymd_and_hms(2024, 1, 1, 9, 0, 0).unwrap();
        let late = Local.with_ymd_and_hms(2024, 1, 3, 9, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 1, 2, 9, 0, 0).unwrap();

        let early_task = Task {
            summary: "Early Task".to_string(),
            date_created: early,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &early_task).await.unwrap();

        let late_task = Task {
            summary: "Late Task".to_string(),
            date_created: late,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &late_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateCreatedFilter {
                time: threshold,
                before: false,
            }),
            &late_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_due_day() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let reference = Local.with_ymd_and_hms(2024, 2, 10, 10, 0, 0).unwrap();

        let due_today = Task {
            summary: "Due Today".to_string(),
            date_due: Some(reference),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_today).await.unwrap();

        let due_tomorrow = Task {
            summary: "Due Tomorrow".to_string(),
            date_due: Some(reference + Duration::days(1)),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_tomorrow).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateDueFilter {
                time: reference,
                type_when: DateDueFilterType::Day,
            }),
            &due_today,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_due_before() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early_due = Local.with_ymd_and_hms(2024, 3, 1, 12, 0, 0).unwrap();
        let late_due = Local.with_ymd_and_hms(2024, 3, 5, 12, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 3, 4, 12, 0, 0).unwrap();

        let due_early = Task {
            summary: "Due Early".to_string(),
            date_due: Some(early_due),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_early).await.unwrap();

        let due_late = Task {
            summary: "Due Late".to_string(),
            date_due: Some(late_due),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_late).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateDueFilter {
                time: threshold,
                type_when: DateDueFilterType::Before,
            }),
            &due_early,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_due_after() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early_due = Local.with_ymd_and_hms(2024, 4, 1, 12, 0, 0).unwrap();
        let late_due = Local.with_ymd_and_hms(2024, 4, 5, 12, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 4, 3, 12, 0, 0).unwrap();

        let due_early = Task {
            summary: "Due Early".to_string(),
            date_due: Some(early_due),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_early).await.unwrap();

        let due_later = Task {
            summary: "Due Later".to_string(),
            date_due: Some(late_due),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_later).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateDueFilter {
                time: threshold,
                type_when: DateDueFilterType::After,
            }),
            &due_later,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_end_before() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early_complete = Local.with_ymd_and_hms(2024, 5, 1, 8, 0, 0).unwrap();
        let late_complete = Local.with_ymd_and_hms(2024, 5, 3, 8, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 5, 2, 8, 0, 0).unwrap();

        let completed_early = Task {
            summary: "Completed Early".to_string(),
            date_completed: Some(early_complete),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &completed_early).await.unwrap();

        let completed_late = Task {
            summary: "Completed Late".to_string(),
            date_completed: Some(late_complete),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &completed_late).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateEndFilter {
                time: threshold,
                before: true,
            }),
            &completed_early,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_end_after() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early_complete = Local.with_ymd_and_hms(2024, 5, 1, 8, 0, 0).unwrap();
        let late_complete = Local.with_ymd_and_hms(2024, 5, 3, 8, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 5, 2, 8, 0, 0).unwrap();

        let completed_early = Task {
            summary: "Completed Early".to_string(),
            date_completed: Some(early_complete),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &completed_early).await.unwrap();

        let completed_late = Task {
            summary: "Completed Late".to_string(),
            date_completed: Some(late_complete),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &completed_late).await.unwrap();

        // end.after should only match tasks completed at or after the threshold
        assert_single_match(
            &db,
            Box::new(DateEndFilter {
                time: threshold,
                before: false,
            }),
            &completed_late,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_depends_on_returns_only_dependents() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let target_task = Task {
            summary: "Target Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        let target_uuid = target_task.uuid;
        write_tasks_impl(&db, &target_task).await.unwrap();

        let mut dependent_task = Task {
            summary: "Dependent Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        let dependent_uuid = dependent_task.uuid;
        dependent_task.links.push(Link {
            id: None,
            from: dependent_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });
        write_tasks_impl(&db, &dependent_task).await.unwrap();
        refresh_blocking_status(&db).await.unwrap();

        let independent_task = Task {
            summary: "Independent Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &independent_task).await.unwrap();

        dependent_task.status = TaskStatus::Blocked;
        assert_single_match(
            &db,
            Box::new(DependsOnFilter {
                id: None,
                uuid: Some(target_uuid),
            }),
            &dependent_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_load_extra_tasks() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let target_task = Task {
            summary: "Target Task".to_string(),
            uuid: Uuid::new_v4(),
            id: Some(1),
            ..Default::default()
        };
        let target_uuid = target_task.uuid;
        write_tasks_impl(&db, &target_task).await.unwrap();

        let mut dependent_task = Task {
            summary: "Dependent Task".to_string(),
            uuid: Uuid::new_v4(),
            id: Some(2),
            ..Default::default()
        };
        let dependent_uuid = dependent_task.uuid;
        dependent_task.links.push(Link {
            id: None,
            from: dependent_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });
        write_tasks_impl(&db, &dependent_task).await.unwrap();

        let independent_task = Task {
            summary: "Independent Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &independent_task).await.unwrap();

        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: target_uuid });

        let task_props = TaskProperties {
            depends_on: Some(vec![DependsOnIdentifier::Uuid(dependent_uuid.to_owned())]),
            ..TaskProperties::default()
        };
        let results_data = load_tasks_impl(&db, Some(filter.clone()), Some(task_props))
            .await
            .unwrap();
        assert_eq!(results_data.to_vec().len(), 1);
        assert_eq!(results_data.to_vec()[0].uuid, target_uuid);
        assert_eq!(results_data.get_extra_tasks().len(), 1);
        assert_true!(
            results_data
                .get_extra_tasks()
                .get(&dependent_uuid)
                .is_some()
        );

        let task_props = TaskProperties {
            depends_on: Some(vec![DependsOnIdentifier::Id(
                dependent_task.id.unwrap().to_owned(),
            )]),
            ..TaskProperties::default()
        };
        let results_data = load_tasks_impl(&db, Some(filter.clone()), Some(task_props))
            .await
            .unwrap();
        assert_eq!(results_data.to_vec().len(), 1);
        assert_eq!(results_data.to_vec()[0].uuid, target_uuid);
        assert_eq!(results_data.get_extra_tasks().len(), 1);
        assert_true!(
            results_data
                .get_extra_tasks()
                .get(&dependent_uuid)
                .is_some()
        );
        assert_eq!(
            results_data
                .get_extra_tasks()
                .get(&dependent_uuid)
                .unwrap()
                .id,
            dependent_task.id
        );

        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        assert_eq!(results_data.to_vec().len(), 1);
        assert_eq!(results_data.to_vec()[0].uuid, target_uuid);
        assert_true!(results_data.get_extra_tasks().is_empty());
    }

    #[tokio::test]
    async fn test_filter_and_combination() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_active = Task {
            summary: "Alpha Active".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_active).await.unwrap();

        let alpha_pending = Task {
            summary: "Alpha Pending".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_pending).await.unwrap();

        assert_single_match(
            &db,
            Box::new(AndFilter {
                children: vec![
                    Box::new(StatusFilter {
                        status: TaskStatus::Active,
                    }),
                    Box::new(StringFilter {
                        value: "alpha".to_string(),
                    }),
                ],
            }),
            &alpha_active,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_or_combination() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_pending = Task {
            summary: "Alpha Pending".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_pending).await.unwrap();

        let beta_pending = Task {
            summary: "Beta Pending".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &beta_pending).await.unwrap();

        assert_single_match(
            &db,
            Box::new(OrFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "alpha".to_string(),
                    }),
                    Box::new(StatusFilter {
                        status: TaskStatus::Active,
                    }),
                ],
            }),
            &alpha_pending,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_xor_combination() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_pending = Task {
            summary: "Alpha Pending".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_pending).await.unwrap();

        let beta_pending = Task {
            summary: "Beta Pending".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &beta_pending).await.unwrap();

        let alpha_active = Task {
            summary: "Alpha Active".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_active).await.unwrap();

        assert_single_match(
            &db,
            Box::new(XorFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "alpha".to_string(),
                    }),
                    Box::new(StatusFilter {
                        status: TaskStatus::Active,
                    }),
                ],
            }),
            &alpha_pending,
        )
        .await;
    }

    // =========================================================================
    // LINK STORAGE TESTS
    // =========================================================================
    //
    // These tests verify that all link types are properly stored and loaded
    // from the database. The key insight is:
    // - Canonical types (DependsOn, ParentOf) are stored as-is
    // - Inferred types (Blocking, ChildOf) should be stored with swapped direction
    //   as their canonical counterpart
    // - Symmetric types (RelatedTo, Duplicates) use canonical UUID ordering
    // =========================================================================

    /// Test: DependsOn link is stored and loaded correctly
    #[tokio::test]
    async fn test_depends_on_link_stored_and_loaded() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let target_uuid = Uuid::new_v4();
        let source_uuid = Uuid::new_v4();

        // Create target task (the one being depended on)
        let target_task = Task {
            summary: "Target Task".to_string(),
            uuid: target_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &target_task).await.unwrap();

        // Create source task with DependsOn link to target
        let mut source_task = Task {
            summary: "Source Task".to_string(),
            uuid: source_uuid,
            ..Default::default()
        };
        source_task.links.push(Link {
            id: None,
            from: source_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });
        write_tasks_impl(&db, &source_task).await.unwrap();

        // Load source task and verify DependsOn link exists
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: source_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].links.len(), 1);
        assert_eq!(results[0].links[0].link_type, LinkType::DependsOn);
        assert_eq!(results[0].links[0].to, target_uuid);

        // Load target task and verify Blocking link is inferred
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: target_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Target should have inferred Blocking link"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::Blocking);
        assert_eq!(results[0].links[0].to, source_uuid);
    }

    /// Test: Blocking link is stored (as DependsOn with swapped direction) and loaded correctly
    ///
    /// When task A has a Blocking link to task B, it means:
    /// - A blocks B (B depends on A)
    /// - Should be stored as DependsOn(from=B, to=A) in the database
    /// - When loading A, we should see the Blocking link to B
    /// - When loading B, we should see the DependsOn link to A
    #[tokio::test]
    async fn test_blocking_link_stored_and_loaded() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let blocker_uuid = Uuid::new_v4();
        let blocked_uuid = Uuid::new_v4();

        // Create blocked task (the one being blocked)
        let blocked_task = Task {
            summary: "Blocked Task".to_string(),
            uuid: blocked_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &blocked_task).await.unwrap();

        // Create blocker task with Blocking link
        let mut blocker_task = Task {
            summary: "Blocker Task".to_string(),
            uuid: blocker_uuid,
            ..Default::default()
        };
        blocker_task.links.push(Link {
            id: None,
            from: blocker_uuid,
            to: blocked_uuid,
            link_type: LinkType::Blocking,
        });
        write_tasks_impl(&db, &blocker_task).await.unwrap();

        // Load blocker task and verify Blocking link exists
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: blocker_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Blocker task should have the Blocking link after round-trip"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::Blocking);
        assert_eq!(results[0].links[0].to, blocked_uuid);

        // Load blocked task and verify DependsOn link exists (the canonical form)
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: blocked_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Blocked task should have DependsOn link to blocker"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::DependsOn);
        assert_eq!(results[0].links[0].to, blocker_uuid);
    }

    /// Test: ParentOf link is stored and loaded correctly
    #[tokio::test]
    async fn test_parent_of_link_stored_and_loaded() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let parent_uuid = Uuid::new_v4();
        let child_uuid = Uuid::new_v4();

        // Create child task
        let child_task = Task {
            summary: "Child Task".to_string(),
            uuid: child_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &child_task).await.unwrap();

        // Create parent task with ParentOf link
        let mut parent_task = Task {
            summary: "Parent Task".to_string(),
            uuid: parent_uuid,
            ..Default::default()
        };
        parent_task.links.push(Link {
            id: None,
            from: parent_uuid,
            to: child_uuid,
            link_type: LinkType::ParentOf,
        });
        write_tasks_impl(&db, &parent_task).await.unwrap();

        // Load parent task and verify ParentOf link exists
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: parent_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].links.len(), 1);
        assert_eq!(results[0].links[0].link_type, LinkType::ParentOf);
        assert_eq!(results[0].links[0].to, child_uuid);

        // Load child task and verify ChildOf link is inferred
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: child_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Child should have inferred ChildOf link"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::ChildOf);
        assert_eq!(results[0].links[0].to, parent_uuid);
    }

    /// Test: ChildOf link is stored (as ParentOf with swapped direction) and loaded correctly
    ///
    /// When task A has a ChildOf link to task B, it means:
    /// - A is a child of B (B is parent of A)
    /// - Should be stored as ParentOf(from=B, to=A) in the database
    /// - When loading A, we should see the ChildOf link to B
    /// - When loading B, we should see the ParentOf link to A
    #[tokio::test]
    async fn test_child_of_link_stored_and_loaded() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let child_uuid = Uuid::new_v4();
        let parent_uuid = Uuid::new_v4();

        // Create parent task
        let parent_task = Task {
            summary: "Parent Task".to_string(),
            uuid: parent_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &parent_task).await.unwrap();

        // Create child task with ChildOf link
        let mut child_task = Task {
            summary: "Child Task".to_string(),
            uuid: child_uuid,
            ..Default::default()
        };
        child_task.links.push(Link {
            id: None,
            from: child_uuid,
            to: parent_uuid,
            link_type: LinkType::ChildOf,
        });
        write_tasks_impl(&db, &child_task).await.unwrap();

        // Load child task and verify ChildOf link exists
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: child_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Child task should have ChildOf link after round-trip"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::ChildOf);
        assert_eq!(results[0].links[0].to, parent_uuid);

        // Load parent task and verify ParentOf link exists (the canonical form)
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: parent_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Parent task should have ParentOf link to child"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::ParentOf);
        assert_eq!(results[0].links[0].to, child_uuid);
    }

    /// Test: RelatedTo link is stored and loaded with symmetric behavior
    #[tokio::test]
    async fn test_related_to_link_stored_and_loaded() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let task_a_uuid = Uuid::new_v4();
        let task_b_uuid = Uuid::new_v4();

        // Create task B first
        let task_b = Task {
            summary: "Task B".to_string(),
            uuid: task_b_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &task_b).await.unwrap();

        // Create task A with RelatedTo link to B
        let mut task_a = Task {
            summary: "Task A".to_string(),
            uuid: task_a_uuid,
            ..Default::default()
        };
        task_a.links.push(Link {
            id: None,
            from: task_a_uuid,
            to: task_b_uuid,
            link_type: LinkType::RelatedTo,
        });
        write_tasks_impl(&db, &task_a).await.unwrap();

        // Load task A and verify RelatedTo link exists
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: task_a_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].links.len(), 1);
        assert_eq!(results[0].links[0].link_type, LinkType::RelatedTo);
        assert_eq!(results[0].links[0].to, task_b_uuid);

        // Load task B and verify RelatedTo link is symmetric
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: task_b_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Task B should have symmetric RelatedTo link"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::RelatedTo);
        assert_eq!(results[0].links[0].to, task_a_uuid);
    }

    /// Test: Duplicates link is stored and loaded with symmetric behavior
    #[tokio::test]
    async fn test_duplicates_link_stored_and_loaded() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let task_a_uuid = Uuid::new_v4();
        let task_b_uuid = Uuid::new_v4();

        // Create task B first
        let task_b = Task {
            summary: "Task B".to_string(),
            uuid: task_b_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &task_b).await.unwrap();

        // Create task A with Duplicates link to B
        let mut task_a = Task {
            summary: "Task A".to_string(),
            uuid: task_a_uuid,
            ..Default::default()
        };
        task_a.links.push(Link {
            id: None,
            from: task_a_uuid,
            to: task_b_uuid,
            link_type: LinkType::Duplicates,
        });
        write_tasks_impl(&db, &task_a).await.unwrap();

        // Load task A and verify Duplicates link exists
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: task_a_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].links.len(), 1);
        assert_eq!(results[0].links[0].link_type, LinkType::Duplicates);
        assert_eq!(results[0].links[0].to, task_b_uuid);

        // Load task B and verify Duplicates link is symmetric
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: task_b_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Task B should have symmetric Duplicates link"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::Duplicates);
        assert_eq!(results[0].links[0].to, task_a_uuid);
    }

    /// Test: Multiple link types on the same task
    #[tokio::test]
    async fn test_multiple_link_types() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let main_uuid = Uuid::new_v4();
        let dep_uuid = Uuid::new_v4();
        let blocks_uuid = Uuid::new_v4();
        let parent_uuid = Uuid::new_v4();
        let related_uuid = Uuid::new_v4();

        // Create all target tasks
        for (uuid, name) in [
            (dep_uuid, "Dependency"),
            (blocks_uuid, "Blocked"),
            (parent_uuid, "Parent"),
            (related_uuid, "Related"),
        ] {
            let task = Task {
                summary: name.to_string(),
                uuid,
                ..Default::default()
            };
            write_tasks_impl(&db, &task).await.unwrap();
        }

        // Create main task with multiple link types
        let mut main_task = Task {
            summary: "Main Task".to_string(),
            uuid: main_uuid,
            ..Default::default()
        };
        main_task.links.extend(vec![
            Link {
                id: None,
                from: main_uuid,
                to: dep_uuid,
                link_type: LinkType::DependsOn,
            },
            Link {
                id: None,
                from: main_uuid,
                to: blocks_uuid,
                link_type: LinkType::Blocking,
            },
            Link {
                id: None,
                from: main_uuid,
                to: parent_uuid,
                link_type: LinkType::ChildOf,
            },
            Link {
                id: None,
                from: main_uuid,
                to: related_uuid,
                link_type: LinkType::RelatedTo,
            },
        ]);
        write_tasks_impl(&db, &main_task).await.unwrap();

        // Load main task and verify all links exist
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: main_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            4,
            "Main task should have all 4 links after round-trip"
        );

        // Verify each link type exists
        let link_types: Vec<LinkType> = results[0]
            .links
            .iter()
            .map(|l| l.link_type.clone())
            .collect();
        assert!(link_types.contains(&LinkType::DependsOn));
        assert!(link_types.contains(&LinkType::Blocking));
        assert!(link_types.contains(&LinkType::ChildOf));
        assert!(link_types.contains(&LinkType::RelatedTo));
    }

    /// Test: Blocking link via Task::apply() - simulates command palette flow
    ///
    /// This is the key integration test that simulates what happens when a user
    /// creates a "blocks" link via the command palette:
    /// 1. Parse "modify blocks:uuid"
    /// 2. Apply properties to task (adds Blocking link)
    /// 3. Save task
    /// 4. Reload and verify the link persisted
    #[tokio::test]
    async fn test_blocking_link_via_apply() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let blocker_uuid = Uuid::new_v4();
        let blocked_uuid = Uuid::new_v4();

        // Create both tasks first
        let blocked_task = Task {
            summary: "Blocked Task".to_string(),
            uuid: blocked_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &blocked_task).await.unwrap();

        let mut blocker_task = Task {
            summary: "Blocker Task".to_string(),
            uuid: blocker_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &blocker_task).await.unwrap();

        // Apply blocks property (simulates parsing "modify blocks:uuid")
        let props = TaskProperties {
            blocks: Some(vec![DependsOnIdentifier::Uuid(blocked_uuid)]),
            ..TaskProperties::default()
        };
        blocker_task.apply(&props).unwrap();

        // Verify link was added in memory
        assert_eq!(blocker_task.links.len(), 1);
        assert_eq!(blocker_task.links[0].link_type, LinkType::Blocking);

        // Save the modified task
        write_tasks_impl(&db, &blocker_task).await.unwrap();

        // Reload blocker task and verify Blocking link persisted
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: blocker_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Blocker task should have Blocking link after save and reload"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::Blocking);
        assert_eq!(results[0].links[0].to, blocked_uuid);
    }

    /// Test: ChildOf link via Task::apply()
    #[tokio::test]
    async fn test_child_of_link_via_apply() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let child_uuid = Uuid::new_v4();
        let parent_uuid = Uuid::new_v4();

        // Create both tasks first
        let parent_task = Task {
            summary: "Parent Task".to_string(),
            uuid: parent_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &parent_task).await.unwrap();

        let mut child_task = Task {
            summary: "Child Task".to_string(),
            uuid: child_uuid,
            ..Default::default()
        };
        write_tasks_impl(&db, &child_task).await.unwrap();

        // Apply child_of property
        let props = TaskProperties {
            child_of: Some(vec![DependsOnIdentifier::Uuid(parent_uuid)]),
            ..TaskProperties::default()
        };
        child_task.apply(&props).unwrap();

        // Verify link was added in memory
        assert_eq!(child_task.links.len(), 1);
        assert_eq!(child_task.links[0].link_type, LinkType::ChildOf);

        // Save the modified task
        write_tasks_impl(&db, &child_task).await.unwrap();

        // Reload child task and verify ChildOf link persisted
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: child_uuid });
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].links.len(),
            1,
            "Child task should have ChildOf link after save and reload"
        );
        assert_eq!(results[0].links[0].link_type, LinkType::ChildOf);
        assert_eq!(results[0].links[0].to, parent_uuid);
    }
}
