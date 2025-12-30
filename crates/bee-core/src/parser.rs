use log::debug;
use std::fmt::Debug;

use chrono::{DateTime, Duration, Local, NaiveTime, TimeDelta, TimeZone};

use crate::lexer::{Lexer, Token, TokenType};

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

fn get_day_duration_from_string(number: i64, value: &str) -> Result<TimeDelta, String> {
    let parsed = value
        .parse::<i64>()
        .map_err(|err| format!("invalid duration value '{}': {}", value, err))?;
    Duration::try_days(number * parsed).ok_or_else(|| "invalid day duration".to_string())
}

fn empty_token() -> Token {
    Token {
        token_type: TokenType::Eof,
        literal: String::new(),
        start: 0,
        end: 0,
    }
}

pub trait BaseParser: Debug {
    fn get_buffer_index(&self) -> usize;
    fn set_buffer_index(&mut self, value: usize);

    fn get_current_token(&self) -> &Token;
    fn set_current_token(&mut self, tok: Token);

    fn get_buffer_tokens(&self) -> &Vec<Token>;
    fn get_mut_buffer_tokens(&mut self) -> &mut Vec<Token>;

    fn get_peek_token(&self) -> &Token;
    fn set_peek_token(&mut self, tok: Token);

    fn get_mut_lexer(&mut self) -> &mut Lexer;

    fn back_token(&mut self) {
        if self.get_buffer_index() == 0 {
            debug!("Ignoring back_token call at buffer start");
            return;
        }
        let new_index = self.get_buffer_index() - 1;
        self.set_buffer_index(new_index);
        if let Some(token) = self.get_buffer_tokens().get(new_index) {
            self.set_current_token(token.to_owned());
        } else {
            self.set_current_token(empty_token());
        }
        if let Some(token) = self.get_buffer_tokens().get(new_index + 1) {
            self.set_peek_token(token.to_owned());
        } else {
            self.set_peek_token(empty_token());
        }
    }

    fn back_n_tokens(&mut self, n: usize) {
        for _ in 0..n {
            self.back_token();
        }
    }

    /// advance one token
    fn next_token(&mut self) {
        // We have buffered tokens, just go forward
        if self.get_buffer_tokens().len() > 2
            && self.get_buffer_index() < self.get_buffer_tokens().len() - 2
        {
            self.set_current_token(self.get_peek_token().to_owned());
            let next_peek = self
                .get_buffer_tokens()
                .get(self.get_buffer_index() + 2)
                .cloned()
                .unwrap_or_else(empty_token);
            self.set_peek_token(next_peek);
            self.set_buffer_index(self.get_buffer_index() + 1);
            return;
        }

        // We're up to date with the lexer
        self.set_current_token(self.get_peek_token().to_owned());

        let next_lexer_tok = match self.get_mut_lexer().next_token() {
            Ok(token) => token,
            Err(err) => {
                debug!("Lexer error while reading token: {}", err);
                empty_token()
            }
        };
        self.set_peek_token(next_lexer_tok);

        let next_peek_tok = self.get_peek_token().to_owned();
        self.get_mut_buffer_tokens().push(next_peek_tok);
        self.set_buffer_index(self.get_buffer_index() + 1);
    }

    /// skip whitespace and return the number of whitespace characters skipped
    fn skip_whitespace(&mut self) -> usize {
        let mut blank_count = 0;
        while self.get_current_token().token_type == TokenType::Blank {
            self.next_token();
            blank_count += 1;
        }
        blank_count
    }

