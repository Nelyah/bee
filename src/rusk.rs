pub mod actions;
mod config;
pub mod parse;
pub mod printer;
pub mod storage;
pub mod task;

use chrono::Local;
use config::CONFIG;
use printer::cli::SimpleTaskTextPrinter;
use uuid::Uuid;

use crate::{printer::cli::Printer, task::task::Task};

fn main() {
    println!("hello world");

    println!("{}", CONFIG.default_report);
    println!("default report is {}", CONFIG.default_report);
    let p: SimpleTaskTextPrinter = SimpleTaskTextPrinter::default();
    let ts: Vec<Task> = vec![Task {
        description: "bar".to_string(),
        id: Some(1),
        status: task::task::TaskStatus::PENDING,
        uuid: Uuid::default(),
        tags: vec!["one".to_string(), "two".to_string()],
        date_created: Local::now(),
        date_completed: None,
        sub: Vec::default(),
    },Task {
        description: "foo".to_string(),
        id: Some(2),
        status: task::task::TaskStatus::PENDING,
        uuid: Uuid::default(),
        tags: Vec::default(),
        date_created: Local::now(),
        date_completed: None,
        sub: Vec::default(),
    },Task {
        description: "foo".to_string(),
        id: Some(2),
        status: task::task::TaskStatus::PENDING,
        uuid: Uuid::default(),
        tags: Vec::default(),
        date_created: Local::now(),
        date_completed: None,
        sub: Vec::default(),
    }];
    p.print_list_of_tasks(&ts, &CONFIG.get_report(&CONFIG.default_report).unwrap())
}
