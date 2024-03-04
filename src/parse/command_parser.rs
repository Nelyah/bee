use super::parser::build_filter_from_strings;

use crate::config::ReportConfig;
use crate::config::CONFIG;
use crate::filters::AndFilter;
use crate::filters::Filter;

use std::collections::HashMap;

#[derive(Debug, Clone, Default)]
pub struct Parser {
    command_parsers: Vec<ParsedCommand>,
}

impl Parser {
    pub fn register_command_parser(&mut self, command_parser: ParsedCommand) {
        self.command_parsers.push(command_parser);
    }
}

#[derive(Debug, Clone, Default)]
pub struct ParsedCommand {
    pub command: String,
    pub filters: Box<dyn Filter>,
    pub arguments: Vec<String>,
    pub arguments_as_filters: bool,
    pub report_kind: ReportConfig,
}

impl Parser {
    pub fn parse_command_line_arguments(&self, args: Vec<String>) -> ParsedCommand {
        // Build a map from command name to ParsedCommand
        let mut command_to_parser = HashMap::new();
        for parsed_command in &self.command_parsers {
            command_to_parser.insert(parsed_command.command.clone(), parsed_command.clone());
        }

        let arguments = if args.len() > 1 { &args[1..] } else { &[] };

        let mut report_kind = ReportConfig::default();
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
                parsed_command.filters = Box::new(AndFilter {
                    children: vec![
                        build_filter_from_strings(&filters),
                        build_filter_from_strings(&report_kind.filters),
                    ],
                });
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
            filters: Box::new(AndFilter {
                children: vec![
                    build_filter_from_strings(&filters),
                    build_filter_from_strings(&report_kind.filters),
                ],
            }),
            command: "list".to_string(),
            report_kind,
            ..Default::default()
        }
    }
}

// Assume implementation of build_filter_from_strings and CONFIG
