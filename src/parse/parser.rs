use super::lexer::{Lexer, Token, TokenType};
use crate::task::filters::{Filter, FilterCombinationType};
use crate::task::{filters, task};

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

fn is_number(value: &str) -> bool {
    value.parse::<i32>().is_ok()
}

fn add_string_to_current_filter(
    value: &str,
    filter: &Filter,
    scope_operator: ScopeOperator,
) -> Filter {
    match scope_operator {
        ScopeOperator::None | ScopeOperator::And => filters::add_filter(
            &filter,
            &filters::new_with_value(value),
            FilterCombinationType::And,
        ),
        ScopeOperator::Or => filters::add_filter(
            &filter,
            &filters::new_with_value(value),
            FilterCombinationType::Or,
        ),
        ScopeOperator::Xor => filters::add_filter(
            &filter,
            &filters::new_with_value(value),
            FilterCombinationType::Xor,
        ),
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

    pub fn parse_filter(&mut self) -> Filter {
        let mut filter = self.parse_filter_impl(false, ScopeOperator::None);

        // Change operator to OR if certain conditions are met
        if filter.operator == FilterCombinationType::And {
            let change_op_to_or = filter
                .children
                .iter()
                .all(|f| is_number(&f.value) && f.has_value && f.children.is_empty());
            if change_op_to_or {
                filter.operator = FilterCombinationType::Or;
            }
        }

        filter
    }

    fn parse_filter_impl(
        &mut self,
        has_parenthesis_scope: bool,
        scope_operator: ScopeOperator,
    ) -> Filter {
        if self.current_token.token_type == TokenType::Eof {
            return filters::new_empty();
        }

        let mut filter = Filter {
            operator: FilterCombinationType::None,
            ..Default::default()
        };

        while self.current_token.token_type != TokenType::Eof {
            match self.current_token.token_type {
                TokenType::OperatorOr => {
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
                    filter = Filter {
                        has_value: false,
                        operator: FilterCombinationType::Or,
                        children: vec![
                            filter,
                            self.parse_filter_impl(has_parenthesis_scope, ScopeOperator::Or),
                        ],
                        ..Default::default()
                    };
                }
                TokenType::OperatorAnd => {
                    match self.peek_token.token_type {
                        TokenType::OperatorOr | TokenType::OperatorAnd | TokenType::OperatorXor => {
                            panic!("Error: encountered two operators one after the other");
                        }
                        _ => {}
                    }
                    self.next_token();
                    filter = filters::add_filter(
                        &filter,
                        &self.parse_filter_impl(has_parenthesis_scope, ScopeOperator::And),
                        FilterCombinationType::And,
                    );
                }
                TokenType::OperatorXor => {
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
                    filter = Filter {
                        has_value: false,
                        operator: FilterCombinationType::Xor,
                        children: vec![
                            filter,
                            self.parse_filter_impl(has_parenthesis_scope, ScopeOperator::Xor),
                        ],
                        ..Default::default()
                    };
                }
                TokenType::RightParenthesis => {
                    if !has_parenthesis_scope {
                        panic!("Error: encountered ')' before encountering a '('");
                    }
                    return filter;
                }
                TokenType::LeftParenthesis => {
                    self.next_token();
                    filter = filters::add_filter(
                        &filter,
                        &self.parse_filter_impl(true, ScopeOperator::None),
                        FilterCombinationType::And,
                    );

                    if self.current_token.token_type != TokenType::RightParenthesis {
                        panic!(
                            "Error parsing command line. Expected right parenthesis, found '{}'",
                            self.current_token.literal
                        );
                    }
                    self.next_token();
                }
                TokenType::FilterStatus => {
                    if self.peek_token.token_type != TokenType::String {
                        panic!(
                            "Expected a token of type String following a TokenTypeFilterStatus, found {} (value: {})",
                            self.peek_token.token_type,
                            self.peek_token.literal
                        );
                    }
                    // Assuming string_is_valid_task_status is a function to validate task status
                    println!("{}", &self.peek_token.literal);
                    task::TaskStatus::from_string(&self.peek_token.literal).unwrap();

                    let status_string =
                        format!("{}{}", self.current_token.literal, self.peek_token.literal);
                    filter = add_string_to_current_filter(&status_string, &filter, scope_operator);
                    self.next_token();
                    self.next_token();
                }
                TokenType::String
                | TokenType::TagMinus
                | TokenType::TagPlus
                | TokenType::Int
                | TokenType::Uuid => {
                    filter = add_string_to_current_filter(
                        &self.current_token.literal,
                        &filter,
                        scope_operator,
                    );
                    self.next_token();
                }
                _ => panic!("Not implemented token encountered"),
            }
        }

        filter
    }
}

pub fn build_filter_from_strings(values: Vec<String>) -> Filter {
    let lexer = Lexer::new(values.join(" "));
    let mut parser = ParserN::new(lexer);
    parser.parse_filter()
}

#[path = "parser_test.rs"]
mod parser_test;
