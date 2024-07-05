use uuid::Uuid;

use super::{ActionUndo, ActionUndoType, BaseTaskAction, TaskAction};

use crate::Printer;

use crate::task::{Task, TaskData};

#[derive(Default)]
pub struct DoneTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for DoneTaskAction {
    impl_taskaction_from_base!();
    fn pre_action_hook(&self) {}
    fn do_action(&mut self, p: &dyn Printer) -> Result<(), String> {
        if self.base.tasks.get_task_map().is_empty() {
            p.show_information_message(" No task to complete.");
            return Ok(());
        }

        let mut undos: Vec<Task> = Vec::default();
        let uuids_to_complete: Vec<Uuid> = self
            .base
            .tasks
            .get_task_map()
            .keys()
            .map(|u| u.to_owned())
            .collect();
        for uuid in uuids_to_complete {
            let task_before = self.base.tasks.get_task_map().get(&uuid).unwrap().clone();
            self.base.tasks.task_done(&uuid);
            let t = self
                .base
                .tasks
                .get_task_map()
                .get(&uuid)
                .ok_or("Invalid UUID to modify".to_owned())?;
            if task_before != *t {
                undos.push(t.clone());
            }
            match t.get_id() {
                Some(id) => {
                    p.show_information_message(&format!("Completed Task {}.", id));
                }
                None => {
                    p.show_information_message(&format!("Completed Task {}.", t.get_uuid()));
                }
            }
        }

        if !undos.is_empty() {
            self.base.undos.push(ActionUndo {
                action_type: ActionUndoType::Modify,
                tasks: undos,
            });
        }
        Ok(())
    }
    fn post_action_hook(&self) {}
    fn get_command_description(&self) -> String {
        "Complete a task".to_string()
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

    fn init() {
        let _ = env_logger::builder().is_test(true).try_init();
    }

    impl Printer for MockPrinter {
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
        let mut action = DoneTaskAction::default();
        let printer = MockPrinter;

        let result = action.do_action(&printer);
        assert!(result.is_ok());
    }

    #[test]
    fn test_do_action_with_tasks() {
        init();
        let mut action = DoneTaskAction::default();
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

        // Check that the task was marked as done
        assert_eq!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task1.get_uuid())
                .unwrap()
                .get_status(),
            &TaskStatus::Completed
        );

        assert_eq!(action.base.undos.len(), 1);
        assert_eq!(action.base.undos.first().unwrap().tasks.len(), 2);
    }

    #[test]
    fn test_get_command_description() {
        let action = DoneTaskAction::default();
        assert_false!(action.get_command_description().is_empty());
    }
}
