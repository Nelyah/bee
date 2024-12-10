use super::table::Table;
use crate::config::get_config;
use crate::task::{Task, TaskStatus};
use crate::{config::ReportConfig, printer::table::StyledText};
use chrono::{DateTime, Local};
use colored::{ColoredString, Colorize};
use log::{debug, trace};
use serde_json::Value;
use std::cmp::Ordering;
use std::io::{self, Write};

pub trait Printer {
    fn print_list_of_tasks(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
    ) -> Result<(), String>;
    fn print_task_info(&self, task: &Task) -> Result<(), String>;
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
                    .filter(|&tag| colour_conf.value.as_ref() == Some(tag))
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
            "depends" => {
                if !task.get_depends().is_empty()
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
    fn print_task_info(&self, task: &Task) -> Result<(), String> {
        let status = match task.get_status() {
            TaskStatus::Pending => task.get_status().to_string().to_uppercase().blue(),
            TaskStatus::Completed => task.get_status().to_string().to_uppercase().green(),
            TaskStatus::Deleted => task.get_status().to_string().to_uppercase().bright_red(),
        };
        let mut output_str = String::default();
        output_str += format!("\n{} - {}", status, task.get_summary()).as_str();

        output_str += format!(
            "\n\nIDs:\t\t{}{}",
            match task.get_id() {
                Some(id) => id.to_string() + ", ",
                None => "".to_string(),
            },
            task.get_uuid().to_string().bold()
        )
        .as_str();

        if let Some(proj) = task.get_project() {
            output_str += format!("\nProject:\t{}", proj.get_name().bold()).as_str();
        }

        if !task.get_tags().is_empty() {
            output_str += format!("\nTags:\t\t{}", task.get_tags().join(" ").bold()).as_str();
        }

        output_str += "\n";

        output_str += format!(
            "\nCreated:\t{}",
            task.get_date_created()
                .format("%Y-%m-%d %H:%M")
                .to_string()
                .bold()
        )
        .as_str();

        if let Some(end_date) = task.get_date_completed() {
            output_str += format!(
                "\nCompleted:\t{}",
                end_date.format("%Y-%m-%d %H:%M").to_string().bold()
            )
            .as_str();
        }

        if let Some(due_date) = task.get_date_due() {
            output_str += format!(
                "\nDue:\t\t{}",
                due_date
                    .format("%Y-%m-%d %H:%M")
                    .to_string()
                    .bold()
                    .yellow()
            )
            .as_str();
        }

        if !task.get_annotations().is_empty() {
            output_str += "\n\nAnnotations:";
        }
        for ann in task.get_annotations() {
            output_str += format!(
                "\n    {} - {}",
                ann.get_time().format("%Y-%m-%d %H:%M").to_string().bold(),
                ann.get_value()
            )
            .as_str();
        }

        if !task.get_depends().is_empty() || !task.get_depends().is_empty() {
            output_str += "\n";
        }

        if !task.get_depends().is_empty() {
            output_str += format!(
                "\nDepends:\t{}",
                task.get_depends()
                    .iter()
                    .map(|uuid| uuid.to_string())
                    .collect::<Vec<String>>()
                    .join(" ")
                    .bold()
            )
            .as_str();
        }

        if !task.get_blocking().is_empty() {
            output_str += format!(
                "\nBlocking:\t{}",
                task.get_blocking()
                    .iter()
                    .map(|uuid| uuid.to_string())
                    .collect::<Vec<String>>()
                    .join(" ")
                    .bold()
            )
            .as_str();
        }

        println!("{}", output_str);

        Ok(())
    }

    fn print_list_of_tasks(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
    ) -> Result<(), String> {
        let mut writer = io::stdout();
        self.print_list_of_tasks_impl(tasks, report_kind, &mut writer)
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

impl SimpleTaskTextPrinter {
    fn print_list_of_tasks_impl<W: Write>(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
        writer: &mut W,
    ) -> Result<(), String> {
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
                            row.push("".to_owned());
                        }
                    }
                    "project" => {
                        match t.get_project() {
                            Some(proj) => row.push(proj.get_name().to_owned()),
                            None => row.push("".to_string()),
                        };
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

        if task_to_row.is_empty() {
            return writeln!(writer, "No task to show.").map_err(|e| e.to_string());
        }

        // Remove unused columns
        let mut column_used: Vec<bool> = Vec::default();
        column_used.resize(report_kind.column_names.len(), false);

        for row_task in &task_to_row {
            for (i, col) in row_task.row.iter().enumerate() {
                if !col.is_empty() {
                    column_used[i] = true;
                }
            }
        }

        let mut used_columns: Vec<usize> = Vec::default();
        for (i, col_used) in column_used.iter().enumerate() {
            if *col_used {
                used_columns.push(i);
            }
        }
        let mut header_names = Vec::default();
        for idx in &used_columns {
            header_names.push(report_kind.column_names[*idx].to_owned());
        }
        for i in 0..report_kind.column_names.len() {
            if !used_columns.contains(&i) {
                debug!(
                    "Dropping column '{}' (index: {}) because none of the tasks have that field",
                    &report_kind.column_names[i], i
                );
            }
        }
        let mut tbl = Table::new(&header_names, writer)?;

        for row_task in task_to_row.iter_mut() {
            let mut new_row = Vec::default();
            for idx in &used_columns {
                new_row.push(row_task.row[*idx].to_owned());
            }
            row_task.row = new_row;
        }

        task_to_row.sort();
        task_to_row.reverse();
        for row_task in task_to_row {
            tbl.add_row(row_task.row, get_style_for_task(&row_task.task)?)
                .unwrap();
        }

        tbl.print();
        Ok(())
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
