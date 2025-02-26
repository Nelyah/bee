use crate::{ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base};
use bee_core::Printer;

use bee_core::task::TaskData;

#[derive(Default)]
pub struct InfoTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for InfoTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        for task in self.base.get_tasks().to_vec() {
            printer.print_task_info(task)?;
        }
        Ok(())
    }
}

impl InfoTaskAction {
    pub fn get_command_description() -> String {
        r#"Show information about tasks matched by <filters>.
This includes their modification history, their dependencies, due dates, etc.
<arguments> are treated as <filters> for this action.
"#
        .to_string()
    }
}
