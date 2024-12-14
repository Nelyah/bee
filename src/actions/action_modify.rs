use log::debug;
use uuid::Uuid;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::task::{Task, TaskProperties};
use crate::Printer;
use std::collections::HashMap;

use crate::task::TaskData;

#[derive(Default)]
pub struct ModifyTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for ModifyTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, p: &dyn Printer) -> Result<(), String> {
        let props = TaskProperties::from(&self.base.arguments)?;
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
            self.base.tasks.apply(&uuid, &props)?;

            let t = self
                .base
                .tasks
                .get_task_map()
                .get(&uuid)
                .ok_or("Invalid UUID to modify".to_owned())?;
            if task_before != *t {
                undos.insert(t.get_uuid().to_owned(), task_before.to_owned());
            }
            match t.get_id() {
                Some(id) => {
                    p.show_information_message(&format!("Modified Task {}.", id));
                }
                None => {
                    p.show_information_message(&format!("Modified Task {}.", t.get_uuid()));
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

            debug!("extra UUID when modifying: {:?}", extra_uuids);
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
}

impl ModifyTaskAction {
    pub fn get_command_description() -> String {
        r#"Modify a task
<arguments> are used to define the fields that will be modified for this task.
By default, it will be its summary.
"#
        .to_string()
    }
}

#[cfg(test)]
mod tests {
    use all_asserts::*;

    use super::*;
    use crate::config::ReportConfig;
    use crate::task::{Task, TaskData, TaskProperties, TaskStatus};
    use crate::Printer;

    struct MockPrinter;

    impl Printer for MockPrinter {
        fn show_help(
            &self,
            _help_section_description: &HashMap<String, String>,
        ) -> Result<(), String> {
            Ok(())
        }
        fn print_task_info(&self, _task: &Task) -> Result<(), String> {
            Ok(())
        }
        fn print_raw(&self, _: &str) {}
        fn show_information_message(&self, _message: &str) {}
        fn error(&self, _: &str) {}

        fn print_list_of_tasks(&self, _: Vec<&Task>, _: &ReportConfig) -> Result<(), String> {
            Err("Not implemented".to_string())
        }
    }

    #[test]
    fn test_do_action_no_tasks() {
        let mut action = ModifyTaskAction::default();
        let printer = MockPrinter;

        let result = action.do_action(&printer);
        assert!(result.is_ok());
    }

    #[test]
    fn test_do_action_with_tasks() {
        let mut action = ModifyTaskAction::default();
        assert_true!(action.base.undos.is_empty());
        let printer = MockPrinter;
        action.base.arguments = vec!["new description".to_string()];

        // Add a task to the action
        let mut tasks = TaskData::default();
        let task1 = tasks
            .add_task(
                &TaskProperties::from(&["this is a task1".to_owned()]).unwrap(),
                TaskStatus::Pending,
            )
            .unwrap()
            .clone();

        tasks
            .add_task(
                &TaskProperties::from(&["this is a task2".to_owned()]).unwrap(),
                TaskStatus::Pending,
            )
            .unwrap();

        action.base.tasks = tasks;

        let result = action.do_action(&printer);
        assert!(result.is_ok());

        assert_eq!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task1.get_uuid())
                .unwrap()
                .get_summary(),
            "new description"
        );

        assert_eq!(action.base.undos.len(), 1);
        assert_eq!(action.base.undos.first().unwrap().tasks.len(), 2);
    }

    #[test]
    fn test_get_command_description() {
        assert_false!(ModifyTaskAction::get_command_description().is_empty());
    }
}
