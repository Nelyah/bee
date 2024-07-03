use log::debug;
use std::fmt::Debug;

use crate::task::lexer::{Lexer, Token, TokenType};

use chrono::{DateTime, Duration, Local, NaiveTime, TimeDelta, TimeZone};

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
            panic!("Error: Trying to call 'back_token' too many times!");
        }
        self.set_buffer_index(self.get_buffer_index() - 1);
        self.set_current_token(
            self.get_buffer_tokens()
                .get(self.get_buffer_index())
                .unwrap()
                .to_owned(),
        );
        self.set_peek_token(
            self.get_buffer_tokens()
                .get(self.get_buffer_index() + 1)
                .unwrap()
                .to_owned(),
        );
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
            self.set_peek_token(
                self.get_buffer_tokens()
                    .get(self.get_buffer_index() + 2)
                    .unwrap()
                    .to_owned(),
            );
            self.set_buffer_index(self.get_buffer_index() + 1);
            return;
        }

        // We're up to date with the lexer
        self.set_current_token(self.get_peek_token().to_owned());

        let next_lexer_tok = self.get_mut_lexer().next_token().unwrap();
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
                            &now.date_naive()
                                .and_time(NaiveTime::from_hms_opt(0, 0, 0).unwrap()),
                        )
                        .single()
                        .unwrap();
                    match self.get_current_token().literal.as_str() {
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
        if time.is_none() {
            return Err("invalid date expression".to_string());
        }
        debug!("Parsed date expression. Time: {:?}", time);
        Ok(time.unwrap())
    }
}

#[cfg(test)]
#[path = "parser_test.rs"]
mod parser_test;
