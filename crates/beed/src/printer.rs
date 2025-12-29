use crate::dto::ApiEvent;
use bee_core::{Printer, config::ReportConfig, task::Task};
use std::cell::RefCell;
use std::collections::HashMap;

/// A printer implementation that captures structured events for API responses.
pub struct JsonPrinter {
    events: RefCell<Vec<ApiEvent>>,
}

impl JsonPrinter {
    /// Create a new JSON printer instance.
    pub fn new() -> Self {
        Self {
            events: RefCell::new(Vec::new()),
        }
    }

    /// Drain captured events in insertion order.
    pub fn take_events(&self) -> Vec<ApiEvent> {
        self.events.take()
    }

    fn push_event(&self, event: ApiEvent) {
        self.events.borrow_mut().push(event);
    }
}

impl Printer for JsonPrinter {
    fn print_list_of_tasks(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
    ) -> Result<(), String> {
        self.push_event(ApiEvent::new(
            "list",
            format!(
                "listed {} tasks with {} columns",
                tasks.len(),
                report_kind.columns.len()
            ),
        ));
        Ok(())
    }

    fn print_task_info(&self, task: &Task) -> Result<(), String> {
        self.push_event(ApiEvent::new(
            "task_info",
            format!("task {}", task.get_uuid()),
        ));
        Ok(())
    }

    fn show_help(&self, help_section_description: &HashMap<String, String>) -> Result<(), String> {
        self.push_event(ApiEvent::new(
            "help",
            format!("{} help sections", help_section_description.len()),
        ));
        Ok(())
    }

    fn show_information_message(&self, message: &str) {
        self.push_event(ApiEvent::new("info", message));
    }

    fn error(&self, message: &str) {
        self.push_event(ApiEvent::new("error", message));
    }

    fn print_raw(&self, message: &str) {
        self.push_event(ApiEvent::new("raw", message));
    }
}
