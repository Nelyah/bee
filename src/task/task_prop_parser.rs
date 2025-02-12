use std::fmt::Debug;

use log::debug;
use uuid::Uuid;

use super::parser::BaseParser;
use crate::task::lexer::{Lexer, Token, TokenType};

use super::{DependsOnIdentifier, Project, TaskProperties, TaskStatus};

#[derive(Debug, Default)]
pub struct TaskPropertyParser {
    lexer: Lexer,
    current_token: Token,
    peek_token: Token,
    buffer_tokens: Vec<Token>,
    buffer_index: usize,
}

impl BaseParser for TaskPropertyParser {
    fn get_buffer_index(&self) -> usize {
        self.buffer_index
    }
    fn set_buffer_index(&mut self, value: usize) {
        self.buffer_index = value;
    }

    fn get_current_token(&self) -> &Token {
        &self.current_token
    }
    fn set_current_token(&mut self, tok: Token) {
        self.current_token = tok;
    }

    fn get_buffer_tokens(&self) -> &Vec<Token> {
        &self.buffer_tokens
    }
    fn get_mut_buffer_tokens(&mut self) -> &mut Vec<Token> {
        &mut self.buffer_tokens
    }

    fn get_peek_token(&self) -> &Token {
        &self.peek_token
    }
    fn set_peek_token(&mut self, tok: Token) {
        self.peek_token = tok;
    }

    fn get_mut_lexer(&mut self) -> &mut Lexer {
        &mut self.lexer
    }
}

macro_rules! process_tag_prefix {
    ($self:ident, $props:ident, $tag_vector:ident) => {
        if $self.peek_token.token_type != TokenType::WordString {
            if let Some(summary) = $props.summary {
                $props.summary = Some(summary + &$self.current_token.literal);
            } else {
                $props.summary = Some($self.current_token.literal.to_owned());
            }
            $self.next_token();
        } else {
            if let Some(ref mut tags) = $props.$tag_vector {
                tags.push($self.peek_token.literal.to_owned());
            } else {
                $props.$tag_vector = Some(vec![$self.peek_token.literal.to_owned()]);
            }
            $self.next_token();
            $self.next_token();

            // Skip the next if it's a whitespace because that likely means we had a
            // whitespace before as well
            if $self.current_token.token_type == TokenType::Blank {
                $self.next_token();
            }
        }
    };
}

impl TaskPropertyParser {
    pub fn new(lexer: Lexer) -> TaskPropertyParser {
        let mut parser = TaskPropertyParser {
            lexer,
            current_token: Token::default(),
            peek_token: Token::default(),
            buffer_tokens: Vec::default(),
            buffer_index: 0,
        };
        parser.next_token();
        parser.next_token();
        parser.buffer_index = 0;
        parser
    }

