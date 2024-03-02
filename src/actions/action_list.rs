use super::common::{ActionUndo, BaseTaskAction, TaskAction};
use crate::Printer;

use crate::task::filters::Filter;
use crate::task::manager::TaskData;

pub struct NewTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for NewTaskAction {
    delegate_to_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, printer: &Box<dyn Printer>) {
        printer.print_list_of_tasks(self.base.get_tasks().to_vec(), self.base.get_report());
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "foo bar".to_string()
    }
}
