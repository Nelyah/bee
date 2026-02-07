//! Profile management commands.
//!
//! Profile commands allow managing multiple isolated databases and configurations:
//! - `bee profile list` - List all profiles
//! - `bee profile show` - Show current profile info
//! - `bee profile create <name>` - Create a new profile
//! - `bee profile delete <name>` - Delete a profile
//! - `bee profile init <name>` - Initialize profile system with existing data

use crate::{ActionResult, ActionUndo, BaseTaskAction, TaskAction, impl_taskaction_from_base};
use bee_core::Printer;
use bee_core::profile;
use bee_core::task::TaskData;

/// Profile management action supporting multiple subcommands.
#[derive(Default)]
pub struct ProfileTaskAction {
    pub base: BaseTaskAction,
}

impl TaskAction for ProfileTaskAction {
    impl_taskaction_from_base!();

    fn do_action(&mut self, printer: &dyn Printer) -> ActionResult<()> {
        let args = &self.base.arguments;

        if args.is_empty() {
            return self.show_usage(printer);
        }

        let subcommand = args[0].as_str();
        let subargs: Vec<&str> = args.iter().skip(1).map(|s| s.as_str()).collect();

        match subcommand {
            "list" => self.do_list(printer),
            "show" => self.do_show(printer),
            "create" => self.do_create(printer, &subargs),
            "delete" => self.do_delete(printer, &subargs),
            "init" => self.do_init(printer, &subargs),
            _ => {
                printer.error(&format!("Unknown profile subcommand: {}", subcommand));
                self.show_usage(printer)
            }
        }
    }
}

impl ProfileTaskAction {
    fn show_usage(&self, printer: &dyn Printer) -> ActionResult<()> {
        printer.show_information_message(
            r#"Profile management commands:

  bee profile list              - List all configured profiles
  bee profile show              - Show current profile info and paths
  bee profile create <name>     - Create a new profile
  bee profile delete <name>     - Delete a profile (keeps data files)
  bee profile init <name>       - Initialize profile system with existing data

Profile names must be lowercase alphanumeric with hyphens (e.g., 'personal', 'work', 'my-project').

Environment:
  Set BEE_PROFILE=<name> to select the active profile for CLI commands.
"#,
        );
        Ok(())
    }

    fn do_list(&self, printer: &dyn Printer) -> ActionResult<()> {
        let profiles = profile::list_profiles()?;

        if profiles.is_empty() {
            printer.show_information_message(
                "No profiles configured. Run 'bee profile init <name>' to initialize.",
            );
            return Ok(());
        }

        let current_profile = profile::get_active_profile_from_env();

        printer.show_information_message("Configured profiles:");
        for (key, p) in profiles {
            let marker = if Some(&key) == current_profile.as_ref() {
                "*"
            } else {
                " "
            };
            let desc = if p.description.is_empty() {
                "".to_string()
            } else {
                format!(" - {}", p.description)
            };
            printer.show_information_message(&format!("  {} {}{}", marker, key, desc));
        }

        if current_profile.is_some() {
            printer.show_information_message("");
            printer.show_information_message("* = active profile (from BEE_PROFILE)");
        }

        Ok(())
    }

    fn do_show(&self, printer: &dyn Printer) -> ActionResult<()> {
        match profile::get_active_profile_from_env() {
            Some(name) => {
                let data_dir = profile::get_profile_data_dir(&name);
                let config_dir = profile::get_profile_config_dir(&name);
                let db_path = profile::get_profile_database_path(&name);
                let config_path = profile::get_profile_config_path(&name);

                printer.show_information_message(&format!("Active profile: {}", name));
                printer.show_information_message(&format!(
                    "  Data directory:   {}",
                    data_dir.display()
                ));
                printer.show_information_message(&format!(
                    "  Config directory: {}",
                    config_dir.display()
                ));
                printer.show_information_message(&format!(
                    "  Database:         {}",
                    db_path.display()
                ));
                printer.show_information_message(&format!(
                    "  Config file:      {}",
                    config_path.display()
                ));

                // Check if the profile is defined in profiles.toml
                if !profile::profile_exists(&name) {
                    printer.show_information_message("");
                    printer.show_information_message(
                        "Warning: This profile is not defined in profiles.toml.",
                    );
                    printer.show_information_message(
                        "  Run 'bee profile create <name>' to formally define it.",
                    );
                }
            }
            None => {
                printer.show_information_message("No profile active (BEE_PROFILE not set).");
                printer.show_information_message("");
                printer.show_information_message("To use profiles:");
                printer
                    .show_information_message("  1. Run 'bee profile init <name>' to initialize");
                printer.show_information_message("  2. Set BEE_PROFILE=<name> in your shell");
            }
        }
        Ok(())
    }

