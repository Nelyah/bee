use uuid::Uuid;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::Printer;

use crate::filters::Filter;
use crate::task::TaskData;

#[derive(Default)]
pub struct DeleteTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for DeleteTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, p: &dyn Printer) {
        if self.base.tasks.get_task_map().is_empty() {
            p.show_information_message(" No task to complete.");
            return;
        }
        let uuids_to_complete: Vec<Uuid> = self
            .base
            .tasks
            .get_task_map()
            .keys()
            .map(|u| u.to_owned())
            .collect();
        for uuid in uuids_to_complete {
            p.show_information_message(&format!(
                "Deleted task {}.",
                &self
                    .base
                    .tasks
                    .get_task_map()
                    .get(&uuid)
                    .unwrap()
                    .get_uuid()
            ));
            self.base.tasks.task_delete(&uuid);
        }
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "foo bar".to_string()
    }
}
