use std::collections::HashSet;

use crate::{ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base};

use bee_core::Printer;

use bee_core::task::TaskData;

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

fn get_tags_as_string(tasks: &TaskData) -> String {
    let mut s = HashSet::<&String>::default();
    for p in tasks
        .get_task_map()
        .values()
        .flat_map(|t| t.get_tags())
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
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        if self.base.arguments.is_empty() {
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
                "tags" => {
                    printer.print_raw(get_tags_as_string(&self.base.tasks).as_str());
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
}

impl CmdTaskAction {
    pub fn get_command_description() -> String {
        r#"Execute a specific command. This is used internally to populate autocompletion options.
<filters> are ignored.
<arguments> supported are as follow: get <projects|tags>
"#
        .to_string()
    }
}
