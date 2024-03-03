use crate::task::Task;
use serde::{Deserialize, Serialize};

use crate::config::ReportConfig;
use crate::parse::command_parser::ParsedCommand;
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

use crate::filters::Filter;
use crate::task::TaskData;

#[derive(Default)]
pub struct BaseTaskAction {
    tasks: TaskData,
    undos: Vec<ActionUndo>,
    filters: Filter,
    arguments: Vec<String>,
    report: ReportConfig,
}

impl BaseTaskAction {
    pub fn set_filters(&mut self, filters: Filter) {
        self.filters = filters;
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

pub trait TaskAction {
    fn pre_action_hook(&self);
    fn do_action(&mut self, printer: &dyn Printer);
    fn post_action_hook(&self);
    fn get_command_description(&self) -> String;
    fn set_undos(&mut self, undos: Vec<ActionUndo>);
    fn get_undos(&self) -> &Vec<ActionUndo>;
    fn set_tasks(&mut self, tasks: TaskData);
    fn get_tasks(&self) -> &TaskData;
    fn set_filters(&mut self, filters: Filter);
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
        fn set_filters(&mut self, filters: Filter) {
            self.base.set_filters(filters);
        }
        fn set_arguments(&mut self, arguments: Vec<String>) {
            self.base.set_arguments(arguments);
        }
    };
}

pub struct ActionRegisty {
    registered_type: Vec<ActionType>,
}

enum ActionType {
    List,
    Add,
    Undo,
}

impl ActionType {
    pub fn to_string_vec(&self) -> Vec<String> {
        match self {
            Self::List => vec!["list".to_string()],
            Self::Add => vec!["add".to_string()],
            Self::Undo => vec!["undo".to_string()],
        }
    }

    pub fn use_arguments_as_filter(&self) -> bool {
        match self {
            Self::List => true,
            Self::Add => false,
            Self::Undo => false,
        }
    }
}

impl Default for ActionRegisty {
    fn default() -> Self {
        ActionRegisty {
            registered_type: vec![ActionType::List, ActionType::Add, ActionType::Undo],
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
        let mut action: Box<dyn TaskAction> = match cp.command.as_str() {
            "list" => Box::new(action_list::ListTaskAction {
                base: BaseTaskAction::default(),
            }),
            "add" => Box::new(action_add::AddTaskAction {
                base: BaseTaskAction::default(),
            }),
            "undo" => Box::new(action_undo::UndoTaskAction {
                base: BaseTaskAction::default(),
            }),
            _ => panic!("Invalid command parsed, could not get an action from it!"),
        };
        // let action = actions.get_mut(&cp.command).expect("Unknown command");
        action.set_filters(cp.filters.clone());
        action.set_arguments(cp.arguments.clone());
        action.set_report(cp.report_kind.clone());
        // action.clone()
        //
        action
    }
}

mod action_add;
mod action_list;
mod action_undo;
