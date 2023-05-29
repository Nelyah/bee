// use reqwest::{Client, RequestBuilder, Response};
// use reqwest::Response;

use rusk::task::Task;

use serde::Deserialize;
use serde::Serialize;

use std::collections::HashMap;

#[derive(Deserialize, Serialize)]
struct Ip {
    status: String,
    tasks: Vec<Task>,
}

async fn make_add_request(args: CommandLineArgs) -> Result<(), reqwest::Error> {
    let mut map = HashMap::new();
    map.insert("description", args.text);

    let client = reqwest::Client::new();
    client
        .post("http://127.0.0.1:8000/v1/add_task")
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
        .post("http://127.0.0.1:8000/v1/delete_task")
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
        .post("http://127.0.0.1:8000/v1/complete_task")
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
        .post("http://127.0.0.1:8000/v1/get_tasks")
        .json(&map)
        .send()
        .await?
        .json::<Ip>()
        .await?;
    for task in res.tasks {
        println!("{}", serde_json::to_string(&task).unwrap());
    }
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
        "add" | "complete" | "delete" | "list" => true,
        _ => false,
    }
}

fn parse_command(arg: &str) -> Command {
    match arg {
        "add" => Command::Add,
        "complete" => Command::Complete,
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
