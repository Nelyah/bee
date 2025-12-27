mod cli;
mod config;
mod table;

use bee_actions::{ActionRegistry, command_parser::Parser};
use bee_core::{
    Printer,
    filters::{self, Filter},
    storage::{AsyncStore, db::DbStore},
    task::TaskProperties,
};

use crate::{
    cli::SimpleTaskTextPrinter,
    config::{SectionType, get_cli_config},
};

use log::{debug, trace};
use std::process::exit;

fn get_section_filters() -> Result<Option<Box<dyn Filter>>, String> {
    let mut report_filter = filters::new_empty();
    let section_config = &get_cli_config().section;
    if let Some(session_type) = &section_config.section_type
        && *session_type == SectionType::Filters
    {
        for filter in section_config.filters.values() {
            report_filter = filters::or(report_filter, filters::from(filter)?);
        }
        return Ok(Some(report_filter));
    }

    Ok(None)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let undo_count = 1;

    match config::load_config() {
        Ok(_) => {}
        Err(msg) => {
            SimpleTaskTextPrinter.error(&msg);
            exit(1);
        }
    }

    let mut arg_parser = Parser::default();
    for cmd in ActionRegistry::get_parsed_commands() {
        arg_parser.register_command_parser(cmd);
    }

    let mut command = match arg_parser.parse_command_line_arguments(std::env::args().collect()) {
        Ok(res) => res,
        Err(msg) => {
            SimpleTaskTextPrinter.error(&msg);
            exit(1);
        }
    };
    let section_filters = match get_section_filters() {
        Ok(res) => res,
        Err(msg) => {
            SimpleTaskTextPrinter.error(&msg);
            exit(1);
        }
    };
    if let Some(f) = section_filters {
        command.filters = filters::or(command.filters.clone(), f);
    }

    let undos = match DbStore::load_undos(undo_count).await {
        Ok(u) => u,
        Err(e) => {
            SimpleTaskTextPrinter.error(&format!("Failed to load undos: {}", e));
            exit(1);
        }
    };
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

    let mut tasks = match DbStore::load_tasks(Some(command.filters.clone()), props).await {
        Ok(t) => t,
        Err(e) => {
            SimpleTaskTextPrinter.error(&format!("Failed to load tasks: {}", e));
            exit(1);
        }
    };
    command.filters.convert_id_to_uuid(tasks.get_id_to_uuid());

    for undo_action in &undos {
        tasks.set_undos(&undo_action.tasks);
    }

    let mut action = ActionRegistry::get_action_from_command_parser(&command);
    action.set_tasks(tasks);
    action.set_undos(undos);
    match action.do_action(&SimpleTaskTextPrinter) {
        Ok(_) => {}
        Err(msg) => {
            SimpleTaskTextPrinter.error(&msg);
            exit(1);
        }
    }

    if let Err(e) = DbStore::write_tasks(action.get_tasks()).await {
        SimpleTaskTextPrinter.error(&format!("Failed to write tasks: {}", e));
        exit(1);
    }

    if let Err(e) = DbStore::log_undo(undo_count, action.get_undos().to_owned()).await {
        SimpleTaskTextPrinter.error(&format!("Failed to log undo: {}", e));
        exit(1);
    }

    Ok(())
}