    fn do_create(&self, printer: &dyn Printer, args: &[&str]) -> ActionResult<()> {
        if args.is_empty() {
            printer.error("Profile name required. Usage: bee profile create <name>");
            return Ok(());
        }

        let name = args[0];

        // Parse optional --description flag
        let description = if args.len() > 2 && args[1] == "--description" {
            args[2..].join(" ")
        } else if args.len() > 1 {
            args[1..].join(" ")
        } else {
            String::new()
        };

        match profile::create_profile(name, &description) {
            Ok(()) => {
                printer.show_information_message(&format!("Created profile '{}'", name));
                printer.show_information_message(&format!(
                    "  Data:   {}",
                    profile::get_profile_data_dir(name).display()
                ));
                printer.show_information_message(&format!(
                    "  Config: {}",
                    profile::get_profile_config_dir(name).display()
                ));
                printer.show_information_message("");
                printer.show_information_message(&format!(
                    "To use this profile: export BEE_PROFILE={}",
                    name
                ));
            }
            Err(e) => {
                printer.error(&format!("Failed to create profile: {}", e));
            }
        }
        Ok(())
    }

    fn do_delete(&self, printer: &dyn Printer, args: &[&str]) -> ActionResult<()> {
        if args.is_empty() {
            printer.error("Profile name required. Usage: bee profile delete <name>");
            return Ok(());
        }

        let name = args[0];

        // Check if this is the active profile
        if let Some(active) = profile::get_active_profile_from_env()
            && active == name
        {
            printer.error(&format!(
                "Cannot delete the active profile '{}'. Unset BEE_PROFILE first.",
                name
            ));
            return Ok(());
        }

        match profile::delete_profile(name) {
            Ok(()) => {
                printer.show_information_message(&format!("Deleted profile '{}'", name));
                printer.show_information_message("");
                printer
                    .show_information_message("Note: Data files were NOT deleted. To remove them:");
                printer.show_information_message(&format!(
                    "  rm -rf {}",
                    profile::get_profile_data_dir(name).display()
                ));
                printer.show_information_message(&format!(
                    "  rm -rf {}",
                    profile::get_profile_config_dir(name).display()
                ));
            }
            Err(e) => {
                printer.error(&format!("Failed to delete profile: {}", e));
            }
        }
        Ok(())
    }

    fn do_init(&self, printer: &dyn Printer, args: &[&str]) -> ActionResult<()> {
        if args.is_empty() {
            printer.error("Profile name required. Usage: bee profile init <name>");
            return Ok(());
        }

        let name = args[0];

        // Parse optional --description flag
        let description = if args.len() > 2 && args[1] == "--description" {
            args[2..].join(" ")
        } else {
            String::new()
        };

        match profile::init_profile(name, &description) {
            Ok(()) => {
                printer.show_information_message("Profile system initialized!");
                printer.show_information_message(&format!("  Created profile: {}", name));
                printer.show_information_message(&format!(
                    "  Data:   {}",
                    profile::get_profile_data_dir(name).display()
                ));
                printer.show_information_message(&format!(
                    "  Config: {}",
                    profile::get_profile_config_dir(name).display()
                ));
                printer.show_information_message("");
                printer
                    .show_information_message("Existing data has been copied to the new profile.");
                printer.show_information_message("");
                printer.show_information_message("Next steps:");
                printer.show_information_message(&format!(
                    "  1. Add to your shell: export BEE_PROFILE={}",
                    name
                ));
                printer.show_information_message(
                    "  2. Create additional profiles: bee profile create work",
                );
                printer.show_information_message("  3. Verify data: bee list");
            }
            Err(e) => {
                printer.error(&format!("Failed to initialize profiles: {}", e));
            }
        }
        Ok(())
    }

    pub fn get_command_description() -> String {
        r#"Manage profiles for separate databases and configurations.

Subcommands:
  list              List all configured profiles
  show              Show current profile info and paths
  create <name>     Create a new profile
  delete <name>     Delete a profile
  init <name>       Initialize profile system with existing data

Examples:
  bee profile init personal        Initialize with a 'personal' profile
  bee profile create work          Create a 'work' profile
  export BEE_PROFILE=work          Switch to work profile
"#
        .to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Arc, Mutex};

    struct TestPrinter {
        messages: Arc<Mutex<Vec<String>>>,
        errors: Arc<Mutex<Vec<String>>>,
    }

