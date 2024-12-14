use super::{ActionUndo, ActionUndoType, BaseTaskAction, TaskAction};

use crate::Printer;

use crate::task::TaskData;

#[derive(Default)]
pub struct UndoTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for UndoTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, _: &dyn Printer) -> Result<(), String> {
        let undos = &self.base.undos;
        for current_undo in undos.iter().rev() {
            for t in &current_undo.tasks {
                if !self.get_tasks().get_undos().contains_key(t.get_uuid()) {
                    return Err(format!("Could not find task to undo: {}", t.get_uuid()));
                }

                match current_undo.action_type {
                    ActionUndoType::Add => self.base.tasks.task_delete(t.get_uuid()),
                    ActionUndoType::Modify => self.base.tasks.set_task(t.to_owned()),
                }
            }
        }
        self.base.undos.clear();
        Ok(())
    }
}

impl UndoTaskAction {
    pub fn get_command_description() -> String {
        r#"Undo the last operation
Both <filter> and <arguments> will be ignored.
"#
        .to_string()
    }
}
