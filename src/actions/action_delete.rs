use uuid::Uuid;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::Printer;

use crate::task::{Task, TaskData};

#[derive(Default)]
pub struct DeleteTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for DeleteTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, p: &dyn Printer) {
        let mut undos : Vec<Task> = Vec::default();
        if self.base.tasks.get_task_map().is_empty() {
            p.show_information_message(" No task to complete.");
            return;
        }
        let uuids_to_deleted: Vec<Uuid> = self
            .base
            .tasks
            .get_task_map()
            .keys()
            .map(|u| u.to_owned())
            .collect();
        for uuid in uuids_to_deleted {
            let t = self.base.tasks.get_task_map().get(&uuid).unwrap();
            undos.push(t.to_owned());
            match t.get_id() {
                Some(id) => {
                    p.show_information_message(&format!("Deleted Task {}.", id));
                }
                None => {
                    p.show_information_message(&format!("Deleted Task {}.", t.get_uuid()));
                }
            }
            self.base.tasks.task_delete(&uuid);
        }
        self.base.undos.push(ActionUndo {
            action_type: super::ActionUndoType::Modify,
            tasks: undos,
        });
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "foo bar".to_string()
    }
}
