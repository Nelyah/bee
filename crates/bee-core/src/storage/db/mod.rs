mod attachments;
mod blocking;
mod connection;
mod external_links;
mod filter_sql;
mod sync_relations;
mod tables;
mod task_read;
mod task_write;
mod undo;
mod user_reports;

use std::collections::HashSet;

use crate::{
    CoreResult,
    attachment::Attachment,
    external_links::ExternalLink,
    filters::{Filter, filters_impl::UuidFilter},
    storage::{
        AsyncStore,
        db::{
            attachments as attachments_db,
            blocking::{resequence_task_ids_txn, update_blocking_status},
            connection::get_database,
            external_links as external_links_db,
            task_read::{
                get_project_burndown, get_project_task_totals, get_projects_with_counts,
                get_projects_with_status_breakdown, get_tags_with_counts, load_tasks_impl,
            },
            task_write::write_tasks_impl,
            undo::{append_undo_action_impl, load_undos_impl},
            user_reports as user_reports_db,
        },
    },
    task::{ActionUndo, Task, TaskData, TaskProperties},
};
use sea_orm::TransactionTrait;

// Re-export profile-aware database functions for use by bee-api
pub use connection::{get_database_for_profile, get_database_url_for_profile};

pub use user_reports::{UserReport, UserReportParams};

pub use task_read::{BurndownRow, CompletionRow, ProjectStatusRow};

// TODO: Need to update SeaORM to use the newer related entities and subtypes
// https://www.sea-ql.org/blog/2025-10-20-sea-orm-2.0/
// sea-orm-cli generate entity --output-dir ./src/entity --entity-format dense

/// Async store backed by the sqlite database.
pub struct DbStore {}

impl DbStore {
    /// Get all unique projects with task counts.
    pub async fn get_projects() -> CoreResult<Vec<CompletionRow>> {
        let db = get_database(None).await?;
        get_projects_with_counts(&db).await
    }

    /// Get all unique tags with task counts.
    pub async fn get_tags() -> CoreResult<Vec<CompletionRow>> {
        let db = get_database(None).await?;
        get_tags_with_counts(&db).await
    }

    // Project Overview methods

    /// Get all projects with status breakdown (pending, active, completed, overdue counts).
    pub async fn get_projects_with_stats() -> CoreResult<Vec<ProjectStatusRow>> {
        let db = get_database(None).await?;
        get_projects_with_status_breakdown(&db).await
    }

    /// Get burndown data for a project (daily completion counts).
    ///
    /// Returns data points for the past `days` days. Uses prefix matching
    /// so "backend" includes "backend.api", "backend.db", etc.
    pub async fn get_burndown(project_name: &str, days: u32) -> CoreResult<Vec<BurndownRow>> {
        let db = get_database(None).await?;
        get_project_burndown(&db, project_name, days).await
    }

    /// Get total task counts for a project (total, completed).
    pub async fn get_project_totals(project_name: &str) -> CoreResult<(i64, i64)> {
        let db = get_database(None).await?;
        get_project_task_totals(&db, project_name).await
    }

