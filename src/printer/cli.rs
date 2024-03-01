use super::table::Table;
use crate::config::ReportConfig;
use crate::task::task::Task;
use chrono::{DateTime, Local};
use serde_json::Value;
use std::io;

pub trait Printer {
    fn print_list_of_tasks(&self, tasks: &Vec<Task>, report_kind: &ReportConfig);
    fn show_information_message(&self, message: &str);
}

fn format_relative_time(t: DateTime<Local>) -> String {
    let now = Local::now();
    let diff = now.signed_duration_since(t);

    let seconds = diff.num_seconds();
    let minutes = diff.num_minutes();
    let hours = diff.num_hours();
    let days = diff.num_days();
    let weeks = days / 7;
    let months = days / 30;
    let years = days / 365;

    if seconds < 60 {
        format!("{}s", seconds)
    } else if minutes < 60 {
        format!("{}m", minutes)
    } else if hours < 24 {
        format!("{}h", hours)
    } else if days < 14 {
        format!("{}d", days)
    } else if weeks < 8 {
        format!("{}w", weeks)
    } else if months < 12 {
        format!("{}mo", months)
    } else {
        format!("{}y", years)
    }
}

#[derive(Default)]
pub struct SimpleTaskTextPrinter;

impl Printer for SimpleTaskTextPrinter {
    fn print_list_of_tasks(&self, tasks: &Vec<Task>, report_kind: &ReportConfig) {
        let mut tbl = Table::new(&report_kind.column_names, io::stdout()).unwrap();

        for t in tasks {
            let mut row: Vec<String> = Vec::default();
            for field in &report_kind.columns {
                match field.as_str() {
                    "date_created" | "date_completed" => {
                        if let Some(date_str) = t.get_field(field).as_str() {
                            let local_date: DateTime<Local> = DateTime::from(
                                DateTime::parse_from_rfc3339(date_str).ok().unwrap(),
                            );
                            row.push(format_relative_time(local_date))
                        }
                    }

                    _ => {
                        let value = t.get_field(field);
                        row.push(print_value(&value))
                    }
                }
            }
            tbl.add_row(row).unwrap();
        }

        tbl.print();
    }

    fn show_information_message(&self, message: &str) {
        println!("{}", message);
    }
}

fn print_value(value: &Value) -> String {
    match value {
        Value::String(s) => s.to_string(),
        Value::Number(n) => n.to_string(),
        Value::Bool(b) => b.to_string(),
        Value::Array(arr) => {
            let string_array: Vec<String> = arr
                .iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect();
            string_array.join(", ").to_string()
        }
        Value::Null => "".to_string(),
        // You can add more matches for other types if needed
        _ => panic!("Unsupported type {}", value),
    }
}

#[path = "cli_test.rs"]
mod cli_test;
