use std::collections::HashMap;
use std::fmt;

use crate::task::Task;
use serde::{Deserialize, Serialize};

use crate::command_parser::ParsedCommand;
use crate::config::ReportConfig;
use crate::Printer;

#[derive(Default, Debug, PartialEq, Eq, Serialize, Deserialize, Clone)]
pub enum ActionUndoType {
    Add,
    #[default]
    Modify,
}

#[derive(Default, Serialize, Deserialize, Clone, Debug)]
pub struct ActionUndo {
    pub action_type: ActionUndoType,
    pub tasks: Vec<Task>,
}

use crate::task::TaskData;

#[derive(Default)]
pub struct BaseTaskAction {
    tasks: TaskData,
    undos: Vec<ActionUndo>,
    arguments: Vec<String>,
    report: ReportConfig,
}

impl BaseTaskAction {
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

pub trait TaskAction {
    /// This is the main execution of the action. This is where it will affect
    /// the tasks it targets or call the printer
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String>;

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

    /// Set the report this action should use. This is important
    /// to decide how the printer should behave in some cases
    fn set_report(&mut self, report: ReportConfig);
}

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
        fn set_report(&mut self, report: crate::config::ReportConfig) {
            self.base.set_report(report);
        }
        fn set_arguments(&mut self, arguments: Vec<String>) {
            self.base.set_arguments(arguments);
        }
    };
}

pub struct ActionRegisty {
    registered_type: Vec<ActionType>,
}

#[derive(Debug, PartialEq, Eq, Hash)]
enum ActionType {
    Annotate,
    Command,
    List,
    Start,
    Stop,
    Help,
    Info,
    Add,
    Undo,
    Export,
    Done,
    Delete,
    Modify,
}

/// This traits implement the name of the action type. This can potentially
/// differ from the string that the action matches
impl fmt::Display for ActionType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            ActionType::Annotate => "Annotate",
            ActionType::Command => "Command",
            ActionType::Start => "Start",
            ActionType::Stop => "Stop",
            ActionType::List => "List",
            ActionType::Help => "Help",
            ActionType::Info => "Info",
            ActionType::Add => "Add",
            ActionType::Undo => "Undo",
            ActionType::Export => "Export",
            ActionType::Done => "Done",
            ActionType::Delete => "Delete",
            ActionType::Modify => "Modify",
        };
        write!(f, "{}", s)
    }
}

impl ActionType {
    fn as_dict() -> HashMap<ActionType, Vec<String>> {
        // Make sure all cases are handled, if we had a new variant then this function should
        // fail to compile, hopefully we don't forget to add to the dictionary as well
        let a = ActionType::List;
        match a {
            ActionType::Add => (),
            ActionType::Annotate => (),
            ActionType::Command => (),
            ActionType::List => (),
            ActionType::Start => (),
            ActionType::Stop => (),
            ActionType::Help => (),
            ActionType::Info => (),
            ActionType::Export => (),
            ActionType::Undo => (),
            ActionType::Done => (),
            ActionType::Delete => (),
            ActionType::Modify => (),
        }
        let mut map = HashMap::new();

        map.insert(ActionType::List, vec!["list".to_string()]);
        map.insert(ActionType::Start, vec!["start".to_string()]);
        map.insert(ActionType::Stop, vec!["stop".to_string()]);
        map.insert(ActionType::Help, vec!["help".to_string()]);
        map.insert(ActionType::Info, vec!["info".to_string()]);
        map.insert(ActionType::Add, vec!["add".to_string()]);
        map.insert(ActionType::Command, vec!["_cmd".to_string()]);
        map.insert(ActionType::Annotate, vec!["annotate".to_string()]);
        map.insert(ActionType::Export, vec!["export".to_string()]);
        map.insert(ActionType::Undo, vec!["undo".to_string()]);
        map.insert(ActionType::Done, vec!["done".to_string()]);
        map.insert(ActionType::Delete, vec!["delete".to_string()]);
        map.insert(
            ActionType::Modify,
            vec!["modify".to_string(), "mod".to_string()],
        );

        map
    }

    fn from(s: &str) -> ActionType {
        let dict = ActionType::as_dict();
        for (key, value) in dict {
            if value.contains(&s.to_string()) {
                return key;
            }
        }

        unreachable!("Invalid string '{}' for ActionType", &s);
    }
    pub fn to_string_vec(&self) -> Vec<String> {
        ActionType::as_dict().get(self).unwrap().to_vec()
    }

