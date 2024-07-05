use uuid::Uuid;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::task::{Task, TaskProperties};
use crate::Printer;

use crate::task::TaskData;

#[derive(Default)]
pub struct AnnotateTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for AnnotateTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, p: &dyn Printer) -> Result<(), String> {
        let mut props = TaskProperties::default();
        props.set_annotate(self.base.arguments.join(" ").to_owned());

        let mut undos: Vec<Task> = Vec::default();

        let uuids_to_annotate: Vec<Uuid> = self
            .base
            .tasks
            .get_task_map()
            .keys()
            .map(|u| u.to_owned())
            .collect();
        for uuid in uuids_to_annotate {
            self.base.tasks.apply(&uuid, &props)?;
            let t = self
                .base
                .tasks
                .get_task_map()
                .get(&uuid)
                .ok_or("Invalid UUID to annotate".to_owned())?;
            undos.push(t.to_owned());
            match t.get_id() {
                Some(id) => {
                    p.show_information_message(&format!("Annotated task {}.", id));
                }
                None => {
                    p.show_information_message(&format!("Annotated task {}.", t.get_uuid()));
                }
            }
        }
        self.base.undos.push(ActionUndo {
            action_type: super::ActionUndoType::Modify,
            tasks: undos,
        });
        Ok(())
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "Annotate a task".to_string()
    }
}
