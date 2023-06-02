// use reqwest::{Client, RequestBuilder, Response};
// use reqwest::Response;

use rusk::task::Task;
mod config;
use config::CONFIG;

#[macro_use]
extern crate prettytable;
use prettytable::{format, Table};

use serde::Deserialize;

use std::collections::HashMap;

#[derive(Deserialize)]
struct Ip {
    tasks: Vec<Task>,
}

async fn make_add_request(args: CommandLineArgs) -> Result<(), reqwest::Error> {
    let mut map = HashMap::new();
    map.insert("description", args.text);

    let client = reqwest::Client::new();
    client
        .post(format!("{}/v1/add_task", CONFIG.server))
        .json(&map)
        .send()
        .await?
        .json::<Ip>()
        .await?;
    Ok(())
}

async fn make_delete_request(args: CommandLineArgs) -> Result<(), reqwest::Error> {
    let mut map = HashMap::new();
    map.insert("query", args.filters);

    let client = reqwest::Client::new();
    client
        .post(format!("{}/v1/delete_task", CONFIG.server))
        .json(&map)
        .send()
        .await?
        .json::<Ip>()
        .await?;
    Ok(())
}

async fn make_completed_request(args: CommandLineArgs) -> Result<(), reqwest::Error> {
    let mut map = HashMap::new();
    map.insert("query", args.filters);

    let client = reqwest::Client::new();
    client
        .post(format!("{}/v1/complete_task", CONFIG.server))
        .json(&map)
        .send()
        .await?
        .json::<Ip>()
        .await?;
    Ok(())
}

async fn make_list_request(args: CommandLineArgs) -> Result<(), reqwest::Error> {
    let mut map = HashMap::new();
    map.insert("query", args.filters);

    let client = reqwest::Client::new();
    let res = client
        .post(&format!("{}/v1/get_tasks", CONFIG.server))
        .json(&map)
        .send()
        .await?
        .json::<Ip>()
        .await?;
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
    let mut tasks = res.tasks;
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
    Ok(())
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
}

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
    let text = args.iter().skip_while(|&arg| !is_text(arg)).nth(1).cloned();

    CommandLineArgs {
        filters,
        command,
        text,
    }
}

fn is_command(arg: &str) -> bool {
    match arg {
        "add" | "complete" | "done" | "delete" | "list" => true,
        _ => false,
    }
}

fn parse_command(arg: &str) -> Command {
    match arg {
        "add" => Command::Add,
        "complete" => Command::Complete,
        "done" => Command::Complete,
        "delete" => Command::Delete,
        "list" => Command::List,
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
        Command::Add => make_add_request(args).await.unwrap(),
        Command::List => make_list_request(args).await.unwrap(),
        Command::Delete => make_delete_request(args).await.unwrap(),
        Command::Complete => make_completed_request(args).await.unwrap(),
    }
}
