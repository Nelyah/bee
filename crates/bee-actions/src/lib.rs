//! Action system for task manipulation commands.
//!
//! Actions implement the [`TaskAction`] trait to define operations like add, done,
//! delete, and undo. The system supports both CLI and API input paths, with
//! automatic undo tracking for reversible operations.
//!
//! # Action Lifecycle
//!
//! 1. Action is created via `ActionRegistry::get_action_from_command_parser()`
//! 2. Task data is injected via `set_tasks()`
//! 3. Input is provided via `set_arguments()` (CLI) or `set_properties()` (API)
//! 4. `do_action()` executes the operation and records undo entries
//! 5. Caller persists tasks and undo log
//!
//! # Creating a New Action
//!
//! 1. Create a struct with `base: BaseTaskAction` field
//! 2. Implement `TaskAction`, using `impl_taskaction_from_base!()` for boilerplate
//! 3. Implement `do_action()` with your logic
//! 4. Register in `action_type.rs`
//!
//! # Available Actions
//!
//! - **Lifecycle**: `AddTaskAction`, `DoneTaskAction`, `DeleteTaskAction`
//! - **Status**: `StartTaskAction`, `StopTaskAction`
//! - **Modify**: `EditTaskAction`, `ModifyTaskAction`, `AnnotateTaskAction`
//! - **Query**: `ListTaskAction`, `InfoTaskAction`
//! - **System**: `HelpTaskAction`, `UndoTaskAction`, `ImportTaskAction`, `ExportTaskAction`

pub mod command_parser;

mod action_type;

mod action_add;
mod action_annotate;
mod action_cmd;
mod action_delete;
mod action_done;
mod action_edit;
mod action_export;
mod action_help;
mod action_import;
mod action_info;
mod action_list;
mod action_modify;
mod action_start;
mod action_stop;
mod action_undo;

