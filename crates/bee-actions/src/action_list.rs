use crate::{ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base};
use bee_core::Printer;

use bee_core::task::TaskData;

#[derive(Default)]
pub struct ListTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for ListTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        printer.print_list_of_tasks(self.base.get_tasks().to_vec(), &self.base.report)?;
        Ok(())
    }
}

impl ListTaskAction {
    pub fn get_command_description() -> String {
        r#"Show a list of tasks matched by <filter>
<arguments> are treated as filters.
"#
        .to_string()
    }
}
