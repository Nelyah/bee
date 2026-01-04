use log::trace;
use unicode_normalization::UnicodeNormalization;
use unicode_segmentation::UnicodeSegmentation;
use uuid::Uuid;

use crate::{CoreError, CoreResult};

#[derive(Debug, PartialEq, Default, Clone)]
pub enum TokenType {
    FilterTokDateDue,
    FilterTokDateDueBefore,
    FilterTokDateDueAfter,
    FilterTokDateCreatedBefore,
    FilterTokDateCreatedAfter,
    FilterTokDateEndBefore,
    FilterTokDateEndAfter,
    DependsOn,
    Blocks,
    ParentOf,
    ChildOf,
    RelatedTo,
    Duplicates,
    String,
    WordString,
    TagPlusPrefix,
    TagMinusPrefix,
    FilterStatus,
    Int,
    Uuid,
    #[default]
    Eof,
    LeftParenthesis,
    RightParenthesis,
    ProjectPrefix,
    OperatorAnd,
    OperatorOr,
    OperatorXor,
    Blank,
}
impl std::fmt::Display for TokenType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let token_str = match self {
            TokenType::FilterTokDateDue => "FilterTokDateDue",
            TokenType::FilterTokDateDueBefore => "FilterTokDateDueBefore",
            TokenType::FilterTokDateDueAfter => "FilterTokDateDueAfter",
            TokenType::DependsOn => "DependsOn",
            TokenType::Blocks => "Blocks",
            TokenType::ParentOf => "ParentOf",
            TokenType::ChildOf => "ChildOf",
            TokenType::RelatedTo => "RelatedTo",
            TokenType::Duplicates => "Duplicates",
            TokenType::String => "String",
            TokenType::ProjectPrefix => "ProjectPrefix",
            TokenType::WordString => "WordString",
            TokenType::TagPlusPrefix => "TagPlusPrefix",
            TokenType::TagMinusPrefix => "TagMinusPrefix",
            TokenType::FilterStatus => "FilterStatus",
            TokenType::Int => "Int",
            TokenType::Uuid => "Uuid",
            TokenType::Eof => "Eof",
            TokenType::LeftParenthesis => "LeftParenthesis",
            TokenType::RightParenthesis => "RightParenthesis",
            TokenType::OperatorAnd => "OperatorAnd",
            TokenType::OperatorOr => "OperatorOr",
            TokenType::OperatorXor => "OperatorXor",
            TokenType::Blank => "Blank",
            TokenType::FilterTokDateEndBefore => "FilterTokDateEndBefore",
            TokenType::FilterTokDateEndAfter => "FilterTokDateEndAfter",
            TokenType::FilterTokDateCreatedBefore => "FilterTokDateCreatedBefore",
            TokenType::FilterTokDateCreatedAfter => "FilterTokDateCreatedAfter",
        };
        write!(f, "{}", token_str)
    }
}

#[path = "lexer_test.rs"]
mod lexer_test;

#[derive(Debug, Default, Clone)]
pub struct Token {
    pub token_type: TokenType,
    pub literal: String,
    /// Start position (inclusive) in grapheme indices.
    #[allow(dead_code)]
    pub start: usize,
    /// End position (exclusive) in grapheme indices.
    #[allow(dead_code)]
    pub end: usize,
}

fn is_segment_character(ch: &char) -> bool {
    ch.is_whitespace() || *ch == '(' || *ch == ')' || *ch == '\0'
}

fn is_segment_character_str(ch: &str) -> bool {
    ch.nfc()
        .collect::<String>()
        .chars()
        .all(|c| is_segment_character(&c))
}

#[derive(Debug, Default)]
pub struct Lexer {
    input: String,
    // This is the position of the next grapheme char we will read
    // I am talking about grapheme char here becaues one single glyph
    // can have a size > 1 (multi-byte character)
    position: usize,
    // This is the position of the grapheme char we have read
    read_position: usize,
    ch: Option<String>,
}

impl Lexer {
    fn get_input_len(&self) -> usize {
        self.input.graphemes(true).collect::<Vec<_>>().len()
    }

    pub fn new(input: String) -> Lexer {
        let mut lexer = Lexer {
            input,
            position: 0,
            read_position: 0,
            ch: None,
        };
        lexer.read_char();
        lexer
    }

    fn read_char(&mut self) {
        if self.read_position >= self.get_input_len() {
            self.ch = None;
        } else {
            self.ch = self
                .input
                .graphemes(true)
                .nth(self.read_position)
                .map(|s| s.to_string());
        }
        self.position = self.read_position;
        self.read_position += 1;
    }

