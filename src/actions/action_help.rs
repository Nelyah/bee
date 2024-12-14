use std::collections::HashMap;

use super::{ActionUndo, BaseTaskAction, TaskAction};
use crate::Printer;

use crate::task::TaskData;

/// Pass along command description to the printer so they can be shown
/// to the user. This is also responsible for adding more general documentation
/// about the tool in general (usage, description, etc.)
pub struct HelpTaskAction {
    pub base: BaseTaskAction,

    /// This is a map containing a mapping of Action name to
    /// action description, as it is implemented by them
    pub command_descriptions: HashMap<String, String>,
}

impl TaskAction for HelpTaskAction {
    impl_taskaction_from_base!();
    fn do_action(&mut self, printer: &dyn Printer) -> Result<(), String> {
        self.command_descriptions.insert(
            "header".to_string(),
            r#"
Rusk is a task management software.
Basic usage is: 

rusk <filter> <action_name> <arguments>

- <filter> restricts the tasks you will be applying the action onto.
- <action_name> defines what action is going to be performed on those tasks.
  This can be omitted. If it is omitted, then the default action is used.
  The default action is 'list' (which lists all the tasks matching the filter).
- <arguments> can be treated differently depending on the action. Refer to each action's
  help description for more information. (TODO)
"#.to_string());
        printer.show_help(&self.command_descriptions)?;
        Ok(())
    }
}

impl HelpTaskAction {
    pub fn get_command_description() -> String {
        "Show help".to_string()
    }
}
