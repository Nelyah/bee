use super::{ActionUndo, BaseTaskAction, TaskAction};
use crate::Printer;

use crate::task::TaskData;

pub struct InfoTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for InfoTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        printer.print_list_of_tasks(self.base.get_tasks().to_vec(), &self.base.report)?;
        Ok(())
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "Show a list of tasks".to_string()
    }
}