    // Helper method to check if the current character is a digit
    fn is_digit(&self) -> bool {
        if let Some(c_as_tr) = &self.ch {
            let c = c_as_tr.chars().next();
            return matches!(c, Some(c) if c.is_ascii_digit());
        }
        false
    }

    // Method to read an integer
    fn read_int(&mut self) -> String {
        let mut output_str = String::default();
        while self.is_digit() {
            if let Some(c) = &self.ch {
                output_str.push_str(c);
            }
            self.read_char();
        }
        output_str
    }

    // Method to check if the current substring is a valid UUID
    fn is_uuid(&self) -> bool {
        let end_pos = self.position + 36; // UUID length is 36
        if end_pos > self.get_input_len() {
            return false;
        }

        let potential_uuid_str = self
            .input
            .graphemes(true)
            .skip(self.position)
            .take(end_pos - self.position)
            .collect::<String>();
        Uuid::parse_str(&potential_uuid_str).is_ok()
    }

    // Method to check and read a UUID
    fn read_uuid(&mut self) -> CoreResult<String> {
        let end_pos = self.position + 36;
        if end_pos > self.get_input_len() {
            return Err(CoreError::parse("Not a valid UUID string"));
        }

        let uuid_str = self
            .input
            .graphemes(true)
            .skip(self.position)
            .take(end_pos - self.position)
            .collect::<String>();

        if Uuid::parse_str(&uuid_str).is_ok() {
            self.position = end_pos;
            self.read_position = end_pos;
            self.ch = self
                .input
                .graphemes(true)
                .nth(end_pos)
                .map(|s| s.to_string());
            Ok(uuid_str.to_string())
        } else {
            Err(CoreError::parse("Not a valid UUID string"))
        }
    }

    // Helper method to check if the current character is part of a word (i.e. not a segmentation
    // character and not a numeric character)
    fn is_word_character(&self) -> bool {
        if let Some(grapheme) = &self.ch {
            return grapheme
                .nfc()
                .collect::<String>()
                .chars()
                .all(|c| c.is_alphabetic());
        }
        false
    }

    // Method to match a specific keyword without consuming the input (case-insensitive)
    fn match_keyword(&self, word: &str) -> bool {
        self.input
            .graphemes(true)
            .skip(self.position)
            .collect::<String>()
            .to_lowercase()
            .starts_with(&word.to_lowercase())
    }

    fn read_next_word(&mut self) -> String {
        let mut output_str = String::default();
        while let Some(ch) = &self.ch {
            if ch
                .nfc()
                .collect::<String>()
                .chars()
                .all(|c| is_segment_character(&c) || c == '-' || c == '+')
            {
                break;
            }
            if let Some(c) = &self.ch {
                output_str.push_str(c);
            }
            self.read_char();
        }
        output_str
    }

    // This reads the word given as parameter. If the next characters do not
    // correspond to the word given, this will PANIC
    fn read_word(&mut self, word: &str) -> String {
        if !self.match_keyword(word) {
            panic!("error in read_word: Trying to read a word that can't be found");
        }

        let mut output_str = String::default();
        for _ in 0..word.len() {
            if let Some(c) = &self.ch {
                output_str.push_str(c);
            }
            self.read_char();
        }

        output_str
    }

