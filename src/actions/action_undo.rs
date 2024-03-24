use super::{ActionUndo, ActionUndoType, BaseTaskAction, TaskAction};

use crate::Printer;

use crate::task::TaskData;

#[derive(Default)]
pub struct UndoTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for UndoTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, _: &dyn Printer) -> Result<(), String> {
        let undos = &self.base.undos;
        for current_undo in undos.iter().rev() {
            for t in &current_undo.tasks {
                if !self.get_tasks().has_uuid(t.get_uuid()) {
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
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "Undo the last operation".to_string()
    }
}
