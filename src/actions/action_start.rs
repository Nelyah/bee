use uuid::Uuid;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::task::{Task, TaskProperties};
use crate::Printer;
use std::collections::HashMap;

use crate::task::TaskData;

#[derive(Default)]
pub struct StartTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for StartTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, p: &dyn Printer) -> Result<(), String> {
        let mut props = TaskProperties::default();
        props.set_active_status(true);
        let mut undos: HashMap<Uuid, Task> = HashMap::default();

        let uuids_to_modify: Vec<Uuid> = self
            .base
            .tasks
            .get_task_map()
            .keys()
            .map(|u| u.to_owned())
            .collect();
        for uuid in uuids_to_modify {
            let task_before = self.base.tasks.get_task_map().get(&uuid).unwrap().clone();
            let res = self.base.tasks.apply(&uuid, &props);

            if let Some(err) = res.err() {
                p.show_information_message(err.as_str());
                continue;
            }

            let t = self
                .base
                .tasks
                .get_task_map()
                .get(&uuid)
                .ok_or("Invalid UUID to modify".to_owned())?;
            if task_before != *t {
                undos.insert(t.get_uuid().to_owned(), task_before.to_owned());
            }
            p.show_information_message(&format!("Started task '{}'.", t.get_summary()));
        }
        if !undos.is_empty() {
            self.base.undos.push(ActionUndo {
                action_type: super::ActionUndoType::Modify,
                tasks: undos.into_values().collect(),
            });
        }
        Ok(())
    }
}

impl StartTaskAction {
    pub fn get_command_description() -> String {
        r#"Changes the status of a task to 'ACTIVE'. This only affects tasks with 'PENDING' status. The rest is ignored.
<arguments> are ignored.
"#
        .to_string()
    }
}