use crate::{action_type::ActionType, command_parser::ParsedCommand};
use bee_core::{
    CoreError, ErrorCode, Printer, UserFacingError,
    config::ReportConfig,
    task::{ActionUndo, ActionUndoType, TaskData, TaskProperties},
};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ActionError {
    #[error("Invalid action input: {message}")]
    Input { message: String },
    #[error("Action failed: {message}")]
    Execution { message: String },
    #[error(transparent)]
    Core(#[from] CoreError),
}

pub type ActionResult<T> = Result<T, ActionError>;

impl ActionError {
    pub fn input(message: impl Into<String>) -> Self {
        Self::Input {
            message: message.into(),
        }
    }

    pub fn execution(message: impl Into<String>) -> Self {
        Self::Execution {
            message: message.into(),
        }
    }
}

impl UserFacingError for ActionError {
    fn code(&self) -> ErrorCode {
        match self {
            ActionError::Input { .. } => ErrorCode::InvalidInput,
            ActionError::Execution { .. } => ErrorCode::ActionError,
            ActionError::Core(err) => err.code(),
        }
    }

    fn user_message(&self) -> String {
        match self {
            ActionError::Input { .. } => "That action input was not valid.".to_string(),
            ActionError::Execution { .. } => "That action could not be completed.".to_string(),
            ActionError::Core(err) => err.user_message(),
        }
    }

    fn developer_message(&self) -> String {
        match self {
            ActionError::Core(err) => err.developer_message(),
            _ => self.to_string(),
        }
    }
}

/// Interface for task manipulation commands.
///
/// Actions receive input through two paths:
/// - **CLI path**: Raw string arguments via `set_arguments()`, parsed in `do_action()`
/// - **API path**: Structured `TaskProperties` via `set_properties()`
///
/// Use `BaseTaskAction::get_properties_or_parse()` to handle both paths uniformly—it
/// returns the structured properties if set, otherwise parses from arguments.
///
/// # Undo Support
///
/// Actions that modify tasks should record undo entries. The undo vector is managed
/// by the caller—use `set_undos()` to receive existing entries and `get_undos()` to
/// return updated entries after execution.
pub trait TaskAction: Send {
    /// Execute the action's logic.
    ///
    /// This method should:
    /// 1. Parse input from arguments or properties
    /// 2. Modify tasks in `self.tasks` as needed
    /// 3. Record undo entries for reversible changes
    /// 4. Use `printer` to output results to the user
    fn do_action(&mut self, printer: &dyn Printer) -> ActionResult<()>;

    /// Set the undo history from previous actions.
    fn set_undos(&mut self, undos: Vec<ActionUndo>);

    /// Get the undo history (including any new entries from this action).
    fn get_undos(&self) -> &Vec<ActionUndo>;

    /// Set the task data this action will operate on.
    fn set_tasks(&mut self, tasks: TaskData);

    /// Get a reference to the task data.
    fn get_tasks(&self) -> &TaskData;

    /// Set raw CLI arguments to be parsed in `do_action()`.
    fn set_arguments(&mut self, arguments: Vec<String>);

    /// Set structured task properties (bypasses argument parsing).
    fn set_properties(&mut self, properties: TaskProperties);

    /// Set the report configuration for output formatting.
    fn set_report(&mut self, report: ReportConfig);
}

#[derive(Default)]
pub struct ActionRegistry;

impl ActionRegistry {
    pub fn get_parsed_commands() -> Vec<ParsedCommand> {
        let mut v = Vec::new();
        for data in ActionType::as_dict().values() {
            for alias in &data.parsed_string {
                v.push(ParsedCommand {
                    command: alias.to_string(),
                    arguments_as_filters: data.use_arguments_as_filter,
                    ..Default::default()
                })
            }
        }
        v
    }

    pub fn get_action_from_command_parser(cp: &ParsedCommand) -> Box<dyn TaskAction> {
        let mut action: Box<dyn TaskAction> = ActionType::get_action_from_name(cp.command.as_str());
        action.set_arguments(cp.arguments.clone());
        action.set_report(cp.report_kind.clone());
        action
    }
}

/// Shared state container for action implementations.
///
/// Provides storage for tasks, undo entries, arguments, properties, and report config.
/// Most actions should embed this struct and use [`impl_taskaction_from_base!`] to
/// generate the boilerplate trait methods.
///
/// # Key Methods
///
/// - `get_properties_or_parse()`: Returns structured properties if set, otherwise
///   parses from raw arguments. Handles both CLI and API input paths.
/// - `set_tasks()` / `get_tasks()`: Access the task data being operated on
/// - `set_undos()` / `get_undos()`: Access the undo history
#[derive(Default)]
pub struct BaseTaskAction {
    tasks: TaskData,
    undos: Vec<ActionUndo>,
    arguments: Vec<String>,
    report: ReportConfig,
    properties: Option<TaskProperties>,
}

impl BaseTaskAction {
    /// Set structured task properties for non-CLI callers.
    pub fn set_properties(&mut self, properties: TaskProperties) {
        self.properties = Some(properties);
    }

    /// Return structured task properties if present.
    pub fn get_properties(&self) -> Option<TaskProperties> {
        self.properties.clone()
    }

    /// Return structured task properties or parse them from arguments.
    pub fn get_properties_or_parse(&self) -> ActionResult<TaskProperties> {
        if let Some(properties) = &self.properties {
            return Ok(properties.clone());
        }
        TaskProperties::from(&self.arguments).map_err(ActionError::from)
    }

    pub fn set_arguments(&mut self, arguments: Vec<String>) {
        self.arguments = arguments;
    }

    pub fn set_report(&mut self, report: ReportConfig) {
        self.report = report.clone();
    }

    pub fn set_tasks(&mut self, tasks: TaskData) {
        self.tasks = tasks;
    }

    pub fn get_tasks(&self) -> &TaskData {
        &self.tasks
    }

    pub fn set_undos(&mut self, undos: Vec<ActionUndo>) {
        self.undos = undos;
    }

    pub fn get_undos(&self) -> &Vec<ActionUndo> {
        &self.undos
    }
}

mod macros {
    /// Generate `TaskAction` trait method implementations that delegate to `self.base`.
    ///
    /// Generates: `set_undos`, `get_undos`, `set_tasks`, `get_tasks`, `set_report`,
    /// `set_arguments`, `set_properties`.
    ///
    /// The caller must still implement `do_action()` with the actual action logic.
    #[macro_export]
    macro_rules! impl_taskaction_from_base {
        () => {
            fn set_undos(&mut self, undos: Vec<ActionUndo>) {
                self.base.set_undos(undos)
            }
            fn get_undos(&self) -> &Vec<ActionUndo> {
                self.base.get_undos()
            }
            fn set_tasks(&mut self, tasks: TaskData) {
                self.base.set_tasks(tasks)
            }
            fn get_tasks(&self) -> &TaskData {
                &self.base.get_tasks()
            }
            fn set_report(&mut self, report: bee_core::config::ReportConfig) {
                self.base.set_report(report);
            }
            fn set_arguments(&mut self, arguments: Vec<String>) {
                self.base.set_arguments(arguments);
            }
            fn set_properties(&mut self, properties: bee_core::task::TaskProperties) {
                self.base.set_properties(properties);
            }
        };
    }
}

#[cfg(test)]
mod tests {
    use super::BaseTaskAction;
    use bee_core::task::TaskProperties;

    #[test]
    fn test_get_properties_or_parse_prefers_structured() {
        let mut base = BaseTaskAction::default();
        let props = TaskProperties::from(&["hello".to_string()]).unwrap();
        base.set_properties(props.clone());

        let parsed = base.get_properties_or_parse().unwrap();
        assert_eq!(parsed, props);
    }

    #[test]
    fn test_get_properties_or_parse_from_arguments() {
        let mut base = BaseTaskAction::default();
        base.set_arguments(vec!["hello".to_string()]);

        let parsed = base.get_properties_or_parse().unwrap();
        let expected = TaskProperties::from(&["hello".to_string()]).unwrap();
        assert_eq!(parsed, expected);
    }
}
