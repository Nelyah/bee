use crate::{ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base};
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

    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        let json_content = self.read_json_input()?;

        let imported_data: TaskData = serde_json::from_str(&json_content)
            .map_err(|e| format!("Failed to parse JSON: {}", e))?;

        let imported_tasks = imported_data.to_vec();
        let import_count = imported_tasks.len();

        for task in imported_tasks {
            self.base.tasks.add_task_object(task.clone());
        }

        printer.show_information_message(&format!("Imported {} task(s).", import_count));

        // No undo entries for bulk import as per spec
        Ok(())
    }
}

impl ImportTaskAction {
    /// Read JSON content from file path or stdin.
    fn read_json_input(&self) -> Result<String, String> {
        let source = self
            .base
            .arguments
            .first()
            .ok_or_else(|| "Import requires a file path or '-' for stdin".to_string())?;

        if source == "-" {
            // Read from stdin
            let mut buffer = String::new();
            io::stdin()
                .read_to_string(&mut buffer)
                .map_err(|e| format!("Failed to read from stdin: {}", e))?;
            Ok(buffer)
        } else {
            // Read from file
            std::fs::read_to_string(source)
                .map_err(|e| format!("Failed to read file '{}': {}", source, e))
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