    fn read_date_expr(&mut self) -> Result<DateTime<Local>, String> {
        debug!("Reading date expression");
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
            match self.get_current_token().token_type {
                // duration
                TokenType::Int => {
                    debug!("Read Int token '{}'", self.get_current_token().literal);
                    let number_token = self.get_current_token().to_owned();
                    backtrace_tokens += 1;
                    self.next_token();
                    backtrace_tokens += self.skip_whitespace();
                    let unit_token = self.get_current_token().to_owned();
                    // expect a duration here
                    let duration = match unit_token.literal.as_str() {
                        value if matches_year_string(value) => {
                            get_day_duration_from_string(365, number_token.literal.as_str())?
                        }
                        value if matches_month_string(value) => {
                            get_day_duration_from_string(30, number_token.literal.as_str())?
                        }
                        value if matches_week_string(value) => {
                            get_day_duration_from_string(7, number_token.literal.as_str())?
                        }
                        value if matches_day_string(value) => {
                            get_day_duration_from_string(1, number_token.literal.as_str())?
                        }
                        value if matches_hour_string(value) => {
                            let parsed = number_token.literal.parse::<i64>().map_err(|err| {
                                format!(
                                    "invalid hour duration value '{}': {}",
                                    number_token.literal, err
                                )
                            })?;
                            Duration::try_hours(parsed)
                                .ok_or_else(|| "invalid hour duration".to_string())?
                        }
                        value if matches_minute_string(value) => {
                            let parsed = number_token.literal.parse::<i64>().map_err(|err| {
                                format!(
                                    "invalid minute duration value '{}': {}",
                                    number_token.literal, err
                                )
                            })?;
                            Duration::try_minutes(parsed)
                                .ok_or_else(|| "invalid minute duration".to_string())?
                        }
                        value if matches_second_string(value) => {
                            let parsed = number_token.literal.parse::<i64>().map_err(|err| {
                                format!(
                                    "invalid second duration value '{}': {}",
                                    number_token.literal, err
                                )
                            })?;
                            Duration::try_seconds(parsed)
                                .ok_or_else(|| "invalid second duration".to_string())?
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
                        && self.get_current_token().token_type == TokenType::WordString
                        && self.get_current_token().literal == "ago"
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
                            self.get_current_token().literal
                        ));
                    }
                    if expect_duration {
                        if time.is_some() {
                            break;
                        }
                        return Err(format!(
                            "unexpected token '{}' found in invalid date expression",
                            self.get_current_token().literal
                        ));
                    }
                    debug!("Read plus token '{}'", self.get_current_token().literal);
                    cur_scope = if self.get_current_token().token_type == TokenType::TagPlusPrefix {
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

                    debug!(
                        "Read WordString token '{}'",
                        self.get_current_token().literal
                    );
                    let now = Local::now();
                    let today_start = Local
                        .from_local_datetime(
                            &now.date_naive().and_time(
                                NaiveTime::from_hms_opt(0, 0, 0)
                                    .ok_or_else(|| "invalid time for day start".to_string())?,
                            ),
                        )
                        .single()
                        .ok_or_else(|| "unable to resolve local date start".to_string())?;
                    match self.get_current_token().literal.as_str() {
                        "now" => {
                            try_time = now;
                        }
                        "today" => {
                            try_time = today_start;
                        }
                        "tomorrow" => {
                            try_time = today_start
                                + Duration::try_days(1)
                                    .ok_or_else(|| "invalid day duration".to_string())?;
                        }
                        "yesterday" => {
                            try_time = today_start
                                - Duration::try_days(1)
                                    .ok_or_else(|| "invalid day duration".to_string())?;
                        }
                        "eod" => {
                            try_time = today_start
                                + Duration::try_hours(18)
                                    .ok_or_else(|| "invalid hour duration".to_string())?;
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
                                self.get_current_token().literal
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
                    debug!("Other token '{}'", self.get_current_token().literal);
                    break;
                }
            }
            backtrace_tokens += self.skip_whitespace();
        }
        self.back_n_tokens(backtrace_tokens);
        debug!("Parsed date expression. Time: {:?}", time);
        time.ok_or_else(|| "invalid date expression".to_string())
    }
}

#[cfg(test)]
#[path = "parser_test.rs"]
mod parser_test;