    impl TestPrinter {
        fn new() -> Self {
            Self {
                messages: Arc::new(Mutex::new(Vec::new())),
                errors: Arc::new(Mutex::new(Vec::new())),
            }
        }

        fn get_messages(&self) -> Vec<String> {
            self.messages.lock().unwrap().clone()
        }

        fn get_errors(&self) -> Vec<String> {
            self.errors.lock().unwrap().clone()
        }
    }

    impl Printer for TestPrinter {
        fn print_list_of_tasks(
            &self,
            _tasks: Vec<&bee_core::task::Task>,
            _report_kind: &bee_core::config::ReportConfig,
        ) -> bee_core::CoreResult<()> {
            Ok(())
        }

        fn print_task_info(&self, _task: &bee_core::task::Task) -> bee_core::CoreResult<()> {
            Ok(())
        }

        fn show_help(
            &self,
            _help_section_description: &std::collections::HashMap<String, String>,
        ) -> bee_core::CoreResult<()> {
            Ok(())
        }

        fn show_information_message(&self, message: &str) {
            self.messages.lock().unwrap().push(message.to_string());
        }

        fn error(&self, message: &str) {
            self.errors.lock().unwrap().push(message.to_string());
        }

        fn print_raw(&self, _message: &str) {}
    }

    fn setup_test_env() -> (tempfile::TempDir, bee_core::profile::ProfilePathsGuard) {
        let tmp = tempfile::tempdir().unwrap();
        let config_home = tmp.path().join("config");
        let data_home = tmp.path().join("data");
        std::fs::create_dir_all(&config_home).unwrap();
        std::fs::create_dir_all(&data_home).unwrap();
        let guard = bee_core::profile::override_profile_paths(bee_core::profile::ProfilePaths {
            config_home,
            data_home,
        });
        (tmp, guard)
    }

    #[test]
    fn test_profile_action_no_args_shows_usage() {
        let (_tmp, _guard) = setup_test_env();
        let mut action = ProfileTaskAction::default();
        let printer = TestPrinter::new();

        action.do_action(&printer).unwrap();

        let messages = printer.get_messages();
        assert!(!messages.is_empty());
        assert!(messages[0].contains("Profile management commands"));
    }

    #[test]
    fn test_profile_action_unknown_subcommand() {
        let (_tmp, _guard) = setup_test_env();
        let mut action = ProfileTaskAction::default();
        action.base.set_arguments(vec!["unknown".to_string()]);
        let printer = TestPrinter::new();

        action.do_action(&printer).unwrap();

        let errors = printer.get_errors();
        assert!(!errors.is_empty());
        assert!(errors[0].contains("Unknown profile subcommand"));
    }

    #[test]
    fn test_profile_action_show_no_profile() {
        let (_tmp, _guard) = setup_test_env();
        let mut action = ProfileTaskAction::default();
        action.base.set_arguments(vec!["show".to_string()]);
        let printer = TestPrinter::new();

        // Ensure BEE_PROFILE is not set
        // SAFETY: This test runs single-threaded and doesn't depend on BEE_PROFILE being set elsewhere
        unsafe {
            std::env::remove_var("BEE_PROFILE");
        }

        action.do_action(&printer).unwrap();

        let messages = printer.get_messages();
        assert!(!messages.is_empty());
        assert!(messages[0].contains("No profile active"));
    }

    #[test]
    fn test_profile_action_create_no_name() {
        let (_tmp, _guard) = setup_test_env();
        let mut action = ProfileTaskAction::default();
        action.base.set_arguments(vec!["create".to_string()]);
        let printer = TestPrinter::new();

        action.do_action(&printer).unwrap();

        let errors = printer.get_errors();
        assert!(!errors.is_empty());
        assert!(errors[0].contains("Profile name required"));
    }

    #[test]
    fn test_profile_action_delete_no_name() {
        let (_tmp, _guard) = setup_test_env();
        let mut action = ProfileTaskAction::default();
        action.base.set_arguments(vec!["delete".to_string()]);
        let printer = TestPrinter::new();

        action.do_action(&printer).unwrap();

        let errors = printer.get_errors();
        assert!(!errors.is_empty());
        assert!(errors[0].contains("Profile name required"));
    }

    #[test]
    fn test_profile_action_init_no_name() {
        let (_tmp, _guard) = setup_test_env();
        let mut action = ProfileTaskAction::default();
        action.base.set_arguments(vec!["init".to_string()]);
        let printer = TestPrinter::new();

        action.do_action(&printer).unwrap();

        let errors = printer.get_errors();
        assert!(!errors.is_empty());
        assert!(errors[0].contains("Profile name required"));
    }
}
