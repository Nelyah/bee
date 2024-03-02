use super::common::{ActionUndo, ActionUndoType, BaseTaskAction, TaskAction};

use crate::Printer;

use crate::task::filters::Filter;
use crate::task::manager::TaskData;

#[derive(Default)]
pub struct UndoTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for UndoTaskAction {
    delegate_to_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, _: &dyn Printer) {
        let undos = self.get_undos().to_owned();
        for current_undo in undos.iter().rev() {
            for t in &current_undo.tasks {
                if !self.get_tasks().has_uuid(t.get_uuid()) {
                    panic!("Could not find task to undo: {}", t.get_uuid());
                }

                match current_undo.action_type {
                    ActionUndoType::Add => self.base.get_tasks_mut().task_delete(t.get_uuid()),
                    ActionUndoType::Modify => self.base.get_tasks_mut().set_task(t.to_owned()),
                }
            }
        }
        self.base.get_undos_mut().clear();
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "foo bar".to_string()
    }
}