    /// Load a single task by UUID, including annotations and history.
    pub async fn get_task_by_uuid(task_uuid: uuid::Uuid) -> CoreResult<Option<Task>> {
        let db = get_database(None).await?;
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: task_uuid });
        let data = load_tasks_impl(&db, Some(filter), None).await?;
        Ok(data.get_owned(&task_uuid))
    }

    pub async fn list_external_links_by_task(
        task_uuid: uuid::Uuid,
    ) -> CoreResult<Vec<ExternalLink>> {
        let db = get_database(None).await?;
        let links = external_links_db::list_by_task_uuid(&db, task_uuid).await?;
        Ok(links)
    }

    pub async fn list_external_links(
        provider: Option<&str>,
        task_uuid: Option<uuid::Uuid>,
    ) -> CoreResult<Vec<ExternalLink>> {
        let db = get_database(None).await?;
        let links = external_links_db::list_all(&db, provider, task_uuid).await?;
        Ok(links)
    }

    pub async fn insert_external_link(
        task_uuid: uuid::Uuid,
        provider: String,
        url: String,
        external_key: String,
    ) -> CoreResult<ExternalLink> {
        let db = get_database(None).await?;
        let link =
            external_links_db::insert_link(&db, task_uuid, provider, url, external_key).await?;
        Ok(link)
    }

    pub async fn get_external_link_by_id(link_id: i32) -> CoreResult<Option<ExternalLink>> {
        let db = get_database(None).await?;
        let link = external_links_db::get_by_id(&db, link_id).await?;
        Ok(link)
    }

    pub async fn delete_external_link_by_id(link_id: i32) -> CoreResult<()> {
        let db = get_database(None).await?;
        external_links_db::delete_by_id(&db, link_id).await?;
        Ok(())
    }

    pub async fn update_external_link_cache_success(
        link_id: i32,
        cached_response: String,
        last_synced_at: chrono::DateTime<chrono::Utc>,
    ) -> CoreResult<()> {
        let db = get_database(None).await?;
        external_links_db::update_cache_success(&db, link_id, cached_response, last_synced_at)
            .await?;
        Ok(())
    }

    pub async fn update_external_link_sync_error(
        link_id: i32,
        sync_error: String,
    ) -> CoreResult<()> {
        let db = get_database(None).await?;
        external_links_db::update_sync_error(&db, link_id, sync_error).await?;
        Ok(())
    }

    // User Reports CRUD methods

    /// List all user-created reports.
    pub async fn list_user_reports() -> CoreResult<Vec<UserReport>> {
        let db = get_database(None).await?;
        let reports = user_reports_db::list_all(&db).await?;
        Ok(reports)
    }

    /// Get a user report by name.
    pub async fn get_user_report_by_name(name: &str) -> CoreResult<Option<UserReport>> {
        let db = get_database(None).await?;
        let report = user_reports_db::get_by_name(&db, name).await?;
        Ok(report)
    }

    /// Create a new user report.
    pub async fn insert_user_report(
        name: String,
        params: UserReportParams,
    ) -> CoreResult<UserReport> {
        let db = get_database(None).await?;
        let report = user_reports_db::insert(&db, name, params).await?;
        Ok(report)
    }

    /// Update an existing user report.
    pub async fn update_user_report(
        name: &str,
        params: UserReportParams,
    ) -> CoreResult<UserReport> {
        let db = get_database(None).await?;
        let report = user_reports_db::update(&db, name, params).await?;
        Ok(report)
    }

    /// Delete a user report by name.
    pub async fn delete_user_report(name: &str) -> CoreResult<()> {
        let db = get_database(None).await?;
        user_reports_db::delete_by_name(&db, name).await?;
        Ok(())
    }

    /// List all user report names (for startup collision detection).
    pub async fn list_user_report_names() -> CoreResult<Vec<String>> {
        let db = get_database(None).await?;
        let names = user_reports_db::list_names(&db).await?;
        Ok(names)
    }

    // Attachments CRUD methods

    /// List all attachments for a task (metadata only, no file data).
    pub async fn list_attachments_by_task(task_uuid: uuid::Uuid) -> CoreResult<Vec<Attachment>> {
        let db = get_database(None).await?;
        let attachments = attachments_db::list_by_task_uuid(&db, task_uuid).await?;
        Ok(attachments)
    }

    /// Get attachment metadata by ID.
    pub async fn get_attachment_by_id(attachment_id: i32) -> CoreResult<Option<Attachment>> {
        let db = get_database(None).await?;
        let attachment = attachments_db::get_by_id(&db, attachment_id).await?;
        Ok(attachment)
    }

    /// Get the raw file data (BLOB) for an attachment.
    pub async fn get_attachment_data(attachment_id: i32) -> CoreResult<Option<Vec<u8>>> {
        let db = get_database(None).await?;
        let data = attachments_db::get_data_by_id(&db, attachment_id).await?;
        Ok(data)
    }

    /// Upload a new attachment with file data.
    pub async fn insert_attachment(
        task_uuid: uuid::Uuid,
        filename: String,
        mime_type: String,
        data: Vec<u8>,
    ) -> CoreResult<Attachment> {
        let db = get_database(None).await?;
        let attachment =
            attachments_db::insert_attachment(&db, task_uuid, filename, mime_type, data).await?;
        Ok(attachment)
    }

    /// Delete an attachment by ID.
    pub async fn delete_attachment_by_id(attachment_id: i32) -> CoreResult<()> {
        let db = get_database(None).await?;
        attachments_db::delete_by_id(&db, attachment_id).await?;
        Ok(())
    }

    // =========================================================================
    // Profile-aware methods
    // =========================================================================

    /// Load tasks from a specific profile's database.
    pub async fn load_tasks_for_profile(
        profile: &str,
        filter: Option<Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> CoreResult<TaskData> {
        let db = connection::get_database_for_profile(profile).await?;
        load_tasks_impl(&db, filter, props).await
    }

    /// Write tasks to a specific profile's database.
    pub async fn write_tasks_for_profile(
        profile: &str,
        data: &TaskData,
        changes: &[ActionUndo],
    ) -> CoreResult<()> {
        let db = connection::get_database_for_profile(profile).await?;

        let mut changed_uuids: HashSet<uuid::Uuid> = HashSet::new();
        for undo in changes {
            for task in &undo.tasks {
                changed_uuids.insert(*task.get_uuid());
                for linked_uuid in task.get_extra_uuid() {
                    changed_uuids.insert(linked_uuid);
                }
            }
        }

        if changed_uuids.is_empty() {
            return Ok(());
        }

        for uuid in &changed_uuids {
            if let Some(task) = data.get_task_map().get(uuid) {
                write_tasks_impl(&db, task).await?;
                continue;
            }
            if let Some(task) = data.get_extra_tasks().get(uuid) {
                write_tasks_impl(&db, task).await?;
            }
        }

        let txn = db.begin().await?;
        resequence_task_ids_txn(&txn).await?;
        update_blocking_status(&txn).await?;
        txn.commit().await?;
        Ok(())
    }

    /// Load undo history from a specific profile's database.
    pub async fn load_undos_for_profile(
        profile: &str,
        limit: usize,
    ) -> CoreResult<Vec<ActionUndo>> {
        if limit == 0 {
            return Ok(Vec::new());
        }
        let db = connection::get_database_for_profile(profile).await?;
        load_undos_impl(&db, limit).await
    }

    /// Log undo actions to a specific profile's database.
    pub async fn log_undo_for_profile(
        profile: &str,
        count: usize,
        undos: Vec<ActionUndo>,
    ) -> CoreResult<()> {
        let db = connection::get_database_for_profile(profile).await?;
        append_undo_action_impl(&db, count, undos).await
    }

    /// Get a task by UUID from a specific profile's database.
    pub async fn get_task_by_uuid_for_profile(
        profile: &str,
        uuid: uuid::Uuid,
    ) -> CoreResult<Option<Task>> {
        let db = connection::get_database_for_profile(profile).await?;
        let filter = UuidFilter { uuid };
        let tasks = load_tasks_impl(&db, Some(Box::new(filter)), None).await?;
        Ok(tasks.get_task_map().get(&uuid).cloned())
    }

    /// List attachments for a task in a specific profile's database.
    pub async fn list_attachments_for_profile(
        profile: &str,
        task_uuid: uuid::Uuid,
    ) -> CoreResult<Vec<Attachment>> {
        let db = connection::get_database_for_profile(profile).await?;
        let attachments = attachments_db::list_by_task_uuid(&db, task_uuid).await?;
        Ok(attachments)
    }
}

