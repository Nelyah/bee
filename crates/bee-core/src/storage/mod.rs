//! Storage abstraction for task persistence.
//!
//! This module defines the [`Store`] (synchronous) and [`AsyncStore`] (asynchronous)
//! traits that abstract over the underlying persistence mechanism. The primary
//! implementation is the SQLite-backed [`db`] module.
//!
//! # Usage
//!
//! Storage operations typically follow this pattern:
//! 1. Load tasks with optional filtering via `load_tasks()`
//! 2. Modify tasks in memory
//! 3. Persist changes via `write_tasks()`
//! 4. Record undo information via `log_undo()`
//!
//! The filter and properties parameters to `load_tasks()` work together:
//! - `filter`: Selects which tasks to load (e.g., `status:pending`, `project:backend`)
//! - `props`: Controls task modifications during load (sorting, property updates)

use crate::{
    CoreResult,
    filters::Filter,
    task::{ActionUndo, TaskData, TaskProperties},
};

pub mod db;

/// Synchronous storage interface for task persistence.
///
/// Provides CRUD operations for tasks and a separate undo log. Implementations
/// should handle transactions internally—each method call is atomic.
pub trait Store {
    /// Load tasks matching the optional filter, applying optional property modifications.
    ///
    /// # Arguments
    /// - `filter`: When `Some`, only tasks matching the filter are returned.
    ///   When `None`, all non-deleted tasks are loaded.
    /// - `props`: When `Some`, these properties are applied to matching tasks
    ///   during the load operation (useful for sorting or computed fields).
    ///
    /// Returns a `TaskData` containing the loaded tasks and their index mappings.
    fn load_tasks(
        filter: Option<Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> CoreResult<TaskData>;

    /// Persist tasks affected by the latest action.
    ///
    /// The TaskData provides the authoritative state for tasks, while `changes`
    /// indicates which tasks were modified by the action (via undo entries).
    fn write_tasks(data: &TaskData, changes: &[ActionUndo]) -> CoreResult<()>;

    /// Load the most recent undo entries, up to `limit`.
    ///
    /// Returns entries in reverse chronological order (most recent first).
    /// Used by the undo action to restore previous task states.
    fn load_undos(limit: usize) -> Vec<ActionUndo>;

    /// Update the undo log by replacing the last `count` entries.
    ///
    /// - Pass `count=0` to append new entries without replacing
    /// - Pass `count=N` to replace the N most recent entries (used when
    ///   an undo action consumes entries and adds new reverse entries)
    fn log_undo(count: usize, updated_undos: Vec<ActionUndo>);
}

/// Asynchronous storage interface for task persistence.
///
/// Identical to [`Store`] but with async methods returning `Send` futures.
/// Use this trait for async runtimes (e.g., Tokio in the API server).
pub trait AsyncStore {
    /// Load tasks matching the optional filter, applying optional property modifications.
    ///
    /// See [`Store::load_tasks`] for details on arguments and behavior.
    fn load_tasks(
        filter: Option<Box<dyn Filter>>,
        props: Option<TaskProperties>,
    ) -> impl std::future::Future<Output = CoreResult<TaskData>> + Send;

    /// Persist tasks affected by the latest action.
    ///
    /// See [`Store::write_tasks`] for details.
    fn write_tasks(
        data: &TaskData,
        changes: &[ActionUndo],
    ) -> impl std::future::Future<Output = CoreResult<()>> + Send;

    /// Load the most recent undo entries, up to `limit`.
    ///
    /// See [`Store::load_undos`] for details.
    fn load_undos(
        limit: usize,
    ) -> impl std::future::Future<Output = CoreResult<Vec<ActionUndo>>> + Send;

    /// Update the undo log by replacing the last `count` entries.
    ///
    /// See [`Store::log_undo`] for details.
    fn log_undo(
        count: usize,
        updated_undos: Vec<ActionUndo>,
    ) -> impl std::future::Future<Output = CoreResult<()>> + Send;
}
