mod cli;
mod config;
mod error_type;
mod table;

use bee_actions::{ActionRegistry, command_parser::Parser};
use bee_core::{
    Printer, UserFacingError,
    filters::{self, Filter},
    storage::{AsyncStore, db::DbStore},
    task::TaskProperties,
};

use crate::{
    cli::SimpleTaskTextPrinter,
    config::{SectionType, get_cli_config},
    error_type::CliResult,
};

use log::{debug, trace};
use std::process::exit;

fn get_section_filters() -> CliResult<Option<Box<dyn Filter>>> {
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
async fn main() {
    if let Err(err) = run().await {
        SimpleTaskTextPrinter.error(&err.user_message());
        log::debug!("CLI error detail: {}", err.developer_message());
        exit(1);
    }
}

async fn run() -> CliResult<()> {
    let mut logger =
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"));
    logger
        .filter_module("sqlx", log::LevelFilter::Warn)
        .filter_module("sea_orm", log::LevelFilter::Warn)
        .filter_module("sea_orm::query", log::LevelFilter::Warn)
        .filter_module("sea_orm::executor", log::LevelFilter::Warn)
        .init();

    let undo_count = 1;

    config::load_config()?;

    let mut arg_parser = Parser::default();
    for cmd in ActionRegistry::get_parsed_commands() {
        arg_parser.register_command_parser(cmd);
    }

    let mut command = arg_parser.parse_command_line_arguments(std::env::args().collect())?;
    let section_filters = get_section_filters()?;
    if let Some(f) = section_filters {
        command.filters = filters::or(command.filters.clone(), f);
    }

    let undos = DbStore::load_undos(undo_count).await?;
    let undos_uuid: Vec<uuid::Uuid> = undos
        .iter()
        .flat_map(|x| x.tasks.iter().map(|y| *y.get_uuid()))
        .collect();

    debug!("Loaded {} undos", undos.len());
    trace!("Undos: {:?}", undos);
    trace!("Undo uuids: {:?}", undos_uuid);

    let mut props: Option<TaskProperties> = None;

    if !command.arguments_as_filters {
        props = Some(TaskProperties::from(&command.arguments)?);
    }

    let mut tasks = DbStore::load_tasks(Some(command.filters.clone()), props).await?;
    command.filters.convert_id_to_uuid(tasks.get_id_to_uuid());

    for undo_action in &undos {
        tasks.set_undos(&undo_action.tasks);
    }

    let mut action = ActionRegistry::get_action_from_command_parser(&command);
    action.set_tasks(tasks);
    action.set_undos(undos);
    action.do_action(&SimpleTaskTextPrinter)?;

    DbStore::write_tasks(action.get_tasks()).await?;

    DbStore::log_undo(undo_count, action.get_undos().to_owned()).await?;

    Ok(())
}
