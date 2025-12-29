use crate::dto::TokenSpan;
use bee_actions::ActionRegistry;
use bee_core::{
    filters::{self, Filter},
    lexer::{Lexer, TokenType},
    task::TaskProperties,
};
use std::collections::HashMap;

/// Parsed input payload for the API parse endpoint.
pub struct ParsedInput {
    pub action: String,
    pub properties: Option<TaskProperties>,
    pub filter: Option<Box<dyn Filter>>,
}

/// Parse a raw input string into structured action, properties, and filter data.
pub fn parse_input(input: &str) -> Result<ParsedInput, String> {
    let args: Vec<String> = input
        .split_whitespace()
        .map(|token| token.to_string())
        .collect();

    let command_specs = ActionRegistry::get_parsed_commands();
    let mut alias_map: HashMap<String, bool> = HashMap::new();
    for cmd in command_specs {
        alias_map.insert(cmd.command, cmd.arguments_as_filters);
    }

    let mut action = "list".to_string();
    let mut filters: Vec<String> = Vec::new();
    let mut arguments: Vec<String> = Vec::new();
    let mut found_action = false;

    for (idx, arg) in args.iter().enumerate() {
        if let Some(arguments_as_filters) = alias_map.get(arg) {
            action = arg.clone();
            found_action = true;
            let remaining = &args[idx + 1..];
            if *arguments_as_filters {
                filters.extend(remaining.iter().cloned());
            } else {
                arguments.extend(remaining.iter().cloned());
            }
            break;
        }

        filters.push(arg.clone());
    }

    if !found_action {
        filters = args.clone();
    }

    let filter = if filters.is_empty() {
        None
    } else {
        Some(filters::from(&filters)?)
    };
    let properties = if arguments.is_empty() {
        None
    } else {
        Some(TaskProperties::from(&arguments)?)
    };

    Ok(ParsedInput {
        action,
        properties,
        filter,
    })
}

/// Tokenize an input string into spans for UI highlighting.
pub fn tokenize_with_spans(input: &str) -> Result<Vec<TokenSpan>, String> {
    let mut lexer = Lexer::new(input.to_string());
    let mut tokens = Vec::new();

    loop {
        let token = lexer.next_token()?;
        if token.token_type == TokenType::Eof {
            break;
        }
        tokens.push(TokenSpan {
            token_type: token.token_type.to_string(),
            literal: token.literal,
            start: token.start,
            end: token.end,
        });
    }

    Ok(tokens)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_input_with_action_and_properties() {
        let parsed = parse_input("add hello world").unwrap();
        assert_eq!(parsed.action, "add");
        assert!(parsed.filter.is_none());
        assert!(parsed.properties.is_some());
    }

    #[test]
    fn test_parse_input_with_filters_only() {
        let parsed = parse_input("project:demo").unwrap();
        assert_eq!(parsed.action, "list");
        assert!(parsed.filter.is_some());
        assert!(parsed.properties.is_none());
    }

    #[test]
    fn test_tokenize_with_spans() {
        let tokens = tokenize_with_spans("a b").unwrap();
        assert_eq!(tokens.len(), 3);
        assert_eq!(tokens[0].literal, "a");
        assert_eq!(tokens[0].start, 0);
        assert_eq!(tokens[0].end, 1);
        assert_eq!(tokens[1].literal, " ");
        assert_eq!(tokens[1].start, 1);
        assert_eq!(tokens[1].end, 2);
        assert_eq!(tokens[2].literal, "b");
        assert_eq!(tokens[2].start, 2);
        assert_eq!(tokens[2].end, 3);
    }
}
