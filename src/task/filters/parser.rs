use uuid::Uuid;

use super::filters_impl::{DateDueFilterType, FilterKind};

use crate::task;
use crate::task::filters::{
    AndFilter, DateCreatedFilter, DateDueFilter, DateEndFilter, Filter, OrFilter, ProjectFilter,
    RootFilter, StatusFilter, StringFilter, TagFilter, TaskIdFilter, UuidFilter, XorFilter,
};
use crate::task::lexer::{Lexer, Token, TokenType};

use crate::task::parser::BaseParser;

#[derive(Debug)]
pub struct FilterParser {
    lexer: Lexer,
    current_token: Token,
    peek_token: Token,
    buffer_tokens: Vec<Token>,
    buffer_index: usize,
}

#[derive(Clone, Copy, PartialEq)]
enum ScopeOperator {
    Or,
    And,
    Xor,
    None,
}

fn add_to_current_filter(
    filter1: Box<dyn Filter>,
    filter2: Box<dyn Filter>,
    scope_operator: &ScopeOperator,
) -> Box<dyn Filter> {
    match scope_operator {
        ScopeOperator::None | ScopeOperator::And => {
            if filter1.get_kind() == FilterKind::Root {
                return filter2;
            }
            if filter2.get_kind() == FilterKind::Root {
                return filter1;
            }
            Box::new(AndFilter {
                children: vec![filter1, filter2],
            })
        }
        _ => {
            unreachable!("We should never get here");
        }
    }
}