    pub fn next_token(&mut self) -> CoreResult<Token> {
        let token_start = self.position;
        let mut whitespaces = String::default();
        while matches!(&self.ch, Some(ch) if ch
                .nfc()
                .collect::<String>()
                .chars()
                .all(|c| c.is_whitespace()))
        {
            whitespaces += &self.ch.as_ref().unwrap().to_string();
            self.read_char();
        }
        if !whitespaces.is_empty() {
            return Ok(Token {
                literal: whitespaces,
                token_type: TokenType::Blank,
                start: token_start,
                end: self.position,
            });
        }

        let token_start = self.position;
        let (token_type, literal) = match &self.ch {
            None => (TokenType::Eof, String::new()),
            Some(ch) => match ch {
                _ if self.is_uuid() => {
                    trace!("Token '{}' is a UUID", ch);
                    (TokenType::Uuid, self.read_uuid()?)
                }
                _ if self.is_digit() => {
                    trace!("Token '{}' is a digit", ch);
                    (TokenType::Int, self.read_int())
                }
                _ if ch == "+" => {
                    trace!("Token '{}' is a TagPlusPrefix", ch);
                    self.read_char();
                    (TokenType::TagPlusPrefix, "+".to_owned())
                }
                _ if ch == "-" => {
                    trace!("Token '{}' is a TagMinusPrefix", ch);
                    self.read_char();
                    (TokenType::TagMinusPrefix, "-".to_owned())
                }
                _ if self.match_keyword("and") => {
                    let mut literal_value = self.read_word("and");

                    let token_type = match &self.ch {
                        Some(c) if !is_segment_character_str(c) => {
                            literal_value += &self.read_next_word();
                            TokenType::WordString
                        }
                        _ => TokenType::OperatorAnd,
                    };

                    trace!("Token '{}' is a {}", literal_value, token_type);
                    (token_type, literal_value)
                }
                _ if self.match_keyword("or") => {
                    let mut literal_value = self.read_word("or");

                    let token_type = match &self.ch {
                        Some(c) if !is_segment_character_str(c) => {
                            literal_value += &self.read_next_word();
                            TokenType::WordString
                        }
                        _ => TokenType::OperatorOr,
                    };

                    trace!("Token '{}' is a {}", literal_value, token_type);
                    (token_type, literal_value)
                }
                _ if self.match_keyword("xor") => {
                    let mut literal_value = self.read_word("xor");

                    let token_type = match &self.ch {
                        Some(c) if !is_segment_character_str(c) => {
                            literal_value += &self.read_next_word();
                            TokenType::WordString
                        }
                        _ => TokenType::OperatorXor,
                    };

                    trace!("Token '{}' is a {}", literal_value, token_type);
                    (token_type, literal_value)
                }
                _ if self.match_keyword("status:") => {
                    (TokenType::FilterStatus, self.read_word("status:"))
                }
                _ if self.match_keyword("created.after:") => (
                    TokenType::FilterTokDateCreatedAfter,
                    self.read_word("created.after:"),
                ),
                _ if self.match_keyword("created.before:") => (
                    TokenType::FilterTokDateCreatedBefore,
                    self.read_word("created.before:"),
                ),
                _ if self.match_keyword("end.after:") => (
                    TokenType::FilterTokDateEndAfter,
                    self.read_word("end.after:"),
                ),
                _ if self.match_keyword("end.before:") => (
                    TokenType::FilterTokDateEndBefore,
                    self.read_word("end.before:"),
                ),
                _ if self.match_keyword("project:") => {
                    (TokenType::ProjectPrefix, self.read_word("project:"))
                }
                _ if self.match_keyword("due:") => {
                    (TokenType::FilterTokDateDue, self.read_word("due:"))
                }
                _ if self.match_keyword("due.before:") => (
                    TokenType::FilterTokDateDueBefore,
                    self.read_word("due.before:"),
                ),
                _ if self.match_keyword("due.after:") => (
                    TokenType::FilterTokDateDueAfter,
                    self.read_word("due.after:"),
                ),
                _ if self.match_keyword("proj:") => {
                    (TokenType::ProjectPrefix, self.read_word("proj:"))
                }
                _ if self.match_keyword("depends:") => {
                    (TokenType::DependsOn, self.read_word("depends:"))
                }
                _ if self.match_keyword("blocks:") => {
                    (TokenType::Blocks, self.read_word("blocks:"))
                }
                _ if self.match_keyword("parent:") => {
                    (TokenType::ParentOf, self.read_word("parent:"))
                }
                _ if self.match_keyword("child:") => (TokenType::ChildOf, self.read_word("child:")),
                _ if self.match_keyword("related:") => {
                    (TokenType::RelatedTo, self.read_word("related:"))
                }
                _ if self.match_keyword("duplicates:") => {
                    (TokenType::Duplicates, self.read_word("duplicates:"))
                }
                _ if ch == ")" => {
                    self.read_char();
                    (TokenType::RightParenthesis, ")".to_string())
                }
                _ if ch == "(" => {
                    self.read_char();
                    (TokenType::LeftParenthesis, "(".to_string())
                }
                _ if self.is_word_character() => {
                    let next_word = self.read_next_word();
                    trace!("Token '{}' is a WordString", next_word);
                    (TokenType::WordString, next_word)
                }
                _ => {
                    let next_word = self.read_next_word();
                    trace!("Token '{}' is a WordString", next_word);
                    (TokenType::String, next_word)
                }
            },
        };

        Ok(Token {
            token_type,
            literal,
            start: token_start,
            end: self.position,
        })
    }
}
