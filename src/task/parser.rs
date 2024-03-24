use crate::lexer::{Lexer, Token, TokenType};

use super::{TaskProperties, TaskStatus};

pub struct Parser {
    lexer: Lexer,
    current_token: Token,
    peek_token: Token,
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

impl Parser {
    pub fn new(lexer: Lexer) -> Parser {
        let mut parser = Parser {
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

    fn skip_whitespace(&mut self) {
        while self.current_token.token_type == TokenType::Blank {
            self.next_token();
        }
    }

    pub fn parse_task_properties(&mut self) -> Result<TaskProperties, String> {
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
                            "Expected a token of type String following a TokenTypeFilterStatus, found '{}' (value: '{}')",
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
                TokenType::TagPlusPrefix => {
                    process_tag_prefix!(self, props, tags_add);
                }
                TokenType::TagMinusPrefix => {
                    process_tag_prefix!(self, props, tags_remove);
                }
                TokenType::Eof => unreachable!("We should not be trying to read EOF"),
            }
        }
        if let Some(summary) = &mut props.summary {
            *summary = summary.trim().to_string();
        }
        Ok(props)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn from_string(value: &str) -> TaskProperties {
        let lexer = Lexer::new(value.to_owned());
        let mut parser = Parser::new(lexer);
        parser.parse_task_properties().unwrap()
    }

    #[test]
    fn test_task_properties_parser() {
        let mut tp = from_string("a new task summary");
        assert_eq!(
            tp,
            TaskProperties {
                summary: Some("a new task summary".to_owned()),
                tags_remove: None,
                tags_add: None,
                status: None,
                annotation: None,
            }
        );
        tp.set_annotate("foo".to_owned());
        assert_eq!(
            tp,
            TaskProperties {
                summary: Some("a new task summary".to_owned()),
                tags_remove: None,
                tags_add: None,
                status: None,
                annotation: Some("foo".to_owned()),
            }
        );

        let tp = from_string("a new task summ(ary status:completed");
        assert_eq!(
            tp,
            TaskProperties {
                summary: Some("a new task summ(ary".to_owned()),
                tags_remove: None,
                tags_add: None,
                status: Some(TaskStatus::Completed),
                annotation: None,
            }
        );

        let tp = from_string("a new task summ(\tary status:  pending");
        assert_eq!(
            tp,
            TaskProperties {
                summary: Some("a new task summ(\tary".to_owned()),
                tags_remove: None,
                tags_add: None,
                status: Some(TaskStatus::Pending),
                annotation: None,
            }
        );

        let tp = from_string("a new task -main summary +foo");
        assert_eq!(
            tp,
            TaskProperties {
                summary: Some("a new task summary".to_owned()),
                tags_remove: Some(vec!["main".to_owned()]),
                tags_add: Some(vec!["foo".to_owned()]),
                status: None,
                annotation: None,
            }
        );

        let tp = from_string("");
        assert_eq!(tp, TaskProperties::default(),);
    }
}
