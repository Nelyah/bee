use uuid::Uuid;

use super::{ActionUndo, BaseTaskAction, TaskAction};

use crate::task::{Task, TaskProperties};
use crate::Printer;
use std::collections::HashMap;

use crate::task::TaskData;

#[derive(Default)]
pub struct StopTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for StopTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, p: &dyn Printer) -> Result<(), String> {
        let mut props = TaskProperties::default();
        props.set_active_status(false);
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
            p.show_information_message(&format!("Stopped task '{}'.", t.get_summary()));
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

impl StopTaskAction {
    pub fn get_command_description() -> String {
        r#"Removes the 'ACTIVE' status of a task back to 'PENDING'. If a task was not 'ACTIVE', it has no effect.
<arguments> are ignored.
"#
        .to_string()
    }
}

#[cfg(test)]
mod tests {
    use all_asserts::{assert_false, assert_true};

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
        let mut action = StopTaskAction::default();
        let printer = MockPrinter;

        let result = action.do_action(&printer);
        assert!(result.is_ok());
    }

    #[test]
    fn test_do_action_with_tasks() {
        // Make sure we add something to the undo and that the task is correctly modified
        let mut action = StopTaskAction::default();
        assert_true!(action.base.undos.is_empty());
        let printer = MockPrinter;

        // Add a task to the action
        let mut tasks = TaskData::default();
        let task1 = tasks
            .add_task(
                &TaskProperties::from(&["this is a task1".to_owned()]).unwrap(),
                TaskStatus::Active,
            )
            .unwrap()
            .clone();

        let task2 = tasks
            .add_task(
                &TaskProperties::from(&["this is a task2".to_owned()]).unwrap(),
                TaskStatus::Pending,
            )
            .unwrap()
            .clone();

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
                .get_status(),
            &TaskStatus::Pending
        );

        assert_eq!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task2.get_uuid())
                .unwrap()
                .get_status(),
            &TaskStatus::Pending
        );

        assert_eq!(action.base.undos.len(), 1);

        // We only modified one task of the two (stopped the active one), so only that
        // task gets added to the undos
        assert_eq!(action.base.undos.first().unwrap().tasks.len(), 1);
    }

    #[test]
    fn test_get_command_description() {
        assert_false!(StopTaskAction::get_command_description().is_empty());
    }
}
