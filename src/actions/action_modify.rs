use uuid::Uuid;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::task::{Task, TaskProperties};
use crate::Printer;

use crate::task::TaskData;

#[derive(Default)]
pub struct ModifyTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for ModifyTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, p: &dyn Printer) {
        let props = TaskProperties::from(&self.base.arguments);
        let mut undos: Vec<Task> = Vec::default();

        let uuids_to_modify: Vec<Uuid> = self
            .base
            .tasks
            .get_task_map()
            .keys()
            .map(|u| u.to_owned())
            .collect();
        for uuid in uuids_to_modify {
            let t = self.base.tasks.get_task_map().get(&uuid).unwrap();
            undos.push(t.to_owned());
            match t.get_id() {
                Some(id) => {
                    p.show_information_message(&format!("Modified Task {}.", id));
                }
                None => {
                    p.show_information_message(&format!("Modified Task {}.", t.get_uuid()));
                }
            }
            self.base.tasks.apply(&uuid, &props);
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
