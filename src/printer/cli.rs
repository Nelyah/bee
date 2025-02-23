use super::table::Table;
use crate::config::{self, get_config};
use crate::task::{filters, Task, TaskStatus};
use crate::{config::ReportConfig, printer::table::StyledText};
use chrono::{DateTime, Local};
use colored::{ColoredString, Colorize};
use log::{debug, trace};
use serde_json::Value;
use std::cmp::Ordering;
use std::collections::HashMap;
use std::io::{self, Write};

pub trait Printer {
    fn print_list_of_tasks(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
    ) -> Result<(), String>;
    fn print_task_info(&self, task: &Task) -> Result<(), String>;

    /// Print the help for all the possible actions. This can also have a couple more named sections.
    ///
    /// @help_section_description: This is a map containing a mapping of Action name to
    /// action description, as it is implemented by them. It may also contain a section
    /// name to its content.
    fn show_help(&self, help_section_description: &HashMap<String, String>) -> Result<(), String>;
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

// Return the style that should be applied to a Task
fn get_style_for_task(task: &Task) -> Result<Option<StyledText>, String> {
    let conf = get_config();

    for colour_conf in &conf.colour_fields {
        match colour_conf.field.as_str() {
            "active" => {
                if task.get_status() == &TaskStatus::Active {
                    return Ok(Some(StyledText {
                        styles: vec![],
                        background_color: colour_conf.bg,
                        foreground_color: colour_conf.fg,
                    }));
                }
            }
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
                if !task.get_depends().is_empty() {
                    return Ok(Some(StyledText {
                        styles: vec![],
                        background_color: colour_conf.bg,
                        foreground_color: colour_conf.fg,
                    }));
                }
            }
            "primary_colour" | "secondary_colour" => {}
            _ => {
                return Err(format!(
                    "Unable to colour the output based on the unknown field '{}'.\
                    Please check your configuration.",
                    colour_conf.field
                ))
            }
        }
    }
    Ok(None)
}

