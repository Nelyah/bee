use bee_core::filters;
use bee_core::filters::Filter;
use log::debug;

use bee_core::config::{ReportConfig, get_config};

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
    // The command name
    pub command: String,
    /// The filters to apply to the tasks
    pub filters: Box<dyn Filter>,
    pub arguments: Vec<String>,
    pub arguments_as_filters: bool,
    pub report_kind: ReportConfig,
}

impl Parser {
    pub fn parse_command_line_arguments(&self, args: Vec<String>) -> Result<ParsedCommand, String> {
        // Build a map from command name to ParsedCommand
        let mut command_to_parser = HashMap::new();
        for parsed_command in &self.command_parsers {
            command_to_parser.insert(parsed_command.command.clone(), parsed_command.clone());
        }

        let arguments = if args.len() > 1 { &args[1..] } else { &[] };

        let mut report_kind = get_config().get_default_report().clone();
        let mut filters = Vec::new();
        let mut command_args = Vec::new();

        for (idx, arg) in arguments.iter().enumerate() {
            if let Some(parsed_command) = command_to_parser.get_mut(arg) {
                for remaining_arg in &arguments[idx + 1..] {
                    if let Some(report) = get_config().get_report(remaining_arg) {
                        debug!("Matched report '{}'", remaining_arg);
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
                parsed_command.filters = filters::and(
                    filters::from(&filters)?,
                    filters::from(&report_kind.filters)?,
                );
                parsed_command.report_kind = report_kind;
                return Ok(parsed_command.clone());
            }

            // Match report name or add to filters
            if let Some(report) = get_config().get_report(arg) {
                debug!("Matched report '{}'", arg);
                report_kind = report.clone();
                continue;
            }

            filters.push(arg.clone());
        }

        let command_filters = filters::and(
            filters::from(&filters)?,
            filters::from(&report_kind.filters)?,
        );
        Ok(ParsedCommand {
            filters: command_filters,
            command: "list".to_string(),
            report_kind,
            ..Default::default()
        })
    }
}