impl BaseParser for FilterParser {
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

impl FilterParser {
    pub fn new(lexer: Lexer) -> FilterParser {
        let mut parser = FilterParser {
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

    pub fn parse_filter(&mut self) -> Result<Box<dyn Filter>, String> {
        let mut has_only_ids = true;
        let filter = self.parse_filter_impl(&0, ScopeOperator::None, &mut has_only_ids)?;

        if has_only_ids {
            let values: Vec<Box<dyn Filter>> = filter
                .iter()
                .filter(|f| f.get_kind() == FilterKind::TaskId)
                .map(|f| f.clone_box())
                .collect();

            if !values.is_empty() {
                return Ok(Box::new(OrFilter { children: values }));
            }
        }

        Ok(filter)
    }

    fn parse_filter_impl(
        &mut self,
        parenthesis_scope: &usize,
        scope_operator: ScopeOperator,
        has_only_ids: &mut bool,
    ) -> Result<Box<dyn Filter>, String> {
        let mut filter: Box<dyn Filter> = Box::new(RootFilter { child: None });
        let err_msg_prefix: String = "could not parse the filter expression. ".to_string();

        if self.current_token.token_type == TokenType::Eof {
            return Ok(filter);
        }

        while self.current_token.token_type != TokenType::Eof {
            match self.current_token.token_type {
                TokenType::Eof => {}
                TokenType::Blank => {
                    self.next_token();
                }
                TokenType::OperatorOr => {
                    *has_only_ids = false;
                    match self.peek_token.token_type {
                        TokenType::OperatorOr | TokenType::OperatorAnd | TokenType::OperatorXor => {
                            return Err(err_msg_prefix + "Found two operators one after the other");
                        }
                        _ => {}
                    }
                    if scope_operator == ScopeOperator::And {
                        return Ok(filter);
                    }
                    self.next_token();
                    filter = Box::new(OrFilter {
                        children: vec![
                            filter,
                            self.parse_filter_impl(
                                parenthesis_scope,
                                ScopeOperator::Or,
                                has_only_ids,
                            )?,
                        ],
                    });
                }
                TokenType::OperatorAnd => {
                    *has_only_ids = false;
                    match self.peek_token.token_type {
                        TokenType::OperatorOr | TokenType::OperatorAnd | TokenType::OperatorXor => {
                            return Err(err_msg_prefix + "Found two operators one after the other");
                        }
                        _ => {}
                    }
                    self.next_token();
                    filter = Box::new(AndFilter {
                        children: vec![
                            filter,
                            self.parse_filter_impl(
                                parenthesis_scope,
                                ScopeOperator::And,
                                has_only_ids,
                            )?,
                        ],
                    });
                }
                TokenType::OperatorXor => {
                    *has_only_ids = false;
                    match self.peek_token.token_type {
                        TokenType::OperatorOr | TokenType::OperatorAnd | TokenType::OperatorXor => {
                            return Err(err_msg_prefix + "Found two operators one after the other");
                        }
                        _ => {}
                    }
                    match scope_operator {
                        ScopeOperator::Or | ScopeOperator::And => {
                            return Ok(filter);
                        }
                        _ => {}
                    }
                    self.next_token();
                    filter = Box::new(XorFilter {
                        children: vec![
                            filter,
                            self.parse_filter_impl(
                                parenthesis_scope,
                                ScopeOperator::Xor,
                                has_only_ids,
                            )?,
                        ],
                    });
                }
                TokenType::RightParenthesis => {
                    if *parenthesis_scope == 0 {
                        return Err(err_msg_prefix + "Encountered ')' before encountering a '('");
                    }
                    return Ok(filter);
                }
                TokenType::LeftParenthesis => {
                    self.next_token();
                    if filter.get_kind() == FilterKind::Root {
                        filter = self.parse_filter_impl(
                            &(parenthesis_scope + 1),
                            ScopeOperator::None,
                            has_only_ids,
                        )?;
                    } else {
                        filter = Box::new(AndFilter {
                            children: vec![
                                filter,
                                self.parse_filter_impl(
                                    &(parenthesis_scope + 1),
                                    ScopeOperator::None,
                                    has_only_ids,
                                )?,
                            ],
                        });
                    }
                    if self.current_token.token_type != TokenType::RightParenthesis {
                        return Err(err_msg_prefix
                            + &format!(
                                "Expected right parenthesis, found '{}'",
                                self.current_token.literal
                            ));
                    }
                    self.next_token();
                }
                TokenType::FilterStatus => {
                    *has_only_ids = false;
                    self.next_token();
                    self.skip_whitespace();
                    if self.current_token.token_type != TokenType::WordString {
                        return Err(err_msg_prefix
                            + &format!(
                            "Expected a token of type String following a TokenTypeFilterStatus, found '{}' (value: '{}')",
                            self.current_token.token_type,
                            self.current_token.literal
                            ));
                    }

                    let status_filter = Box::new(StatusFilter {
                        status: task::TaskStatus::from_string(&self.current_token.literal)
                            .map_err(|err| err_msg_prefix.to_string() + &err)?,
                    });
                    filter = add_to_current_filter(filter, status_filter, &ScopeOperator::And);

                    self.next_token();
                }
                TokenType::ProjectPrefix => {
                    *has_only_ids = false;
                    self.next_token();
                    self.skip_whitespace();
                    if self.current_token.token_type != TokenType::WordString {
                        return Err(err_msg_prefix
                            + &format!(
                            "Expected a token of type String following a TokenTypeProjectPrefix, found '{}' (value: '{}')",
                            self.current_token.token_type,
                            self.current_token.literal
                            ));
                    }

                    if self.current_token.literal.ends_with('.') {
                        return Err(err_msg_prefix
                            + &format!(
                                "A project name cannot end with a '.' (name: '{}')",
                                self.current_token.literal
                            ));
                    }

                    let project_filter = Box::new(ProjectFilter {
                        name: task::Project::from(self.current_token.literal.to_owned()),
                    });
                    filter = add_to_current_filter(filter, project_filter, &ScopeOperator::And);

                    self.next_token();
                }
                TokenType::String | TokenType::WordString => {
                    *has_only_ids = false;
                    filter = add_to_current_filter(
                        filter,
                        Box::new(StringFilter {
                            value: self.current_token.literal.to_owned(),
                        }),
                        &ScopeOperator::And,
                    );
                    self.next_token();
                }
                TokenType::Uuid => {
                    *has_only_ids = false;
                    filter = add_to_current_filter(
                        filter,
                        Box::new(UuidFilter {
                            uuid: Uuid::parse_str(&self.current_token.literal).unwrap(),
                        }),
                        &ScopeOperator::And,
                    );
                    self.next_token();
                }
                TokenType::Int => {
                    filter = add_to_current_filter(
                        filter,
                        Box::new(TaskIdFilter {
                            id: self
                                .current_token
                                .literal
                                .parse::<usize>()
                                .unwrap()
                                .to_owned(),
                        }),
                        &ScopeOperator::And,
                    );
                    self.next_token();
                }
                TokenType::TagMinusPrefix => {
                    *has_only_ids = false;
                    if self.peek_token.token_type != TokenType::WordString {
                        return Err(err_msg_prefix
                            + &format!(
                            "Expected a token of type String following a TokenType::TagMinusPrefix, found '{}' (value: '{}')",
                            self.peek_token.token_type,
                            self.peek_token.literal
                            ));
                    }

                    let tag_filter = Box::new(TagFilter {
                        include: false,
                        tag_name: self.peek_token.literal.to_owned(),
                    });
                    filter = add_to_current_filter(filter, tag_filter, &ScopeOperator::And);
                    self.next_token();
                    self.next_token();
                }
                TokenType::TagPlusPrefix => {
                    *has_only_ids = false;
                    if self.peek_token.token_type != TokenType::WordString {
                        return Err(err_msg_prefix
                            + &format!(
                            "Expected a token of type String following a TokenType::TagMinusPrefix, found '{}' (value: '{}')",
                            self.peek_token.token_type,
                            self.peek_token.literal
                            ));
                    }
                    let tag_filter = Box::new(TagFilter {
                        include: true,
                        tag_name: self.peek_token.literal.to_owned(),
                    });
                    filter = add_to_current_filter(filter, tag_filter, &ScopeOperator::And);
                    self.next_token();
                    self.next_token();
                }
                TokenType::FilterTokDateEndBefore
                | TokenType::FilterTokDateEndAfter
                | TokenType::FilterTokDateCreatedBefore
                | TokenType::FilterTokDateCreatedAfter
                | TokenType::FilterTokDateDue
                | TokenType::FilterTokDateDueAfter
                | TokenType::FilterTokDateDueBefore => {
                    *has_only_ids = false;
                    let before = self.current_token.token_type == TokenType::FilterTokDateEndBefore
                        || self.current_token.token_type == TokenType::FilterTokDateCreatedBefore;
                    let tok_type = self.current_token.token_type.clone();

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
                    let new_filter: Box<dyn Filter> = match tok_type {
                        TokenType::FilterTokDateEndBefore | TokenType::FilterTokDateEndAfter => {
                            Box::new(DateEndFilter { time, before })
                        }
                        TokenType::FilterTokDateCreatedBefore
                        | TokenType::FilterTokDateCreatedAfter => {
                            Box::new(DateCreatedFilter { time, before })
                        }
                        TokenType::FilterTokDateDue => Box::new(DateDueFilter {
                            time,
                            type_when: DateDueFilterType::Day,
                        }),
                        TokenType::FilterTokDateDueBefore => Box::new(DateDueFilter {
                            time,
                            type_when: DateDueFilterType::Before,
                        }),
                        TokenType::FilterTokDateDueAfter => Box::new(DateDueFilter {
                            time,
                            type_when: DateDueFilterType::After,
                        }),
                        _ => unreachable!(),
                    };

                    filter = add_to_current_filter(filter, new_filter, &ScopeOperator::And);

                    self.next_token();
                }
            }
        }

        Ok(filter)
    }
}

#[cfg(test)]
#[path = "parser_test.rs"]
mod parser_test;
