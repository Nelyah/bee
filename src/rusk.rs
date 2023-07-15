// use reqwest::{Client, RequestBuilder, Response};
// use reqwest::Response;

use rusk::operation::Operation;
use rusk::task::Task;
use serde::Deserialize;
mod config;
use config::CONFIG;

#[macro_use]
extern crate prettytable;
use prettytable::{format, Table};

#[derive(Deserialize)]
struct Ip {
    tasks: Vec<Task>,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct TaskSync {
    operations: Vec<Vec<Operation>>,
}

// TODO:
// The data file should be configured in the CONFIG file

// TODO: Add the ability to have multiple server endpoints in the config

use rusk::manager::{json_manager::JsonTaskManager, TaskHandler};
use uuid::Uuid;

#[derive(serde::Serialize, serde::Deserialize, Default)]
struct TaskData {
    description: String,
    tags: Option<Vec<String>>,
    sub_tasks: Option<Vec<String>>,
}

#[derive(serde::Serialize, serde::Deserialize, Default)]
struct TaskQuery {
    query: Vec<String>,
}

fn add_tasks(args: CommandLineArgs) {
    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();
    manager.load_task_data(data_file);
    let sub_tasks: Vec<String> = Vec::default();
    let tags: Vec<String> = Vec::default();

    let mut sub_tasks_uuid: Vec<Uuid> = Default::default();
    if sub_tasks.len() > 0 {
        for i in sub_tasks {
            if let Ok(uuid) = Uuid::parse_str(&i) {
                sub_tasks_uuid.push(uuid);
            }
        }
    }
    match &args.text {
        Some(txt) => {
            manager.add_task(&txt, tags, sub_tasks_uuid);
            manager.write_task_data(data_file);
        }
        _ => {
            println!("Error: no description provided for the task")
        }
    }
}

fn delete_tasks(args: CommandLineArgs) {
    if args.filters.len() == 0 {
        println!("Error: No filter specified");
        return;
    }

    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();
    manager.load_task_data(data_file);

    let tasks_uuid: Vec<Uuid> = manager
        .filter_tasks_from_string(&args.filters)
        .iter()
        .map(|t| t.uuid)
        .collect();

    if tasks_uuid.len() == 0 {
        println!("Error: no task corresponds to the filter mentioned.");
        return;
    }
    for uuid in tasks_uuid {
        manager.delete_task(&uuid);
    }

    manager.write_task_data(data_file);
}

fn complete_tasks(args: CommandLineArgs) {
    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();
    manager.load_task_data(data_file);

    let tasks_uuid: Vec<Uuid> = manager
        .filter_tasks_from_string(&args.filters)
        .iter()
        .map(|t| t.uuid)
        .collect();
    for uuid in tasks_uuid {
        manager.complete_task(&uuid);
    }

    manager.write_task_data(data_file);
}

fn list_tasks(args: CommandLineArgs) {
    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();

    manager.load_task_data(data_file);
    let filtered_tasks = manager.filter_tasks_from_string(&args.filters);
    let owned_tasks: Vec<Task> = filtered_tasks.iter().map(|&t| t.to_owned()).collect();

    let mut table = Table::new();
    let format = format::FormatBuilder::new()
        .column_separator('|')
        .borders('|')
        .separators(
            &[format::LinePosition::Top, format::LinePosition::Bottom],
            format::LineSeparator::new('-', '+', '+', '+'),
        )
        .padding(1, 1)
        .build();
    table.set_format(format);

    // TODO: Fetch this from the config file
    table.set_titles(row!["ID", "Description", "Status"]);
    let mut tasks = owned_tasks;
    tasks.sort_by_key(|t| t.date_created);
    for task in tasks {
        let task_id: String = match task.id {
            Some(value) => value.to_string(),
            _ => String::from("none"),
        };
        table.add_row(row![task_id, task.description, task.status.to_string()]);
    }
    table.set_format(*format::consts::FORMAT_NO_BORDER_LINE_SEPARATOR);
    table.printstd();
}

#[derive(Debug)]
struct CommandLineArgs {
    filters: Vec<String>,
    command: Command,
    text: Option<String>,
}

#[derive(Debug)]
enum Command {
    Add,
    Complete,
    Delete,
    List,
    Sync,
}

// TODO: Parse this to extract tags and projects, etc.
fn parse_command_line() -> CommandLineArgs {
    let args: Vec<String> = std::env::args().skip(1).collect();

    let filters = args
        .iter()
        .take_while(|&arg| !is_command(arg))
        .cloned()
        .collect();
    let command = args
        .iter()
        .find(|&arg| is_command(arg))
        .map(|arg| parse_command(arg))
        .unwrap_or(Command::List);
    let text_tokens = args.iter().skip_while(|&arg| !is_text(arg));
    let text: Option<String> = if text_tokens.clone().count() > 0 {
        Some(text_tokens.cloned().collect::<Vec<String>>().join(" "))
    } else {
        None
    };

    CommandLineArgs {
        filters,
        command,
        text,
    }
}

// TODO: Get new tasks from server as well
async fn request_sync(_args: CommandLineArgs) -> Result<(), reqwest::Error> {
    let data_file = "data.json";
    let mut manager = JsonTaskManager::default();

    manager.load_task_data(data_file);
    let payload = TaskSync {
        operations: manager.get_operations().to_vec(),
    };

    let client = reqwest::Client::new();
    let result = client
        .post(format!("{}/v1/sync", CONFIG.server))
        .json(&payload)
        .send()
        .await?;

    match result.error_for_status() {
        Ok(res) => {
            let value = res.json::<Ip>().await?;
            // Operations were correctly sent
            // Reset the current operations stack
            // TODO: Keep the historic of operations so we can still undo
            manager.wipe_operations();
            manager.write_task_data(data_file);
        }
        Err(err) => {}
    }

    Ok(())
}

fn is_command(arg: &str) -> bool {
    match arg {
        "add" | "done" | "delete" | "list" | "sync" => true,
        _ => false,
    }
}

fn parse_command(arg: &str) -> Command {
    match arg {
        "add" => Command::Add,
        "done" => Command::Complete,
        "delete" => Command::Delete,
        "list" => Command::List,
        "sync" => Command::Sync,
        _ => Command::List,
    }
}

fn is_text(arg: &str) -> bool {
    !is_command(arg)
}

#[tokio::main]
async fn main() {
    let args = parse_command_line();
    match args.command {
        Command::Add => add_tasks(args),
        Command::List => list_tasks(args),
        Command::Delete => delete_tasks(args),
        Command::Complete => complete_tasks(args),
        Command::Sync => request_sync(args).await.unwrap(),
    }
}
