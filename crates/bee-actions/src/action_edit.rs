use std::{
    collections::HashMap,
    env,
    fs::{self},
    io::Write,
    process::Command,
};

use crate::{ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base};
use bee_core::Printer;
use bee_core::task::{Task, TaskData, TaskProperties};

#[derive(Default)]
pub struct EditTaskAction {
    pub base: BaseTaskAction,
}

use tempfile::Builder;
use uuid::Uuid;

fn create_and_edit_json_file(input_serialised_tasks: &str) -> Result<TaskData, String> {
    // Create a temporary file path
    let mut temp_file = Builder::new()
        .suffix(".json")
        .tempfile()
        .map_err(|e| e.to_string())?;

    // Write some initial JSON content to the file
    temp_file
        .write_all(input_serialised_tasks.as_bytes())
        .map_err(|e| format!("Failed to write to file: {}", e))?;

    // Determine the editor to use
    let editor = env::var("EDITOR").unwrap_or_else(|_| "vim".to_string());

    // Open the file in the editor
    let status = Command::new(editor)
        .arg(temp_file.path().to_string_lossy().into_owned())
        .status()
        .expect("Failed to open editor");

    if !status.success() {
        return Err("Editor exited with an error".to_string());
    }

    let task_data: TaskData = serde_json::from_str(
        &fs::read_to_string(temp_file).map_err(|e| format!("Failed to read file: {}", e))?,
    )
    .map_err(|e| format!("Could not parse the modified file: {}", e))?;

    Ok(task_data)
}

/// This will construct a TaskProperties that will only contain the fields
/// that we are allowing to be modified (summary, annotations, tags, project)
fn get_task_property(old_task: &Task, new_task: &Task) -> TaskProperties {
    let mut props = TaskProperties::default();
    if new_task.get_summary() != old_task.get_summary() {
        props.set_summary(new_task.get_summary());
    }

    if new_task.get_tags() != old_task.get_tags() {
        let to_add: Vec<String> = new_task
            .get_tags()
            .iter()
            .filter(|item| !old_task.get_tags().contains(item))
            .cloned()
            .collect();

        let to_remove: Vec<String> = old_task
            .get_tags()
            .iter()
            .filter(|item| !new_task.get_tags().contains(item))
            .cloned()
            .collect();
        props.set_tag_add(&to_add);
        props.set_tag_remove(&to_remove);
    }

    if new_task.get_annotations() != old_task.get_annotations() {
        props.set_annotations(new_task.get_annotations());
    }

    if new_task.get_project() != old_task.get_project() {
        props.set_project(new_task.get_project());
    }

    props
}

