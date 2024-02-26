use super::{ActionUndo, ActionUndoType, BaseTaskAction, TaskAction};

use crate::task::{Task, TaskStatus};
use crate::Printer;

use crate::task::TaskData;

#[derive(Default)]
pub struct AddTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for AddTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, printer: &dyn Printer) {
        let input_description = self.base.arguments.join(" ");

        // Clone here to avoid having multiple mutable borrows
        let new_task: Task = self
            .base
            .tasks
            .add_task(input_description.to_owned(), vec![], TaskStatus::Pending)
            .clone();
        if let Some(new_id) = new_task.get_id() {
            printer.show_information_message(&format!("Created task {}.", new_id));
        } else if input_description.len() > 15 {
            printer
                .show_information_message(&format!("Logged task '{:.15}...'", &input_description));
        } else {
            printer.show_information_message(&format!("Logged task '{:.15}'.", &input_description));
        }

        self.base.undos.push(ActionUndo {
            action_type: ActionUndoType::Add,
            tasks: vec![new_task.to_owned()],
        });
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "foo bar".to_string()
    }
}
