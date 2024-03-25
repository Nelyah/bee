use uuid::Uuid;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::Printer;

use crate::task::TaskData;

#[derive(Default)]
pub struct DoneTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for DoneTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, p: &dyn Printer) -> Result<(), String> {
        if self.base.tasks.get_task_map().is_empty() {
            p.show_information_message(" No task to complete.");
            return Ok(());
        }
        let uuids_to_complete: Vec<Uuid> = self
            .base
            .tasks
            .get_task_map()
            .keys()
            .map(|u| u.to_owned())
            .collect();
        for uuid in uuids_to_complete {
            let t = &self.base.tasks.get_task_map().get(&uuid).unwrap();
            match t.get_id() {
                Some(id) => {
                    p.show_information_message(&format!("Completed Task {}.", id));
                }
                None => {
                    p.show_information_message(&format!("Completed Task {}.", t.get_uuid()));
                }
            }
            self.base.tasks.task_done(&uuid);
        }
        self.base.tasks.upkeep();
        Ok(())
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "Complete a task".to_string()
    }
}
