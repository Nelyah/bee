use crate::{
    ActionError, ActionResult, ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base,
};
use bee_core::Printer;
use bee_core::task::TaskData;
use std::io::{self, Read};

/// Import tasks from a JSON file or stdin.
///
/// Usage:
/// - `bee import <file_path>` - Import from a file
/// - `bee import -` - Import from stdin
#[derive(Default)]
pub struct ImportTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for ImportTaskAction {
    impl_taskaction_from_base!();

    fn do_action(&mut self, printer: &dyn Printer) -> ActionResult<()> {
        let json_content = self.read_json_input()?;

        let imported_data: TaskData = serde_json::from_str(&json_content)
            .map_err(|err| ActionError::execution(format!("Failed to parse JSON: {err}")))?;

        let imported_tasks = imported_data.to_vec();
        let import_count = imported_tasks.len();

        // Collect tasks for undo entry so they get persisted by write_tasks
        let mut undo_tasks = Vec::new();

        for task in imported_tasks {
            let owned_task = task.clone();
            undo_tasks.push(owned_task.clone());
            self.base.tasks.add_task_object(owned_task);
        }

        printer.show_information_message(&format!("Imported {} task(s).", import_count));

        // Create undo entry so tasks get persisted by write_tasks
        // (write_tasks only persists tasks that appear in undo entries)
        if !undo_tasks.is_empty() {
            self.base.undos.push(ActionUndo {
                action_type: bee_core::task::ActionUndoType::Add,
                tasks: undo_tasks,
            });
        }

        Ok(())
    }
}

impl ImportTaskAction {
    /// Read JSON content from file path or stdin.
    fn read_json_input(&self) -> ActionResult<String> {
        let source =
            self.base.arguments.first().ok_or_else(|| {
                ActionError::input("Import requires a file path or '-' for stdin")
            })?;

        if source == "-" {
            // Read from stdin
            let mut buffer = String::new();
            io::stdin().read_to_string(&mut buffer).map_err(|err| {
                ActionError::execution(format!("Failed to read from stdin: {err}"))
            })?;
            Ok(buffer)
        } else {
            // Read from file
            std::fs::read_to_string(source).map_err(|err| {
                ActionError::execution(format!("Failed to read file '{source}': {err}"))
            })
        }
    }

    pub fn get_command_description() -> String {
        r#"Import tasks from a JSON file.
Usage: bee import <file_path>
       bee import -  (read from stdin)

The JSON format should match the export format (TaskData serialized as JSON).
"#
        .to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use bee_core::{CoreResult, Printer, config::ReportConfig, task::Task};
    use std::collections::HashMap;

    struct MockPrinter {
        messages: std::cell::RefCell<Vec<String>>,
    }

    impl MockPrinter {
        fn new() -> Self {
            Self {
                messages: std::cell::RefCell::new(Vec::new()),
            }
        }
    }

    impl Printer for MockPrinter {
        fn show_help(&self, _: &HashMap<String, String>) -> CoreResult<()> {
            Ok(())
        }
        fn print_task_info(&self, _: &Task) -> CoreResult<()> {
            Ok(())
        }
        fn print_raw(&self, _: &str) {}
        fn show_information_message(&self, message: &str) {
            self.messages.borrow_mut().push(message.to_string());
        }
        fn error(&self, _: &str) {}
        fn print_list_of_tasks(&self, _: Vec<&Task>, _: &ReportConfig) -> CoreResult<()> {
            Ok(())
        }
    }

    #[test]
    fn test_import_creates_undo_entries() {
        let json = r#"[
            {
                "uuid": "e2d9a2be-192b-4edf-b984-3e19fa0f432c",
                "status": "Pending",
                "summary": "Test task",
                "date_created": "2025-09-03T09:36:39.225711+02:00"
            }
        ]"#;

        // Create temp file with JSON
        let temp_dir = std::env::temp_dir();
        let temp_file = temp_dir.join("test_import.json");
        std::fs::write(&temp_file, json).unwrap();

        let mut action = ImportTaskAction::default();
        action
            .base
            .set_arguments(vec![temp_file.to_string_lossy().to_string()]);

        let printer = MockPrinter::new();
        action.do_action(&printer).unwrap();

        // Verify undo entries were created
        assert!(
            !action.base.undos.is_empty(),
            "Import should create undo entries for persistence"
        );
        assert_eq!(action.base.undos.len(), 1, "Should have one undo entry");
        assert_eq!(
            action.base.undos[0].tasks.len(),
            1,
            "Undo should contain the imported task"
        );

        std::fs::remove_file(temp_file).ok();
    }

    #[test]
    fn test_import_requires_argument() {
        let mut action = ImportTaskAction::default();
        // No arguments set
        let printer = MockPrinter::new();

        let result = action.do_action(&printer);
        assert!(result.is_err());
        // Should be an Input error
        match result.unwrap_err() {
            ActionError::Input { .. } => (),
            _ => panic!("Expected Input error"),
        }
    }

    #[test]
    fn test_get_command_description() {
        assert!(!ImportTaskAction::get_command_description().is_empty());
    }
}
