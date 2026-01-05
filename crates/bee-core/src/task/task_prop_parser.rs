use std::fmt::Debug;

use log::debug;
use uuid::Uuid;

use crate::{
    CoreError, CoreResult,
    important_link::ImportantLinkInput,
    lexer::{Lexer, Token, TokenType},
    parser::BaseParser,
    task::{DependsOnIdentifier, Project, TaskProperties, TaskStatus},
};

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

    pub fn parse_task_properties(&mut self) -> CoreResult<TaskProperties> {
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
                        return Err(CoreError::parse(format!(
                            "Expected a token of type WordString following a TokenTypeFilterStatus, found '{}' (value: '{}')",
                            self.peek_token.token_type, self.peek_token.literal
                        )));
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
                        return Err(CoreError::parse(format!(
                            "Expected a token of type WordString following a TokenTypeProjectPrefix, found '{}' (value: '{}')",
                            self.peek_token.token_type, self.peek_token.literal
                        )));
                    }

                    let mut project_name = self.current_token.literal.to_string();

                    while self.peek_token.token_type == TokenType::TagMinusPrefix
                        || self.peek_token.token_type == TokenType::WordString
                    {
                        project_name.push_str(&self.peek_token.literal);
                        self.next_token();
                    }

                    if project_name.ends_with('.') {
                        return Err(CoreError::parse(
                            err_msg_prefix
                                + &format!(
                                    "A project name cannot end with a '.' (name: '{}')",
                                    project_name
                                ),
                        ));
                    }

                    if project_name.ends_with('-') {
                        return Err(CoreError::parse(
                            err_msg_prefix
                                + &format!(
                                    "A project name cannot end with a '-' (name: '{}')",
                                    project_name
                                ),
                        ));
                    }

                    if project_name.to_lowercase() == "none" {
                        props.project = Some(None);
                    } else {
                        props.project = Some(Some(Project::from(project_name)));
                    }

                    self.next_token();
                }
                TokenType::TagPlusPrefix => {
                    process_tag_prefix!(self, props, tags_add);
                }
                TokenType::TagMinusPrefix => {
                    process_tag_prefix!(self, props, tags_remove);
                }
                TokenType::DependsOn
                | TokenType::Blocks
                | TokenType::ParentOf
                | TokenType::ChildOf
                | TokenType::RelatedTo
                | TokenType::Duplicates => {
                    let link_token_type = self.current_token.token_type.clone();
                    let link_name = match link_token_type {
                        TokenType::DependsOn => "depends",
                        TokenType::Blocks => "blocks",
                        TokenType::ParentOf => "parent",
                        TokenType::ChildOf => "child",
                        TokenType::RelatedTo => "related",
                        TokenType::Duplicates => "duplicates",
                        _ => unreachable!(),
                    };
                    self.next_token();
                    self.skip_whitespace();

                    // Get existing identifiers for this link type
                    let mut identifiers = match &link_token_type {
                        TokenType::DependsOn => props.depends_on.clone(),
                        TokenType::Blocks => props.blocks.clone(),
                        TokenType::ParentOf => props.parent_of.clone(),
                        TokenType::ChildOf => props.child_of.clone(),
                        TokenType::RelatedTo => props.related_to.clone(),
                        TokenType::Duplicates => props.duplicates.clone(),
                        _ => unreachable!(),
                    }
                    .unwrap_or_default();

                    match self.current_token.token_type {
                        TokenType::Uuid => {
                            let parsed = Uuid::parse_str(&self.current_token.literal)
                                .map_err(|err| {
                                    CoreError::parse(format!(
                                        "Expected a UUID following {}:, but could not parse '{}' ({})",
                                        link_name,
                                        self.current_token.literal,
                                        err
                                    ))
                                })?;
                            identifiers.push(DependsOnIdentifier::Uuid(parsed));
                        }
                        TokenType::Int => {
                            let parsed = self
                                .current_token
                                .literal
                                .parse::<i32>()
                                .map_err(|err| {
                                    CoreError::parse(format!(
                                        "Expected an integer following {}:, but could not parse '{}' ({})",
                                        link_name,
                                        self.current_token.literal,
                                        err
                                    ))
                                })?;
                            identifiers.push(DependsOnIdentifier::Id(parsed));
                        }
                        _ if self.current_token.token_type == TokenType::WordString
                            && self.current_token.literal == *"none" =>
                        {
                            // Clear all links of this type
                            identifiers.clear();
                        }
                        _ => {
                            return Err(CoreError::parse(
                                err_msg_prefix
                                    + &format!(
                                        "Expected a token of type Uuid or Int following {}:, found '{}' (value: '{}')",
                                        link_name,
                                        self.current_token.token_type,
                                        self.current_token.literal
                                    ),
                            ));
                        }
                    }
                    // Store the updated identifiers
                    let identifiers_opt = if identifiers.is_empty() {
                        Some(Vec::new())
                    } else {
                        Some(identifiers)
                    };
                    match link_token_type {
                        TokenType::DependsOn => props.depends_on = identifiers_opt,
                        TokenType::Blocks => props.blocks = identifiers_opt,
                        TokenType::ParentOf => props.parent_of = identifiers_opt,
                        TokenType::ChildOf => props.child_of = identifiers_opt,
                        TokenType::RelatedTo => props.related_to = identifiers_opt,
                        TokenType::Duplicates => props.duplicates = identifiers_opt,
                        _ => unreachable!(),
                    }
                    self.next_token();
                }
                TokenType::FilterTokDateDue => {
                    self.next_token();
                    self.skip_whitespace();

                    if self.current_token.token_type != TokenType::WordString
                        && self.current_token.token_type != TokenType::Int
                    {
                        return Err(CoreError::parse(
                            err_msg_prefix
                                + &format!(
                                    "Expected a token of type String or Int following a TokenTypeFilterDateEnd, found '{}' (value: '{}')",
                                    self.peek_token.token_type, self.peek_token.literal
                                ),
                        ));
                    }

                    let time = self.read_date_expr()?;
                    props.date_due = Some(time);
                    self.next_token();
                }
                TokenType::ImportantLink => {
                    self.next_token();
                    self.skip_whitespace();

                    // Parse URL (WordString or String)
                    let url = match self.current_token.token_type {
                        TokenType::WordString | TokenType::String => {
                            self.current_token.literal.clone()
                        }
                        _ => {
                            return Err(CoreError::parse(format!(
                                "{}Expected URL after link:, found '{}' (value: '{}')",
                                err_msg_prefix,
                                self.current_token.token_type,
                                self.current_token.literal
                            )));
                        }
                    };
                    self.next_token();
                    self.skip_whitespace();

                    // Optionally parse title (quoted string)
                    let title = if self.current_token.token_type == TokenType::String {
                        let t = self.current_token.literal.clone();
                        self.next_token();
                        Some(t)
                    } else {
                        None
                    };

                    props.set_important_link_add(ImportantLinkInput::new(url, title));
                }
                TokenType::ImportantLinkRemove => {
                    self.next_token();
                    self.skip_whitespace();

                    // Parse URL to remove
                    let url = match self.current_token.token_type {
                        TokenType::WordString | TokenType::String => {
                            self.current_token.literal.clone()
                        }
                        _ => {
                            return Err(CoreError::parse(format!(
                                "{}Expected URL after -link:, found '{}' (value: '{}')",
                                err_msg_prefix,
                                self.current_token.token_type,
                                self.current_token.literal
                            )));
                        }
                    };
                    self.next_token();

                    // Add to removal list
                    let mut urls = props.important_link_remove.clone().unwrap_or_default();
                    urls.push(url);
                    props.set_important_link_remove(urls);
                }
                TokenType::Eof => {
                    return Err(CoreError::parse(
                        "unexpected end of input while parsing task property expression",
                    ));
                }
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