impl EditTaskAction {
    fn do_action_impl(&mut self, printer: &dyn Printer, new_tasks: TaskData) -> Result<(), String> {
        let uuids_to_modify: Vec<Uuid> = self
            .base
            .tasks
            .get_task_map()
            .keys()
            .map(|u| u.to_owned())
            .collect();

        let mut task_were_modified = false;
        let mut undos: HashMap<Uuid, Task> = HashMap::default();

        for uuid in &uuids_to_modify {
            let props;
            {
                let old_task = match self.base.tasks.get_task_map().get(uuid) {
                    Some(task) => task,
                    None => {
                        return Err("An unexpected error happen when editing a task.".to_string());
                    }
                };
                let new_task = match new_tasks.get_task_map().get(uuid) {
                    Some(task) => task,
                    None => {
                        return Err("An unexpected error happen when editing a task. \
It is likely that an UUID was modified when editing tasks. \
Don't do that."
                            .to_string());
                    }
                };

                if new_task == old_task {
                    continue;
                }

                props = get_task_property(old_task, new_task);
                undos.insert(uuid.to_owned(), old_task.to_owned());
            }
            self.base.tasks.apply(uuid, &props)?;
            printer.show_information_message(&format!(
                "Modified task '{}'.",
                self.base
                    .tasks
                    .get_task_map()
                    .get(uuid)
                    .unwrap()
                    .get_summary()
            ));
            task_were_modified = true;
        }

        if !task_were_modified {
            printer.show_information_message("No change detected.");
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

impl TaskAction for EditTaskAction {
    impl_taskaction_from_base!();

    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        let new_tasks = create_and_edit_json_file(
            &serde_json::to_string_pretty(self.base.get_tasks()).unwrap(),
        )?;

        self.do_action_impl(printer, new_tasks)
    }
}

impl EditTaskAction {
    pub fn get_command_description() -> String {
        r#"Edit one or more tasks using an editor.
Only some fields can be edited (although all show in the JSON). The editable fields are:
- Summary
- annotations
- tags

The rest will be ignored.
"#
        .to_string()
    }
}

#[cfg(test)]
mod tests {
    use all_asserts::{assert_false, assert_true};
    use log::debug;

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
        let mut action = EditTaskAction::default();
        let printer = MockPrinter;

        let result = action.do_action_impl(&printer, TaskData::default());
        assert!(result.is_ok());
    }

    #[test]
    fn test_do_action_with_tasks() {
        // Make sure we add something to the undo and that the task is correctly modified
        let mut action = EditTaskAction::default();
        assert_true!(action.base.undos.is_empty());
        let printer = MockPrinter;

        // Add a task to the action
        let mut old_tasks = TaskData::default();
        let task1 = old_tasks
            .add_task(
                &TaskProperties::from(&["this is a task1 +old_tag".to_owned()]).unwrap(),
                TaskStatus::Active,
            )
            .unwrap()
            .clone();

        action.base.tasks = old_tasks.clone();

        let mut new_tasks = old_tasks.clone();
        let new_summary = "new task1 description".to_string();
        new_tasks
            .apply(
                task1.get_uuid(),
                &TaskProperties::from(&[new_summary.to_owned() + "+new_tag -old_tag"].to_owned())
                    .unwrap(),
            )
            .unwrap();

        let result = action.do_action_impl(&printer, new_tasks);
        if result.is_err() {
            debug!("After edit of the tasks: {}", result.clone().err().unwrap());
        }
        assert_true!(result.is_ok());

        assert_eq!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task1.get_uuid())
                .unwrap()
                .get_summary(),
            &new_summary
        );

        assert_true!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task1.get_uuid())
                .unwrap()
                .get_tags()
                .contains(&"new_tag".to_string())
        );
        assert_false!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task1.get_uuid())
                .unwrap()
                .get_tags()
                .contains(&"old_tag".to_string())
        );
        assert_eq!(action.base.undos.len(), 1);
    }

    #[test]
    fn test_do_action_no_modify() {
        // Make sure that everything is fine if we don't modify anything
        let mut action = EditTaskAction::default();
        assert_true!(action.base.undos.is_empty());
        let printer = MockPrinter;

        // Add a task to the action
        let mut old_tasks = TaskData::default();
        let task1 = old_tasks
            .add_task(
                &TaskProperties::from(&["this is a task1 +old_tag".to_owned()]).unwrap(),
                TaskStatus::Active,
            )
            .unwrap()
            .clone();

        action.base.tasks = old_tasks.clone();

        let new_tasks = old_tasks.clone();

        let result = action.do_action_impl(&printer, new_tasks);
        if result.is_err() {
            debug!("After edit of the tasks: {}", result.clone().err().unwrap());
        }
        assert_true!(result.is_ok());

        assert_eq!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task1.get_uuid())
                .unwrap()
                .get_summary(),
            &"this is a task1".to_string()
        );

        assert_false!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task1.get_uuid())
                .unwrap()
                .get_tags()
                .contains(&"new_tag".to_string())
        );
        assert_true!(
            action
                .base
                .tasks
                .get_task_map()
                .get(task1.get_uuid())
                .unwrap()
                .get_tags()
                .contains(&"old_tag".to_string())
        );
        assert_eq!(action.base.undos.len(), 0);
    }

    #[test]
    fn test_get_command_description() {
        assert_false!(EditTaskAction::get_command_description().is_empty());
    }
}
