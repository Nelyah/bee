use crate::{ActionUndo, ActionUndoType, BaseTaskAction, TaskAction, impl_taskaction_from_base};
use bee_core::Printer;
use bee_core::task::{Task, TaskData, TaskProperties, TaskStatus};

use log::info;

#[derive(Default)]
pub struct AddTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for AddTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        info!("Performing AddTaskAction");
        let props = TaskProperties::from(&self.base.arguments)?;

        // Clone here to avoid having multiple mutable borrows
        let new_task: Task = self
            .base
            .tasks
            .add_task(&props, TaskStatus::Pending)
            .unwrap()
            .clone();
        if let Some(new_id) = new_task.get_id() {
            printer.show_information_message(&format!("Created task {}.", new_id));
        } else if new_task.get_summary().len() > 15 {
            printer.show_information_message(&format!(
                "Logged task '{:.15}...'",
                new_task.get_summary()
            ));
        } else {
            printer.show_information_message(&format!(
                "Logged task '{:.15}'.",
                new_task.get_summary()
            ));
        }

        self.base.undos.push(ActionUndo {
            action_type: ActionUndoType::Add,
            tasks: vec![new_task.to_owned()],
        });
        Ok(())
    }
}

impl AddTaskAction {
    pub fn get_command_description() -> String {
        r#"Add a new task
<arguments> will define the task's summary, and potentially its properties as well
"#
        .to_string()
    }
}
