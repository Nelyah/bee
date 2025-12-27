use log::info;
use uuid::Uuid;

use crate::{ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base};

use bee_core::Printer;

use bee_core::task::{Task, TaskData};
use std::collections::HashMap;

#[derive(Default)]
pub struct DeleteTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for DeleteTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, p: &dyn Printer) -> Result<(), String> {
        info!("Performing DeleteTaskAction");
        let mut undos: HashMap<Uuid, Task> = HashMap::default();
        if self.base.tasks.get_task_map().is_empty() {
            p.show_information_message("No task to complete.");
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
                    p.show_information_message(&format!(
                        "Deleted Task {} '{}'.",
                        id,
                        t.get_summary()
                    ));
                }
                None => {
                    p.show_information_message(&format!("Deleted Task '{}'.", t.get_summary()));
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
}

impl DeleteTaskAction {
    pub fn get_command_description() -> String {
        r#"Delete a task
<arguments> are ignored for this action
"#
        .to_string()
    }
}

#[cfg(test)]
mod tests {
    use all_asserts::*;

    use super::*;
    use bee_core::Printer;
    use bee_core::config::ReportConfig;
    use bee_core::task::{Task, TaskData, TaskProperties, TaskStatus};

    struct MockPrinter;

    fn init() {
        let _ = env_logger::builder().is_test(true).try_init();
    }

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
        init();
        let mut action = DeleteTaskAction::default();
        let printer = MockPrinter;

        let result = action.do_action(&printer);
        assert!(result.is_ok());
    }

    #[test]
    fn test_do_action_with_tasks() {
        init();
        let mut action = DeleteTaskAction::default();
        assert_true!(action.base.undos.is_empty());
        let printer = MockPrinter;

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

        // Check that the task was marked as Deleted
        assert_eq!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task1.get_uuid())
                .unwrap()
                .get_status(),
            &TaskStatus::Deleted
        );

        assert_eq!(action.base.undos.len(), 1);
        assert_eq!(action.base.undos.first().unwrap().tasks.len(), 2);
    }

    #[test]
    fn test_get_command_description() {
        assert_false!(DeleteTaskAction::get_command_description().is_empty());
    }
}
