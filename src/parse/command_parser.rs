use super::parser::build_filter_from_strings;

use crate::task::filters::Filter;
use crate::config::ReportConfig;
use crate::config::CONFIG;

use std::collections::HashMap;

#[derive(Debug, Clone, Default)]
struct Parser {
    command_parsers: Vec<ParsedCommand>,
}

impl Parser {
    fn register_command_parser(&mut self, command: &str, description: &str, arg_as_filters: bool) {
        self.command_parsers.push(ParsedCommand {
            command: command.to_string(),
            description: description.to_string(),
            arguments_as_filters: arg_as_filters,
            ..Default::default() // assuming other fields have default values
        });
    }
}

#[derive(Debug, Clone, Default)]
struct ParsedCommand {
    description: String,
    command: String,
    filters: Filter,
    arguments: Vec<String>,
    arguments_as_filters: bool,
    report_kind: ReportConfig,
}

impl Parser {
    fn parse_command_line_arguments(&self, args: Vec<String>) -> ParsedCommand {
        // Build a map from command name to ParsedCommand
        let mut command_to_parser = HashMap::new();
        for parsed_command in &self.command_parsers {
            command_to_parser.insert(parsed_command.command.clone(), parsed_command.clone());
        }

        let arguments = if args.len() > 1 { &args[1..] } else { &[] };

        let mut report_kind = ReportConfig::default(); // assuming default report kind
        let mut filters = Vec::new();
        let mut command_args = Vec::new();

        for (idx, arg) in arguments.iter().enumerate() {
            if let Some(parsed_command) = command_to_parser.get_mut(arg) {
                for remaining_arg in &arguments[idx + 1..] {
                    if let Some(report) = CONFIG.get_report(remaining_arg) {
                        report_kind = report.clone();
                        continue;
                    }
                    command_args.push(remaining_arg.clone());
                }
                if parsed_command.arguments_as_filters {
                    filters.extend(command_args.clone());
                } else {
                    parsed_command.arguments = command_args;
                }
                parsed_command.filters = build_filter_from_strings(&filters);
                parsed_command.report_kind = report_kind;
                return parsed_command.clone();
            }

            // Match report name or add to filters
            if let Some(report) = CONFIG.get_report(arg) {
                report_kind = report.clone();
                continue;
            }

            filters.push(arg.clone());
        }

        ParsedCommand {
            filters: build_filter_from_strings(&filters),
            command: "list".to_string(),
            report_kind,
            ..Default::default()
        }
    }
}

// Assume implementation of build_filter_from_strings and CONFIG