    pub fn use_arguments_as_filter(&self) -> bool {
        match self {
            Self::List => true,
            Self::Start => true,
            Self::Stop => true,
            Self::Help => false,
            Self::Info => true,
            Self::Add => false,
            Self::Command => false,
            Self::Annotate => false,
            Self::Export => true,
            Self::Undo => false,
            Self::Done => false,
            Self::Delete => false,
            Self::Modify => false,
        }
    }
}

impl Default for ActionRegisty {
    fn default() -> Self {
        ActionRegisty {
            registered_type: vec![
                ActionType::List,
                ActionType::Start,
                ActionType::Stop,
                ActionType::Help,
                ActionType::Add,
                ActionType::Command,
                ActionType::Annotate,
                ActionType::Info,
                ActionType::Export,
                ActionType::Undo,
                ActionType::Done,
                ActionType::Delete,
                ActionType::Modify,
            ],
        }
    }
}

impl ActionRegisty {
    pub fn get_action_parsed_command(&self) -> Vec<ParsedCommand> {
        let mut v = Vec::new();
        for type_action in &self.registered_type {
            for alias in type_action.to_string_vec() {
                v.push(ParsedCommand {
                    command: alias,
                    arguments_as_filters: type_action.use_arguments_as_filter(),
                    ..Default::default()
                })
            }
        }
        v
    }

    fn get_command_descriptions(&self) -> HashMap<String, String> {
        let action_type_dict = ActionType::as_dict();
        let mut action_descriptions: HashMap<String, String> = HashMap::new();

        for action_type in action_type_dict.keys() {
            let description = match action_type {
                ActionType::List => action_list::ListTaskAction::get_command_description(),
                ActionType::Start => action_start::StartTaskAction::get_command_description(),
                ActionType::Stop => action_stop::StopTaskAction::get_command_description(),
                ActionType::Help => action_help::HelpTaskAction::get_command_description(),
                ActionType::Info => action_info::InfoTaskAction::get_command_description(),
                ActionType::Add => action_add::AddTaskAction::get_command_description(),
                ActionType::Command => action_cmd::CmdTaskAction::get_command_description(),
                ActionType::Export => action_export::ExportTaskAction::get_command_description(),
                ActionType::Undo => action_undo::UndoTaskAction::get_command_description(),
                ActionType::Done => action_done::DoneTaskAction::get_command_description(),
                ActionType::Delete => action_delete::DeleteTaskAction::get_command_description(),
                ActionType::Annotate => {
                    action_annotate::AnnotateTaskAction::get_command_description()
                }
                ActionType::Modify => action_modify::ModifyTaskAction::get_command_description(),
            };
            action_descriptions.insert(action_type.to_string(), description);
        }

        action_descriptions
    }

    fn get_action_from_name(&self, name: &str) -> Box<dyn TaskAction> {
        match ActionType::from(name) {
            ActionType::List => Box::new(action_list::ListTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Start => Box::new(action_start::StartTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Stop => Box::new(action_stop::StopTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Help => Box::new(action_help::HelpTaskAction {
                base: BaseTaskAction::default(),
                command_descriptions: self.get_command_descriptions(),
            }),
            ActionType::Info => Box::new(action_info::InfoTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Add => Box::new(action_add::AddTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Command => Box::new(action_cmd::CmdTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Export => Box::new(action_export::ExportTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Undo => Box::new(action_undo::UndoTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Done => Box::new(action_done::DoneTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Delete => Box::new(action_delete::DeleteTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Annotate => Box::new(action_annotate::AnnotateTaskAction {
                base: BaseTaskAction::default(),
            }),
            ActionType::Modify => Box::new(action_modify::ModifyTaskAction {
                base: BaseTaskAction::default(),
            }),
        }
    }

    pub fn get_action_from_command_parser(&self, cp: &ParsedCommand) -> Box<dyn TaskAction> {
        let mut action: Box<dyn TaskAction> = self.get_action_from_name(cp.command.as_str());
        action.set_arguments(cp.arguments.clone());
        action.set_report(cp.report_kind.clone());
        action
    }
}

mod action_add;
mod action_annotate;
mod action_cmd;
mod action_delete;
mod action_done;
mod action_export;
mod action_help;
mod action_info;
mod action_list;
mod action_modify;
mod action_start;
mod action_stop;
mod action_undo;
