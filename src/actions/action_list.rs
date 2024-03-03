use super::{ActionUndo, BaseTaskAction, TaskAction};
use crate::Printer;

use crate::filters::Filter;
use crate::task::TaskData;

pub struct ListTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for ListTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, printer: &dyn Printer) {
        printer.print_list_of_tasks(self.base.get_tasks().to_vec(), &self.base.report);
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "foo bar".to_string()
    }
}
