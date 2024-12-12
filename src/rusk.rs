mod actions;
mod command_parser;
mod config;
mod printer;
mod storage;
mod task;

use log::{debug, trace};
use std::process::exit;

use printer::cli::SimpleTaskTextPrinter;
use storage::{JsonStore, Store};

use crate::{actions::ActionRegisty, printer::cli::Printer, task::TaskProperties};

fn main() {
    env_logger::init();
    let undo_count = 1;

    match config::load_config() {
        Ok(_) => {}
        Err(msg) => {
            SimpleTaskTextPrinter.error(&msg);
            exit(1);
        }
    }

    let mut arg_parser = command_parser::Parser::default();
    let registry = ActionRegisty::default();
    for cmd in registry.get_action_parsed_command() {
        arg_parser.register_command_parser(cmd);
    }

    let mut command = match arg_parser.parse_command_line_arguments(std::env::args().collect()) {
        Ok(res) => res,
        Err(msg) => {
            SimpleTaskTextPrinter.error(&msg);
            exit(1);
        }
    };

    let undos = JsonStore::load_undos(undo_count);
    let undos_uuid: Vec<uuid::Uuid> = undos
        .iter()
        .flat_map(|x| x.tasks.iter().map(|y| *y.get_uuid()))
        .collect();

    debug!("Loaded {} undos", undos.len());
    trace!("Undos: {:?}", undos);
    trace!("Undo uuids: {:?}", undos_uuid);

    let mut props: Option<TaskProperties> = None;

    if !command.arguments_as_filters {
        match TaskProperties::from(&command.arguments) {
            Ok(props_from_args) => {
                props = Some(props_from_args);
            }
            Err(msg) => {
                SimpleTaskTextPrinter.error(&msg);
                exit(1);
            }
        }
    }

    let mut tasks = match JsonStore::load_tasks(Some(&command.filters), props) {
        Ok(t) => t,
        Err(msg) => {
            SimpleTaskTextPrinter.error(&msg);
            exit(1);
        }
    };
    command.filters.convert_id_to_uuid(tasks.get_id_to_uuid());

    for undo_action in &undos {
        tasks.set_undos(&undo_action.tasks);
    }

    let mut action = registry.get_action_from_command_parser(&command);
    action.set_tasks(tasks);
    action.set_undos(undos);
    match action.do_action(&SimpleTaskTextPrinter) {
        Ok(_) => {}
        Err(msg) => {
            SimpleTaskTextPrinter.error(&msg);
            exit(1);
        }
    }

    match JsonStore::write_tasks(action.get_tasks()) {
        Ok(_) => (),
        Err(msg) => {
            SimpleTaskTextPrinter.error(&msg);
            exit(1);
        }
    };
    JsonStore::log_undo(undo_count, action.get_undos().to_owned());
}