    pub fn parse_task_properties(&mut self) -> Result<TaskProperties, String> {
        let err_msg_prefix: String = "could not parse the task property expression. ".to_string();
        let mut props = TaskProperties::default();
        if self.current_token.token_type == TokenType::Eof {
            return Ok(props);
        }

        while self.current_token.token_type != TokenType::Eof {
            match self.current_token.token_type {
                TokenType::OperatorOr
                | TokenType::Blank
                | TokenType::Int
                | TokenType::Uuid
                | TokenType::String
                | TokenType::WordString
                | TokenType::OperatorAnd
                | TokenType::OperatorXor
                | TokenType::FilterTokDateDueBefore
                | TokenType::FilterTokDateDueAfter
                | TokenType::FilterTokDateCreatedBefore
                | TokenType::FilterTokDateCreatedAfter
                | TokenType::FilterTokDateEndBefore
                | TokenType::FilterTokDateEndAfter
                | TokenType::LeftParenthesis
                | TokenType::RightParenthesis => {
                    if let Some(summary) = props.summary {
                        props.summary = Some(summary + &self.current_token.literal);
                    } else {
                        props.summary = Some(self.current_token.literal.to_owned());
                    }
                    self.next_token();
                }
                TokenType::FilterStatus => {
                    self.next_token();
                    self.skip_whitespace();

                    if self.current_token.token_type != TokenType::WordString {
                        return Err(format!(
                            "Expected a token of type WordString following a TokenTypeFilterStatus, found '{}' (value: '{}')",
                            self.peek_token.token_type,
                            self.peek_token.literal
                        ));
                    }

                    let status = match TaskStatus::from_string(&self.current_token.literal) {
                        Ok(st) => st,
                        Err(e) => {
                            return Err(e);
                        }
                    };
                    props.status = Some(status);
                    self.next_token();
                }
                TokenType::ProjectPrefix => {
                    self.next_token();
                    self.skip_whitespace();

                    if self.current_token.token_type != TokenType::WordString {
                        return Err(format!(
                            "Expected a token of type WordString following a TokenTypeProjectPrefix, found '{}' (value: '{}')",
                            self.peek_token.token_type,
                            self.peek_token.literal
                        ));
                    }

                    let mut project_name = self.current_token.literal.to_string();

                    while self.peek_token.token_type == TokenType::TagMinusPrefix
                        || self.peek_token.token_type == TokenType::WordString
                    {
                        project_name.push_str(&self.peek_token.literal);
                        self.next_token();
                    }

                    if project_name.ends_with('.') {
                        return Err(err_msg_prefix
                            + &format!(
                                "A project name cannot end with a '.' (name: '{}')",
                                project_name
                            ));
                    }

                    if project_name.ends_with('-') {
                        return Err(err_msg_prefix
                            + &format!(
                                "A project name cannot end with a '-' (name: '{}')",
                                project_name
                            ));
                    }

                    props.project = Some(Project::from(project_name));
                    self.next_token();
                }
                TokenType::TagPlusPrefix => {
                    process_tag_prefix!(self, props, tags_add);
                }
                TokenType::TagMinusPrefix => {
                    process_tag_prefix!(self, props, tags_remove);
                }
                TokenType::DependsOn => {
                    self.next_token();
                    self.skip_whitespace();

                    let mut new_depends_on = match &props.depends_on {
                        None => Vec::default(),
                        Some(values) => values.to_owned(),
                    };
                    match self.current_token.token_type {
                        TokenType::Uuid => {
                            new_depends_on.push(DependsOnIdentifier::Uuid(
                                Uuid::parse_str(&self.current_token.literal).unwrap(),
                            ));
                        }
                        TokenType::Int => {
                            new_depends_on.push(DependsOnIdentifier::Usize(
                                self.current_token.literal.parse::<usize>().unwrap(),
                            ));
                        }
                        _ if self.current_token.token_type == TokenType::WordString
                            && self.current_token.literal == *"none" =>
                        {
                            props.depends_on = Some(Vec::new());
                        }
                        _ => {
                            return Err(err_msg_prefix
                            + &format!(
                            "Expected a token of type Uuid or Int following a TokenTypeDependsOn, found '{}' (value: '{}')",
                            self.current_token.token_type,
                            self.current_token.literal
                            ));
                        }
                    }
                    if !new_depends_on.is_empty() {
                        props.depends_on = Some(new_depends_on);
                    }
                    self.next_token();
                }
                TokenType::FilterTokDateDue => {
                    self.next_token();
                    self.skip_whitespace();

                    if self.current_token.token_type != TokenType::WordString
                        && self.current_token.token_type != TokenType::Int
                    {
                        return Err(err_msg_prefix
                            + &format!(
                            "Expected a token of type String or Int following a TokenTypeFilterDateEnd, found '{}' (value: '{}')",
                            self.peek_token.token_type,
                            self.peek_token.literal
                            ));
                    }

                    let time = self.read_date_expr()?;
                    props.date_due = Some(time);
                    self.next_token();
                }
                TokenType::Eof => unreachable!("We should not be trying to read EOF"),
            }
        }
        if let Some(summary) = &mut props.summary {
            *summary = summary.trim().to_string();
            if summary.is_empty() {
                props.summary = None;
            }
        }
        debug!("Parsed task properties: {:?}", props);
        Ok(props)
    }
}

#[cfg(test)]
#[path = "task_prop_parser_test.rs"]
mod parser_test;
