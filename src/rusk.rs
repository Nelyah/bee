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

use crate::{actions::ActionRegisty, printer::cli::Printer};

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

    let command = match arg_parser.parse_command_line_arguments(std::env::args().collect()) {
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

    let mut tasks = JsonStore::load_tasks(Some(command.filters.clone()).as_ref());

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

    // Order is important because we do upkeep in write_tasks and that potentially
    // adds some undo
    // FIXME: I do not want to have to return the entire TaskData here
    // A solution could be to have a JsonStore::Upkeep that would do the
    // upkeep instead of doing it in write_tasks and load_tasks
    tasks = JsonStore::write_tasks(action.get_tasks());
    let mut action_undos = action.get_undos().to_owned();
    if !action_undos.is_empty() {
        action_undos.last_mut().unwrap().tasks = [
            action_undos.last_mut().unwrap().tasks.clone(),
            tasks.get_undos_from_upkeep().to_vec(),
        ]
        .concat();
    }
    JsonStore::log_undo(undo_count, action_undos);
}
