use log::trace;
use unicode_normalization::UnicodeNormalization;
use unicode_segmentation::UnicodeSegmentation;
use uuid::Uuid;

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
    fn read_uuid(&mut self) -> Result<String, String> {
        let end_pos = self.position + 36;
        if end_pos > self.get_input_len() {
            return Err("Not a valid UUID string".to_string());
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
            Err("Not a valid UUID string".to_string())
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

    // Method to match a specific keyword without consuming the input
    fn match_keyword(&self, word: &str) -> bool {
        self.input
            .graphemes(true)
            .skip(self.position)
            .collect::<String>()
            .starts_with(word)
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

    pub fn next_token(&mut self) -> Result<Token, String> {
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
            });
        }

        let token = match &self.ch {
            None => Token {
                token_type: TokenType::Eof,
                literal: String::new(),
            },
            Some(ch) => match ch {
                _ if self.is_uuid() => {
                    trace!("Token '{}' is a UUID", ch);
                    Token {
                        literal: self.read_uuid()?,
                        token_type: TokenType::Uuid,
                    }
                }
                _ if self.is_digit() => {
                    trace!("Token '{}' is a digit", ch);
                    Token {
                        token_type: TokenType::Int,
                        literal: self.read_int(),
                    }
                }
                _ if ch == "+" => {
                    trace!("Token '{}' is a TagPlusPrefix", ch);
                    self.read_char();
                    Token {
                        token_type: TokenType::TagPlusPrefix,
                        literal: "+".to_owned(),
                    }
                }
                _ if ch == "-" => {
                    trace!("Token '{}' is a TagMinusPrefix", ch);
                    self.read_char();
                    Token {
                        token_type: TokenType::TagMinusPrefix,
                        literal: "-".to_owned(),
                    }
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
                    Token {
                        literal: literal_value,
                        token_type,
                    }
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
                    Token {
                        literal: literal_value,
                        token_type,
                    }
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
                    Token {
                        literal: literal_value,
                        token_type,
                    }
                }
                _ if self.match_keyword("status:") => Token {
                    literal: self.read_word("status:"),
                    token_type: TokenType::FilterStatus,
                },
                _ if self.match_keyword("created.after:") => Token {
                    literal: self.read_word("created.after:"),
                    token_type: TokenType::FilterTokDateCreatedAfter,
                },
                _ if self.match_keyword("created.before:") => Token {
                    literal: self.read_word("created.before:"),
                    token_type: TokenType::FilterTokDateCreatedBefore,
                },
                _ if self.match_keyword("end.after:") => Token {
                    literal: self.read_word("end.after:"),
                    token_type: TokenType::FilterTokDateEndAfter,
                },
                _ if self.match_keyword("end.before:") => Token {
                    literal: self.read_word("end.before:"),
                    token_type: TokenType::FilterTokDateEndBefore,
                },
                _ if self.match_keyword("project:") => Token {
                    literal: self.read_word("project:"),
                    token_type: TokenType::ProjectPrefix,
                },
                _ if self.match_keyword("due:") => Token {
                    literal: self.read_word("due:"),
                    token_type: TokenType::FilterTokDateDue,
                },
                _ if self.match_keyword("due.before:") => Token {
                    literal: self.read_word("due.before:"),
                    token_type: TokenType::FilterTokDateDueBefore,
                },
                _ if self.match_keyword("due.after:") => Token {
                    literal: self.read_word("due.after:"),
                    token_type: TokenType::FilterTokDateDueAfter,
                },
                _ if self.match_keyword("proj:") => Token {
                    literal: self.read_word("proj:"),
                    token_type: TokenType::ProjectPrefix,
                },
                _ if self.match_keyword("depends:") => Token {
                    literal: self.read_word("depends:"),
                    token_type: TokenType::DependsOn,
                },
                _ if ch == ")" => {
                    self.read_char();
                    Token {
                        literal: ")".to_string(),
                        token_type: TokenType::RightParenthesis,
                    }
                }
                _ if ch == "(" => {
                    self.read_char();
                    Token {
                        literal: "(".to_string(),
                        token_type: TokenType::LeftParenthesis,
                    }
                }
                _ if self.is_word_character() => {
                    let next_word = self.read_next_word();
                    trace!("Token '{}' is a WordString", next_word);
                    Token {
                        literal: next_word,
                        token_type: TokenType::WordString,
                    }
                }
                _ => {
                    let next_word = self.read_next_word();
                    trace!("Token '{}' is a WordString", next_word);
                    Token {
                        literal: next_word,
                        token_type: TokenType::String,
                    }
                }
            },
        };

        Ok(token)
    }
}
