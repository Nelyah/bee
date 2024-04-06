use std::collections::HashSet;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::Printer;

use crate::task::TaskData;

#[derive(Default)]
pub struct CmdTaskAction {
    pub base: BaseTaskAction,
}

fn get_projects_as_string(tasks: &TaskData) -> String {
    let mut s = HashSet::<&String>::default();
    for p in tasks
        .get_task_map()
        .values()
        .map(|t| t.get_project())
        .filter(|p| p.is_some())
        .map(|p| p.as_ref().unwrap().get_name())
        .collect::<Vec<&String>>()
    {
        s.insert(p);
    }
    s.iter()
        .map(|p| p.to_string())
        .collect::<Vec<_>>()
        .join("\n")
}

impl TaskAction for CmdTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        if self.base.arguments.first().is_none() {
            return Err("No argument found for TaskAction Cmd".to_string());
        }
        let do_get = self.base.arguments.first().unwrap().as_str() == "get";

        if !do_get {
            unimplemented!("Other commands than 'get' have not yet been implemented");
        }

        match self.base.arguments.get(1) {
            Some(a) => match a.as_str() {
                "projects" => {
                    printer.print_raw(get_projects_as_string(&self.base.tasks).as_str());
                }
                _ => {
                    return Err("TaskAction::Cmd: Not a valid field to request".to_string());
                }
            },
            None => {
                return Err("No argument found for command 'get'.".to_string());
            }
        }

        Ok(())
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "Add a new task".to_string()
    }
}
