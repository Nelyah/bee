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

pub trait TaskAction: Send {
    /// This is the main execution of the action. This is where it will affect
    /// the tasks it targets or call the printer
    fn do_action(&mut self, printer: &dyn Printer) -> ActionResult<()>;

    /// Setter for the ActionUndo vector
    fn set_undos(&mut self, undos: Vec<ActionUndo>);

    /// Getter for the ActionUndo vector
    fn get_undos(&self) -> &Vec<ActionUndo>;

    /// Setter for the TaskData this action will operate upon
    fn set_tasks(&mut self, tasks: TaskData);

    /// Get a reference to the task data contained in this action
    fn get_tasks(&self) -> &TaskData;

    /// Set the raw arguments from the command line
    fn set_arguments(&mut self, arguments: Vec<String>);

    /// Provide structured task properties for non-CLI callers.
    fn set_properties(&mut self, properties: TaskProperties);

    /// Set the report this action should use. This is important
    /// to decide how the printer should behave in some cases
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
