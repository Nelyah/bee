use super::table::Table;
use crate::config::get_config;
use crate::task::Task;
use crate::{config::ReportConfig, printer::table::StyledText};
use chrono::{DateTime, Local};
use colored::{ColoredString, Colorize};
use log::trace;
use serde_json::Value;
use std::cmp::Ordering;
use std::io;

pub trait Printer {
    fn print_list_of_tasks(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
    ) -> Result<(), String>;
    fn show_information_message(&self, message: &str);
    fn error(&self, message: &str);

    /// This function is for developer purposes only. It might be used so the program outputs
    /// information to stdout or console.log, depending on the implementation
    fn print_raw(&self, message: &str);
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

pub struct SimpleTaskTextPrinter;

fn get_style_for_task(task: &Task) -> Result<Option<StyledText>, String> {
    let conf = get_config();

    for colour_conf in &conf.colour_fields {
        match colour_conf.field.as_str() {
            "tag" => {
                if task
                    .get_tags()
                    .iter()
                    .filter(|&tag| tag == &colour_conf.value)
                    .count()
                    > 0
                {
                    return Ok(Some(StyledText {
                        styles: vec![],
                        background_color: colour_conf.bg,
                        foreground_color: colour_conf.fg,
                    }));
                }
            }
            "primary_colour" | "secondary_colour" => {}
            _ => return Err(format!("Unable to colour the output based on the unknown field '{}'. Please check your configuration.", colour_conf.field)),
        }
    }
    Ok(None)
}

#[derive(Eq, PartialEq)]
struct RowTask {
    task: Task,
    row: Vec<String>,
}

impl PartialOrd for RowTask {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for RowTask {
    fn cmp(&self, other: &Self) -> Ordering {
        match self.task.cmp(&other.task) {
            Ordering::Equal => unreachable!("Two rows have the same task"),
            other => other,
        }
    }
}

impl Printer for SimpleTaskTextPrinter {
    fn print_list_of_tasks(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
    ) -> Result<(), String> {
        let mut tbl = Table::new(&report_kind.column_names, io::stdout()).unwrap();

        let mut task_to_row: Vec<RowTask> = Vec::default();
        for t in tasks {
            let mut row: Vec<String> = Vec::default();
            for field in &report_kind.columns {
                match field.as_str() {
                    "date_created" | "date_completed" | "date_due" => {
                        if let Some(date_str) = t.get_field(field).as_str() {
                            let local_date: DateTime<Local> = DateTime::from(
                                DateTime::parse_from_rfc3339(date_str).ok().unwrap(),
                            );
                            row.push(format_relative_time(local_date))
                        } else {
                            row.push("None".to_owned());
                        }
                    }
                    "summary" => {
                        let mut out_str = t.get_summary().to_owned();
                        t.get_annotations().iter().for_each(|ann| {
                            out_str += &format!(
                                "\n  {}  {}",
                                ann.get_time().format("%Y-%m-%d"),
                                ann.get_value()
                            )
                        });
                        row.push(out_str);
                    }

                    _ => {
                        let value = t.get_field(field);
                        row.push(print_value(&value))
                    }
                }
            }
            trace!("Row: {:?}", row);
            task_to_row.push(RowTask {
                task: t.to_owned(),
                row,
            });
        }

        task_to_row.sort();
        task_to_row.reverse();
        for row_task in task_to_row {
            tbl.add_row(row_task.row, get_style_for_task(&row_task.task)?)
                .unwrap();
        }

        if tbl.is_empty() {
            println!("No task to show.");
        } else {
            tbl.print();
        }
        Ok(())
    }

    fn show_information_message(&self, message: &str) {
        println!("{}", message);
    }

    fn error(&self, message: &str) {
        println!(
            "{}",
            ColoredString::from("Error: ")
                .bold()
                .bright_red()
                .to_string()
                + message
        );
    }

    fn print_raw(&self, message: &str) {
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
