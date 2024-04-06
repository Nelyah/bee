use std::collections::HashMap;

use crate::task::Task;
use serde::{Deserialize, Serialize};

use crate::command_parser::ParsedCommand;
use crate::config::ReportConfig;
use crate::Printer;

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize, Clone)]
pub enum ActionUndoType {
    Add,
    Modify,
}

#[derive(Serialize, Deserialize, Clone)]
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
    fn pre_action_hook(&self);
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String>;
    fn post_action_hook(&self);
    fn get_command_description(&self) -> String;
    fn set_undos(&mut self, undos: Vec<ActionUndo>);
    fn get_undos(&self) -> &Vec<ActionUndo>;
    fn set_tasks(&mut self, tasks: TaskData);
    fn get_tasks(&self) -> &TaskData;
    fn set_arguments(&mut self, arguments: Vec<String>);
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
    Add,
    Undo,
    Export,
    Done,
    Delete,
    Modify,
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
            ActionType::Export => (),
            ActionType::Undo => (),
            ActionType::Done => (),
            ActionType::Delete => (),
            ActionType::Modify => (),
        }
        let mut map = HashMap::new();

        map.insert(ActionType::List, vec!["list".to_string()]);
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
                ActionType::Add,
                ActionType::Command,
                ActionType::Annotate,
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

    pub fn get_action_from_command_parser(&self, cp: &ParsedCommand) -> Box<dyn TaskAction> {
        let mut action: Box<dyn TaskAction> = match ActionType::from(cp.command.as_str()) {
            ActionType::List => Box::new(action_list::ListTaskAction {
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
        };
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
mod action_list;
mod action_modify;
mod action_undo;