#[derive(Eq, PartialEq, Clone)]
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
    fn show_help(&self, help_section_description: &HashMap<String, String>) -> Result<(), String> {
        let mut tbl = Table::new(
            &vec!["Action name".to_string(), "Description".to_string()],
            io::stdout(),
        )?;
        for (section, content) in help_section_description.iter() {
            if section == "header" {
                continue;
            }
            tbl.add_row(vec![section.to_string(), content.to_string()], None)?;
        }
        if let Some(header_description) = help_section_description.get("header") {
            println!("{}\n", header_description)
        }
        tbl.print();
        Ok(())
    }

    fn print_task_info(&self, task: &Task) -> Result<(), String> {
        let status = match task.get_status() {
            TaskStatus::Active => task.get_status().to_string().to_uppercase().green(),
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

        if !task.get_history().is_empty() {
            output_str += format!("{}", "\n\nTASK HISTORY:".bold().underline()).as_str();
            for event in task.get_history() {
                output_str += format!(
                    "\n- {} | {}",
                    event.time.format("%Y-%m-%d %H:%M").to_string().bold(),
                    &event.value
                )
                .as_str();
            }
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

// Given a report and tasks, build object containing meta information
// required for printing out tasks (RowTask)
impl SimpleTaskTextPrinter {
    fn build_row_task_objects(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
    ) -> Vec<RowTask> {
        let mut rows: Vec<RowTask> = Vec::default();
        for t in tasks {
            let mut row_fields: Vec<String> = Vec::default();
            for field in &report_kind.columns {
                match field.as_str() {
                    "date_created" | "date_completed" | "date_due" => {
                        if let Some(date_str) = t.get_field(field).as_str() {
                            let local_date: DateTime<Local> = DateTime::from(
                                DateTime::parse_from_rfc3339(date_str).ok().unwrap(),
                            );
                            row_fields.push(format_relative_time(local_date))
                        } else {
                            row_fields.push("".to_owned());
                        }
                    }
                    "project" => {
                        match t.get_project() {
                            Some(proj) => row_fields.push(proj.get_name().to_owned()),
                            None => row_fields.push("".to_string()),
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
                        row_fields.push(out_str);
                    }

                    _ => {
                        let value = t.get_field(field);
                        row_fields.push(print_value(&value))
                    }
                }
            }
            trace!("Row: {:?}", row_fields);
            rows.push(RowTask {
                task: t.to_owned(),
                row: row_fields,
            });
        }
        rows
    }

    // If none of the tasks have values for a column, then it should not be shown
    // Returns the updated TaskRow vector and the column names
    fn remove_unused_columns(
        &self,
        mut rows: Vec<RowTask>,
        report_kind: &ReportConfig,
    ) -> (Vec<RowTask>, Vec<String>) {
        // Remove unused columns
        let mut column_used: Vec<bool> = Vec::default();
        column_used.resize(report_kind.column_names.len(), false);

        for row_task in &rows {
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
        // header_names.push("F".to_string());
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

        for row_task in rows.iter_mut() {
            let mut new_row = Vec::default();
            for idx in &used_columns {
                new_row.push(row_task.row[*idx].to_owned());
            }
            row_task.row = new_row;
        }
        (rows, header_names)
    }

    fn split_rows_into_groups(
        &self,
        mut rows: Vec<RowTask>,
        empty_key: &str,
    ) -> Result<HashMap<String, Vec<RowTask>>, String> {
        let mut group_on_value = HashMap::<String, Vec<RowTask>>::new();

        let section_config = &get_config().section;

        if let Some(section_type) = &section_config.section_type {
            match section_type {
                config::SectionType::Project => {
                    for row in rows.drain(0..) {
                        let project = row
                            .task
                            .get_project()
                            .clone()
                            .map_or(empty_key.to_string(), |p| p.to_string());
                        group_on_value.entry(project).or_default().push(row);
                    }
                }
                config::SectionType::Filters => {
                    for (filter_name, filter_str) in &section_config.filters {
                        trace!("There are still some rows remaining. size={}", rows.len());
                        debug!(
                            "Parsing filter for section... section_name='{}'",
                            filter_name
                        );
                        let filter_task = filters::from(filter_str)?;
                        let mut remaining_task_to_row = Vec::new();
                        for row in rows.drain(0..) {
                            if filter_task.validate_task(&row.task) {
                                trace!("Task '{}' matches filters", row.task.get_summary());
                                group_on_value
                                    .entry(filter_name.to_string())
                                    .or_default()
                                    .push(row);
                            } else {
                                trace!("Task '{}' does not match filters", row.task.get_summary());
                                remaining_task_to_row.push(row);
                            }
                        }
                        if let Some(rows) = group_on_value.get(filter_name) {
                            debug!(
                                "Section was added to the table. section='{}', row_count={}",
                                filter_name,
                                rows.len()
                            );
                        } else {
                            debug!(
                                "Section was dropped because no row matched it. section_name='{}'",
                                filter_name
                            );
                        }
                        rows = remaining_task_to_row;
                    }

                    if !rows.is_empty() {
                        debug!(
                            "Some rows didn't fit into a section. row_count={}",
                            rows.len()
                        );
                    }
                    for row in rows.drain(0..) {
                        group_on_value
                            .entry(empty_key.to_string())
                            .or_default()
                            .push(row);
                    }
                }
            }
        } else {
            for row in rows.drain(0..) {
                group_on_value
                    .entry(empty_key.to_string())
                    .or_default()
                    .push(row);
            }
        }
        Ok(group_on_value)
    }

    fn print_list_of_tasks_impl<W: Write>(
        &self,
        tasks: Vec<&Task>,
        report_kind: &ReportConfig,
        writer: &mut W,
    ) -> Result<(), String> {
        let rows: Vec<RowTask> = self.build_row_task_objects(tasks, report_kind);

        if rows.is_empty() {
            return writeln!(writer, "No task to show.").map_err(|e| e.to_string());
        }

        let (rows, header_names) = self.remove_unused_columns(rows, report_kind);

        let empty_key = "__empty_value".to_string();
        let mut group_on_value = self.split_rows_into_groups(rows, &empty_key)?;

        let mut tbl = Table::new(&header_names, writer)?;
        if let Some(rows) = group_on_value.get_mut(&empty_key) {
            rows.sort();
            rows.reverse();

            tbl.add_section("".to_string());

            for row in rows {
                tbl.add_row(row.row.clone(), get_style_for_task(&row.task)?)
                    .unwrap();
            }
        }

        for (section_name, rows) in group_on_value.iter_mut() {
            if section_name == &empty_key {
                continue;
            }
            if rows.is_empty() {
                debug!("Dropping section {} because it is empty!", section_name);
                continue;
            }
            rows.sort();
            rows.reverse();

            tbl.add_section(section_name.to_string());

            for row_task in rows {
                tbl.add_row(row_task.row.clone(), get_style_for_task(&row_task.task)?)
                    .unwrap();
            }
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