impl AsyncStore for DbStore {
    async fn load_tasks(
        filter: Option<Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> CoreResult<TaskData> {
        let db = get_database(None).await?;
        load_tasks_impl(&db, filter, props).await
    }
    async fn write_tasks(data: &TaskData, changes: &[ActionUndo]) -> CoreResult<()> {
        let db = get_database(None).await?;

        let mut changed_uuids: HashSet<uuid::Uuid> = HashSet::new();
        for undo in changes {
            for task in &undo.tasks {
                changed_uuids.insert(*task.get_uuid());
                for linked_uuid in task.get_extra_uuid() {
                    changed_uuids.insert(linked_uuid);
                }
            }
        }

        if changed_uuids.is_empty() {
            return Ok(());
        }

        for uuid in &changed_uuids {
            if let Some(task) = data.get_task_map().get(uuid) {
                write_tasks_impl(&db, task).await?;
                continue;
            }
            if let Some(task) = data.get_extra_tasks().get(uuid) {
                write_tasks_impl(&db, task).await?;
            }
        }

        let txn = db.begin().await?;
        resequence_task_ids_txn(&txn).await?;
        update_blocking_status(&txn).await?;
        txn.commit().await?;
        Ok(())
    }

    async fn log_undo(count: usize, undos: Vec<ActionUndo>) -> CoreResult<()> {
        let db = get_database(None).await?;
        append_undo_action_impl(&db, count, undos).await
    }

    async fn load_undos(limit: usize) -> CoreResult<Vec<ActionUndo>> {
        if limit == 0 {
            return Ok(Vec::new());
        }

        let db = get_database(None).await?;
        load_undos_impl(&db, limit).await
    }
}
