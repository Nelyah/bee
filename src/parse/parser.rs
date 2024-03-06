use log::debug;
use uuid::Uuid;

use super::lexer::{Lexer, Token, TokenType};
use crate::filters::{
    AndFilter, Filter, FilterKind, OrFilter, RootFilter, StatusFilter, StringFilter, TagFilter,
    TaskIdFilter, UuidFilter, XorFilter,
};
use crate::task;

pub struct ParserN {
    lexer: Lexer,
    current_token: Token,
    peek_token: Token,
}

#[derive(Clone, Copy, PartialEq)]
enum ScopeOperator {
    Or,
    And,
    Xor,
    None,
}

// fn is_number(value: &str) -> bool {
//     value.parse::<i32>().is_ok()
// }

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

impl ParserN {
    pub fn new(lexer: Lexer) -> ParserN {
        let mut parser = ParserN {
            lexer,
            current_token: Token::default(),
            peek_token: Token::default(),
        };
        parser.next_token();
        parser.next_token();
        parser
    }

    fn next_token(&mut self) {
        self.current_token = self.peek_token.to_owned();
        self.peek_token = self.lexer.next_token().unwrap();
    }

    pub fn parse_filter(&mut self) -> Box<dyn Filter> {
        let mut has_only_ids = true;
        let filter = self.parse_filter_impl(&0, ScopeOperator::None, &mut has_only_ids);

        if has_only_ids {
            let values: Vec<Box<dyn Filter>> = filter
                .iter_filters()
                .filter(|f| f.get_kind() == FilterKind::TaskId)
                .map(|f| f.clone_box())
                .collect();

            if values.len() > 0 {
                return Box::new(OrFilter { children: values });
            }
        }

        filter
    }

    fn parse_filter_impl(
        &mut self,
        parenthesis_scope: &usize,
        scope_operator: ScopeOperator,
        has_only_ids: &mut bool,
    ) -> Box<dyn Filter> {
        let mut filter: Box<dyn Filter> = Box::new(RootFilter { child: None });

        if self.current_token.token_type == TokenType::Eof {
            return filter;
        }

        while self.current_token.token_type != TokenType::Eof {
            match self.current_token.token_type {
                TokenType::OperatorOr => {
                    *has_only_ids = false;
                    match self.peek_token.token_type {
                        TokenType::OperatorOr | TokenType::OperatorAnd | TokenType::OperatorXor => {
                            panic!("Error: encountered two operators one after the other");
                        }
                        _ => {}
                    }
                    if scope_operator == ScopeOperator::And {
                        return filter;
                    }
                    self.next_token();
                    filter = Box::new(OrFilter {
                        children: vec![
                            filter,
                            self.parse_filter_impl(
                                parenthesis_scope,
                                ScopeOperator::Or,
                                has_only_ids,
                            ),
                        ],
                    });
                }
                TokenType::OperatorAnd => {
                    *has_only_ids = false;
                    match self.peek_token.token_type {
                        TokenType::OperatorOr | TokenType::OperatorAnd | TokenType::OperatorXor => {
                            panic!("Error: encountered two operators one after the other");
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
                            ),
                        ],
                    });
                }
                TokenType::OperatorXor => {
                    *has_only_ids = false;
                    match self.peek_token.token_type {
                        TokenType::OperatorOr | TokenType::OperatorAnd | TokenType::OperatorXor => {
                            panic!("Error: encountered two operators one after the other");
                        }
                        _ => {}
                    }
                    match scope_operator {
                        ScopeOperator::Or | ScopeOperator::And => {
                            return filter;
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
                            ),
                        ],
                    });
                }
                TokenType::RightParenthesis => {
                    if *parenthesis_scope == 0 {
                        panic!("Error: encountered ')' before encountering a '('");
                    }
                    return filter;
                }
                TokenType::LeftParenthesis => {
                    self.next_token();
                    if filter.get_kind() == FilterKind::Root {
                        filter = self.parse_filter_impl(
                            &(parenthesis_scope + 1),
                            ScopeOperator::None,
                            has_only_ids,
                        );
                    } else {
                        filter = Box::new(AndFilter {
                            children: vec![
                                filter,
                                self.parse_filter_impl(
                                    &(parenthesis_scope + 1),
                                    ScopeOperator::None,
                                    has_only_ids,
                                ),
                            ],
                        });
                    }
                    if self.current_token.token_type != TokenType::RightParenthesis {
                        panic!(
                            "Error parsing command line. Expected right parenthesis, found '{}'",
                            self.current_token.literal
                        );
                    }
                    self.next_token();
                }
                TokenType::FilterStatus => {
                    *has_only_ids = false;
                    if self.peek_token.token_type != TokenType::WordString {
                        panic!(
                            "Expected a token of type String following a TokenTypeFilterStatus, found '{}' (value: '{}')",
                            self.peek_token.token_type,
                            self.peek_token.literal
                        );
                    }
                    // Assuming string_is_valid_task_status is a function to validate task status
                    let status_filter = Box::new(StatusFilter {
                        status: task::TaskStatus::from_string(&self.peek_token.literal)
                            .unwrap_or_else(|err| panic!("{}", err)),
                    });
                    filter = add_to_current_filter(filter, status_filter, &ScopeOperator::And);

                    self.next_token();
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
                        panic!(
                            "Expected a token of type String following a TokenType::TagMinusPrefix, found '{}' (value: '{}')",
                            self.peek_token.token_type,
                            self.peek_token.literal
                        );
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
                        panic!(
                            "Expected a token of type String following a TokenType::TagPlusPrefix, found '{}' (value: '{}')",
                            self.peek_token.token_type,
                            self.peek_token.literal
                        );
                    }
                    let tag_filter = Box::new(TagFilter {
                        include: false,
                        tag_name: self.peek_token.literal.to_owned(),
                    });
                    filter = add_to_current_filter(filter, tag_filter, &ScopeOperator::And);
                    self.next_token();
                    self.next_token();
                }
                _ => panic!("Not implemented token encountered"),
            }
        }

        filter
    }
}

pub fn build_filter_from_strings(values: &[String]) -> Box<dyn Filter> {
    let lexer = Lexer::new(values.join(" "));
    let mut parser = ParserN::new(lexer);
    let f = parser.parse_filter();
    debug!("{}", f);
    f
}

#[cfg(test)]
#[path = "parser_test.rs"]
mod parser_test;
