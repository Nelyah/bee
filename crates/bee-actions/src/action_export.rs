use crate::{
    ActionError, ActionResult, ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base,
};
use bee_core::Printer;

use bee_core::task::TaskData;

#[derive(Default)]
pub struct ExportTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for ExportTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, printer: &dyn Printer) -> ActionResult<()> {
        let json = serde_json::to_string_pretty(self.base.get_tasks())
            .map_err(|err| ActionError::execution(format!("Failed to serialize tasks: {err}")))?;
        printer.show_information_message(&json);
        Ok(())
    }
}

impl ExportTaskAction {
    pub fn get_command_description() -> String {
        r#"Print the tasks as JSON format.
This is useful for scripting access to Bee.
Both <filters> and <arguments> are treated as filter
"#
        .to_string()
    }
}
