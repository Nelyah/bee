pub mod actions;
mod config;
pub mod filters;
pub mod parse;
pub mod printer;
pub mod storage;
pub mod task;

use printer::cli::SimpleTaskTextPrinter;
use storage::{JsonStore, Store};

use crate::{actions::common::ActionRegisty, printer::cli::Printer};

fn main() {
    env_logger::init();
    let undo_count = 1;

    let mut arg_parser = parse::command_parser::Parser::default();
    let registry = ActionRegisty::default();
    for cmd in registry.get_action_parsed_command() {
        arg_parser.register_command_parser(cmd);
    }

    let command = arg_parser.parse_command_line_arguments(std::env::args().collect());

    let undos = JsonStore::load_undos(undo_count);
    let tasks = JsonStore::load_tasks(Some(&command.filters));

    let mut action = registry.get_action_from_command_parser(&command);
    action.set_tasks(tasks);
    action.set_undos(undos);
    action.do_action(&SimpleTaskTextPrinter);

    JsonStore::log_undo(undo_count, action.get_undos_mut().to_owned());
    JsonStore::write_tasks(action.get_tasks());
}
