use uuid::Uuid;

use crate::{ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base};

use bee_core::Printer;
use bee_core::task::{Task, TaskData, TaskProperties};

use std::collections::HashMap;

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

            // I "know" that I can expect Err here that is not fatal and should be given as
            // a warning.
            // TODO: Have a better Error handling with custom types
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

#[cfg(test)]
mod tests {
    use all_asserts::{assert_false, assert_true};

    use super::*;
    use bee_core::{
        Printer,
        config::ReportConfig,
        task::{Task, TaskData, TaskProperties, TaskStatus},
    };

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
        let mut action = StartTaskAction::default();
        let printer = MockPrinter;

        let result = action.do_action(&printer);
        assert!(result.is_ok());
    }

    #[test]
    fn test_do_action_with_tasks() {
        // Make sure we add something to the undo and that the task is correctly modified
        let mut action = StartTaskAction::default();
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
            &TaskStatus::Active
        );

        assert_eq!(action.base.undos.len(), 1);
        assert_eq!(action.base.undos.first().unwrap().tasks.len(), 1);
    }

    #[test]
    fn test_get_command_description() {
        assert_false!(StartTaskAction::get_command_description().is_empty());
    }
}
