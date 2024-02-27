use crate::task::task::Task;
use serde::{Deserialize, Serialize};

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize, Clone)]
pub enum ActionUndoType {
    Add,
    Modify,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct ActionUndo {
    action_type: ActionUndoType,
    tasks: Vec<Task>,
}

// use crate::config;
// use crate::parser;
// use crate::printer;
use crate::task::filters::Filter;
use crate::task::manager::TaskData;


pub struct BaseTaskAction {
    tasks: TaskData,
    undos: Vec<ActionUndo>,
    command_name: String,
    command_description: String,
    filters: Filter,
    arguments: Vec<String>,
    // report: config::ReportConfig,
}


impl BaseTaskAction {
    pub fn set_filters(&mut self, filters: Filter) {
        self.filters = filters;
    }

    pub fn set_arguments(&mut self, arguments: Vec<String>) {
        self.arguments = arguments;
    }

    // pub fn set_report(&mut self, report: config::ReportConfig) {
    //     self.report = report;
    // }

    pub fn set_tasks(&mut self, tasks: TaskData) {
        self.tasks = tasks;
    }

    pub fn get_tasks(&self) -> &TaskData {
        &self.tasks
    }

    pub fn set_undos(&mut self, undos: Vec<ActionUndo>) {
        self.undos = undos;
    }

    pub fn get_undos(&self) -> &[ActionUndo] {
        &self.undos
    }

    pub fn get_filters(&self) -> &Filter {
        &self.filters
    }
}

pub trait TaskAction {
    fn pre_action_hook(&self);
    // fn do_action(&self, printer: &printer::Printer);
    fn post_action_hook(&self);
    fn get_command_names(&self) -> Vec<String>;
    fn get_command_description(&self) -> String;
    fn set_undos(&mut self, undos: Vec<ActionUndo>);
    fn get_undos(&self) -> &[ActionUndo];
    fn set_tasks(&mut self, tasks: TaskData);
    fn get_tasks(&self) -> &TaskData;
    fn get_filters(&self) -> &Filter;
}

// The code is used as soon as it is first acces, thanks to the Lazy library
// lazy_static! {
//     pub static ref NAME_TO_TASK_ACTION: Lazy<HashMap<String, Box<dyn TaskAction>>> = Lazy::new(|| {
//         let mut map = HashMap::new();
//         // You can initialize your HashMap here, for example:
//         // map.insert("action1".to_string(), Box::new(SomeTaskAction {}));
//         map
//     });
// }


// pub fn get_action_from_command_parser(cp: &parser::ParsedCommand) -> Box<dyn TaskAction> {
//     let mut actions = NAME_TO_TASK_ACTION.lock().unwrap();
//     let action = actions.get_mut(&cp.command).expect("Unknown command");
//     action.set_filters(cp.filters.clone());
//     action.set_arguments(cp.arguments.clone());
//     // action.set_report(cp.report_kind.clone());
//     action.clone()
// }

// pub fn register_action(p: &mut parser::Parser, action: Box<dyn TaskAction>, arg_as_filters: bool) {
//     for name in action.get_command_names() {
//         NAME_TO_TASK_ACTION.lock().unwrap().insert(name.clone(), action.clone());
//         p.register_command_parser(&name, &action.get_command_description(), arg_as_filters);
//     }
// }

// pub fn register_actions(p: &mut parser::Parser) {
//     register_action(p, Box::new(CompleteTaskAction::new()), false);
//     register_action(p, Box::new(CreateTaskAction::new()), false);
//     register_action(p, Box::new(ListTaskAction::new()), true);
//     register_action(p, Box::new(HelpTaskAction::new()), false);
//     register_action(p, Box::new(ModifyTaskAction::new()), false);
//     register_action(p, Box::new(UndoTaskAction::new()), false);
// }

