pub mod config;
pub mod filters;
pub mod task;

mod lexer;
mod parser;

use std::collections::HashMap;

use config::ReportConfig;
use task::Task;

pub trait Printer {
    fn print_list_of_tasks(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
    ) -> Result<(), String>;
    fn print_task_info(&self, task: &Task) -> Result<(), String>;

    /// Print the help for all the possible actions. This can also have a couple more named sections.
    ///
    /// @help_section_description: This is a map containing a mapping of Action name to
    /// action description, as it is implemented by them. It may also contain a section
    /// name to its content.
    fn show_help(&self, help_section_description: &HashMap<String, String>) -> Result<(), String>;
    fn show_information_message(&self, message: &str);
    fn error(&self, message: &str);

    /// This function is for developer purposes only. It might be used so the program outputs
    /// information to stdout or console.log, depending on the implementation
    fn print_raw(&self, message: &str);
}
