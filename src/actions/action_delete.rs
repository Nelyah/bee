use uuid::Uuid;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::Printer;

use crate::task::{Task, TaskData};
use std::collections::HashMap;

#[derive(Default)]
pub struct DeleteTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for DeleteTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, p: &dyn Printer) -> Result<(), String> {
        let mut undos: HashMap<Uuid, Task> = HashMap::default();
        if self.base.tasks.get_task_map().is_empty() {
            p.show_information_message(" No task to complete.");
            return Ok(());
        }
        let uuids_to_deleted: Vec<Uuid> = self
            .base
            .tasks
            .get_task_map()
            .keys()
            .map(|u| u.to_owned())
            .collect();
        for uuid in uuids_to_deleted {
            let task_before = self.base.tasks.get_task_map().get(&uuid).unwrap().clone();
            self.base.tasks.task_delete(&uuid);
            let t = self.base.tasks.get_task_map().get(&uuid).unwrap();
            if task_before != *t {
                undos.insert(t.get_uuid().to_owned(), task_before.to_owned());
            }
            match t.get_id() {
                Some(id) => {
                    p.show_information_message(&format!("Deleted Task {}.", id));
                }
                None => {
                    p.show_information_message(&format!("Deleted Task {}.", t.get_uuid()));
                }
            }
        }
        if !undos.is_empty() {
            let mut extra_uuids: Vec<Uuid> = [
                undos
                    .values()
                    .flat_map(|t| t.get_extra_uuid())
                    .collect::<Vec<_>>(),
                self.base
                    .tasks
                    .get_extra_tasks()
                    .keys()
                    .map(|uuid| uuid.to_owned())
                    .collect::<Vec<_>>(),
            ]
            .concat();
            extra_uuids.sort_unstable();
            extra_uuids.dedup();
            for uuid in extra_uuids {
                if let Some(task) = self.base.tasks.get_extra_tasks().get(&uuid) {
                    // Do not overwrite the tasks if they're already in the undos
                    if undos.contains_key(&uuid) {
                        undos.insert(uuid.to_owned(), task.to_owned());
                    }
                }
            }
            self.base.undos.push(ActionUndo {
                action_type: super::ActionUndoType::Modify,
                tasks: undos.into_values().collect(),
            });
        }
        Ok(())
    }
    fn get_command_description(&self) -> String {
        "Delete a task".to_string()
    }
}
