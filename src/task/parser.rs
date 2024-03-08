use crate::lexer::{Lexer, Token, TokenType};

use super::TaskProperties;

pub struct Parser {
    lexer: Lexer,
    current_token: Token,
    peek_token: Token,
}

macro_rules! process_tag_prefix {
    ($self:ident, $props:ident, $tag_vector:ident) => {
        if $self.peek_token.token_type != TokenType::WordString {
            if let Some(desc) = $props.description {
                $props.description = Some(desc + &$self.current_token.literal);
            } else {
                $props.description = Some($self.current_token.literal.to_owned());
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

    pub fn parse_task_properties(&mut self) -> TaskProperties {
        let mut props = TaskProperties::default();
        if self.current_token.token_type == TokenType::Eof {
            return props;
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
                | TokenType::LeftParenthesis
                | TokenType::RightParenthesis
                | TokenType::FilterStatus => {
                    if let Some(desc) = props.description {
                        props.description = Some(desc + &self.current_token.literal);
                    } else {
                        props.description = Some(self.current_token.literal.to_owned());
                    }
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
        if let Some(desc) = &mut props.description {
            *desc = desc.trim().to_string();
        }
        props
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn from_string(value: &str) -> TaskProperties {
        let lexer = Lexer::new(value.to_owned());
        let mut parser = Parser::new(lexer);
        parser.parse_task_properties()
    }

    #[test]
    fn test_task_properties_parser() {
        let tp = from_string("a new task description");
        assert_eq!(
            tp,
            TaskProperties {
                description: Some("a new task description".to_owned()),
                tags_remove: None,
                tags_add: None
            }
        );

        let tp = from_string("a new task descrip(tion status:completed");
        assert_eq!(
            tp,
            TaskProperties {
                description: Some("a new task descrip(tion status:completed".to_owned()),
                tags_remove: None,
                tags_add: None
            }
        );

        let tp = from_string("a new task descrip(\ttion status:  completed");
        assert_eq!(
            tp,
            TaskProperties {
                description: Some("a new task descrip(\ttion status:  completed".to_owned()),
                tags_remove: None,
                tags_add: None
            }
        );

        let tp = from_string("a new task -main description +foo");
        assert_eq!(
            tp,
            TaskProperties {
                description: Some("a new task description".to_owned()),
                tags_remove: Some(vec!["main".to_owned()]),
                tags_add: Some(vec!["foo".to_owned()]),
            }
        );

        let tp = from_string("");
        assert_eq!(tp, TaskProperties::default(),);
    }
}
