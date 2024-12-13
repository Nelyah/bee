use super::{ActionUndo, BaseTaskAction, TaskAction};
use crate::Printer;

use crate::task::TaskData;

pub struct ListTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for ListTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        printer.print_list_of_tasks(self.base.get_tasks().to_vec(), &self.base.report)?;
        Ok(())
    }
    fn get_command_description(&self) -> String {
        "Show a list of tasks".to_string()
    }
}
