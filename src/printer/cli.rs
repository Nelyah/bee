use crate::config::ReportConfig;
use crate::task::task::Task;
use chrono::{DateTime, Local};
use serde_json::Value;

pub trait Printer {
    fn print_list_of_tasks(&self, tasks: &[Task], report_kind: &ReportConfig);
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

    match diff.num_seconds() {
        0..=59 => format!("{}s", seconds),
        60..=3599 => format!("{}m", minutes),
        3600..=86399 => format!("{}h", hours),
        86400..=1209599 => format!("{}d", days),
        1209600..=4838399 => format!("{}w", weeks),
        4838400..=29030400 => format!("{}mo", months),
        _ => format!("{}y", years),
    }
}

pub struct SimpleTaskTextPrinter;

impl Printer for SimpleTaskTextPrinter {
    fn print_list_of_tasks(&self, tasks: &[Task], report_kind: &ReportConfig) {
        for t in tasks {
            for field in &report_kind.columns {
                if let Some(value) = t.get_field(field) {
                    match field.as_str() {
                        "date_created" | "date_completed" => {
                            if let Some(date_str) = value.as_str() {
                                if let Ok(date) = DateTime::parse_from_rfc3339(date_str) {
                                    // Convert DateTime<FixedOffset> to DateTime<Local>
                                    let local_date: DateTime<Local> = DateTime::from(date);
                                    print!("{} ", format_relative_time(local_date));
                                }
                            }
                        }
                        _ => print_value(&value),
                    }
                }
            }
            println!();
        }
    }

    fn show_information_message(&self, message: &str) {
        println!("{}", message);
    }
}

fn print_value(value: &Value) {
    match value {
        Value::String(s) => print!("{}", s),
        Value::Number(n) => print!("{}", n),
        Value::Bool(b) => print!("{}", b),
        Value::Array(arr) => {
            let string_array: Vec<String> = arr
                .iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect();
            print!("{}", string_array.join(", "));
        }
        // You can add more matches for other types if needed
        _ => panic!("Unsupported type"),
    }
}
