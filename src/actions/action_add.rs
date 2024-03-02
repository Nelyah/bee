use super::common::{ActionUndo, BaseTaskAction, TaskAction};
use crate::task::task::{Task, TaskStatus};
use crate::Printer;

use crate::task::filters::Filter;
use crate::task::manager::TaskData;

#[derive(Default)]
pub struct AddTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for AddTaskAction {
    delegate_to_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, printer: &Box<dyn Printer>) {
        let input_description = self.base.get_arguments().join(" ");

        let new_task: &Task = self.base.get_tasks_mut().add_task(
            input_description.to_owned(),
            vec![],
            TaskStatus::PENDING,
        );
        if let Some(new_id) = new_task.get_id() {
            printer.show_information_message(&format!("Created task {}.", new_id));
        } else {
            if input_description.len() > 15 {
                printer.show_information_message(&format!(
                    "Logged task '{:.15}...'",
                    &input_description
                ));
            } else {
                printer.show_information_message(&format!(
                    "Logged task '{:.15}'.",
                    &input_description
                ));
            }
        }
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "foo bar".to_string()
    }
}
