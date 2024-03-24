use chrono::{DateTime, Duration, Local, NaiveTime, TimeDelta, TimeZone};
use log::debug;
use uuid::Uuid;

use super::filters_impl::FilterKind;

use crate::filters::{
    AndFilter, DateCreatedFilter, DateEndFilter, Filter, OrFilter, RootFilter, StatusFilter,
    StringFilter, TagFilter, TaskIdFilter, UuidFilter, XorFilter,
};
use crate::lexer::{Lexer, Token, TokenType};
use crate::task;

pub struct Parser {
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

fn matches_year_string(input: &str) -> bool {
    input == "y" || input == "year" || input == "years"
}

fn matches_month_string(input: &str) -> bool {
    input == "mo" || input == "month" || input == "months"
}

fn matches_week_string(input: &str) -> bool {
    input == "w" || input == "week" || input == "weeks"
}

fn matches_day_string(input: &str) -> bool {
    input == "d" || input == "day" || input == "days"
}

fn matches_hour_string(input: &str) -> bool {
    input == "h" || input == "hour" || input == "hours"
}

fn matches_minute_string(input: &str) -> bool {
    input == "m" || input == "minute" || input == "minutes"
}

fn matches_second_string(input: &str) -> bool {
    input == "s" || input == "second" || input == "seconds"
}

fn get_day_duration_from_string(number: i64, value: &str) -> TimeDelta {
    Duration::try_days(number * value.parse::<i64>().unwrap().to_owned()).unwrap()
}

impl Parser {
    pub fn new(lexer: Lexer) -> Parser {
        let mut parser = Parser {
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

    /// advance one token
    fn next_token(&mut self) {
        // We have buffered tokens, just go forward
        if self.buffer_tokens.len() > 2 && self.buffer_index < self.buffer_tokens.len() - 2 {
            self.current_token = self.peek_token.to_owned();
            self.peek_token = self
                .buffer_tokens
                .get(self.buffer_index + 2)
                .unwrap()
                .to_owned();
            self.buffer_index += 1;
            return;
        }

        // We're up to date with the lexer
        self.current_token = self.peek_token.to_owned();
        self.peek_token = self.lexer.next_token().unwrap();
        self.buffer_tokens.push(self.peek_token.to_owned());
        self.buffer_index += 1;
    }

    /// go back one token
    fn back_token(&mut self) {
        if self.buffer_index == 0 {
            panic!("Error: Trying to call 'back_token' too many times!");
        }
        self.buffer_index -= 1;
        self.current_token = self
            .buffer_tokens
            .get(self.buffer_index)
            .unwrap()
            .to_owned();
        self.peek_token = self
            .buffer_tokens
            .get(self.buffer_index + 1)
            .unwrap()
            .to_owned();
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

    fn back_n_tokens(&mut self, n: usize) {
        for _ in 0..n {
            self.back_token();
        }
    }

    fn read_date_expr(&mut self) -> Result<DateTime<Local>, String> {
        let mut time = None;
        let mut try_time = Local::now();
        let mut first = true;
        let mut expect_duration = false;
        let mut in_keyword = false;

        let mut backtrace_tokens = 0;

        #[derive(PartialEq)]
        enum Scope {
            Minus,
            Plus,
        }

        let mut cur_scope = Scope::Minus;

        loop {
            match self.current_token.token_type {
                // duration
                TokenType::Int => {
                    debug!("Read Int token '{}'", self.current_token.literal);
                    debug!("Read WordString token '{}'", self.peek_token.literal);
                    let number_token = self.current_token.to_owned();
                    backtrace_tokens += 1;
                    self.next_token();
                    backtrace_tokens += self.skip_whitespace();
                    let unit_token = self.current_token.to_owned();
                    // expect a duration here
                    let duration = match unit_token.literal {
                        _ if matches_year_string(unit_token.literal.as_str()) => {
                            get_day_duration_from_string(365, number_token.literal.as_str())
                        }
                        _ if matches_month_string(unit_token.literal.as_str()) => {
                            get_day_duration_from_string(30, number_token.literal.as_str())
                        }
                        _ if matches_week_string(unit_token.literal.as_str()) => {
                            get_day_duration_from_string(7, number_token.literal.as_str())
                        }
                        _ if matches_day_string(unit_token.literal.as_str()) => {
                            get_day_duration_from_string(1, number_token.literal.as_str())
                        }
                        _ if matches_hour_string(unit_token.literal.as_str()) => {
                            Duration::try_hours(
                                number_token.literal.parse::<i64>().unwrap().to_owned(),
                            )
                            .unwrap()
                        }
                        _ if matches_minute_string(unit_token.literal.as_str()) => {
                            Duration::try_minutes(
                                number_token.literal.parse::<i64>().unwrap().to_owned(),
                            )
                            .unwrap()
                        }
                        _ if matches_second_string(unit_token.literal.as_str()) => {
                            Duration::try_seconds(
                                number_token.literal.parse::<i64>().unwrap().to_owned(),
                            )
                            .unwrap()
                        }
                        _ => {
                            break;
                        }
                    };
                    if first {
                        try_time = Local::now() - duration;
                    } else {
                        match cur_scope {
                            Scope::Minus => {
                                try_time -= duration;
                            }
                            Scope::Plus => {
                                try_time += duration;
                            }
                        }
                    }

                    expect_duration = false;
                    time = Some(try_time.to_owned());
                    backtrace_tokens = 0;
                    self.next_token();
                    backtrace_tokens += self.skip_whitespace();

                    if first
                        && !in_keyword
                        && self.current_token.token_type == TokenType::WordString
                        && self.current_token.literal == "ago"
                    {
                        self.next_token();
                        backtrace_tokens = 0;
                        break;
                    }
                    first = false;
                }
                TokenType::TagPlusPrefix | TokenType::TagMinusPrefix => {
                    if first {
                        return Err(format!(
                            "unexpected token '{}' found in invalid date expression",
                            self.current_token.literal
                        ));
                    }
                    if expect_duration {
                        if time.is_some() {
                            break;
                        }
                        return Err(format!(
                            "unexpected token '{}' found in invalid date expression",
                            self.current_token.literal
                        ));
                    }
                    debug!("Read plus token '{}'", self.current_token.literal);
                    cur_scope = if self.current_token.token_type == TokenType::TagPlusPrefix {
                        Scope::Plus
                    } else {
                        Scope::Minus
                    };
                    expect_duration = true;
                    backtrace_tokens += 1;
                    self.next_token();
                }
                // This is a specific time
                TokenType::WordString => {
                    if !first {
                        break;
                    }
                    first = false;

                    debug!("Read WordString token '{}'", self.current_token.literal);
                    let now = Local::now();
                    let today_start = Local
                        .from_local_datetime(
                            &now.date_naive()
                                .and_time(NaiveTime::from_hms_opt(0, 0, 0).unwrap()),
                        )
                        .single()
                        .unwrap();
                    match self.current_token.literal.as_str() {
                        "now" => {
                            try_time = now;
                        }
                        "today" => {
                            try_time = today_start;
                        }
                        "tomorrow" => {
                            try_time = today_start + Duration::try_days(1).unwrap();
                        }
                        "yesterday" => {
                            try_time = today_start - Duration::try_days(1).unwrap();
                        }
                        "eod" => {
                            try_time = today_start + Duration::try_hours(18).unwrap();
                        }
                        "in" => {
                            expect_duration = true;
                            self.next_token();
                            backtrace_tokens += 1 + self.skip_whitespace();
                            in_keyword = true;
                            continue;
                        }
                        // last week
                        _ => {
                            return Err(format!(
                                "unexpected token '{}' found in invalid date expression",
                                self.current_token.literal
                            ));
                        }
                    }

                    time = Some(try_time.to_owned());
                    backtrace_tokens = 0;
                    self.next_token();
                }
                TokenType::Blank => {
                    self.next_token();
                }
                _ => {
                    debug!("Other token '{}'", self.current_token.literal);
                    break;
                }
            }
            backtrace_tokens += self.skip_whitespace();
        }
        self.back_n_tokens(backtrace_tokens);
        if time.is_none() {
            return Err("invalid date expression".to_string());
        }
        Ok(time.unwrap())
    }

    fn skip_whitespace(&mut self) -> usize {
        let mut blank_count = 0;
        while self.current_token.token_type == TokenType::Blank {
            self.next_token();
            blank_count += 1;
        }
        blank_count
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
                            self.peek_token.token_type,
                            self.peek_token.literal
                            ));
                    }
                    // Assuming string_is_valid_task_status is a function to validate task status

                    let status_filter = Box::new(StatusFilter {
                        status: task::TaskStatus::from_string(&self.current_token.literal)
                            .map_err(|err| err_msg_prefix.to_string() + &err)?,
                    });
                    filter = add_to_current_filter(filter, status_filter, &ScopeOperator::And);

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
                | TokenType::FilterTokDateCreatedAfter => {
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

                    let new_filter: Box<dyn Filter> = if tok_type
                        == TokenType::FilterTokDateEndBefore
                        || tok_type == TokenType::FilterTokDateEndAfter
                    {
                        Box::new(DateEndFilter { time, before })
                    } else {
                        Box::new(DateCreatedFilter { time, before })
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
