use uuid::Uuid;

#[derive(Debug, PartialEq, Default, Clone)]
pub enum TokenType {
    FilterTokDateCreatedBefore,
    FilterTokDateCreatedAfter,
    FilterTokDateEndBefore,
    FilterTokDateEndAfter,
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

pub struct Lexer {
    input: String,
    position: usize,
    read_position: usize,
    ch: Option<char>,
}

impl Lexer {
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
        if self.read_position >= self.input.len() {
            self.ch = None;
        } else {
            self.ch = Some(self.input.chars().nth(self.read_position).unwrap());
        }
        self.position = self.read_position;
        self.read_position += 1;
    }

    // Helper method to check if the current character is a digit
    fn is_digit(&self) -> bool {
        matches!(self.ch, Some(ch) if ch.is_ascii_digit())
    }

    // Method to read an integer
    fn read_int(&mut self) -> String {
        let starting_pos = self.position;
        while self.is_digit() {
            self.read_char();
        }
        self.input[starting_pos..self.position].to_string()
    }

    // Method to check if the current substring is a valid UUID
    fn is_uuid(&self) -> bool {
        let end_pos = self.position + 36; // UUID length is 36
        if end_pos > self.input.len() {
            return false;
        }

        Uuid::parse_str(&self.input[self.position..end_pos]).is_ok()
    }

    // Method to check and read a UUID
    fn read_uuid(&mut self) -> Result<String, String> {
        let end_pos = self.position + 36;
        if end_pos > self.input.len() {
            return Err("Not a valid UUID string".to_string());
        }

        let uuid_str = &self.input[self.position..end_pos];
        if Uuid::parse_str(uuid_str).is_ok() {
            self.position = end_pos;
            self.read_position = end_pos;
            self.ch = self.input.chars().nth(end_pos);
            Ok(uuid_str.to_string())
        } else {
            Err("Not a valid UUID string".to_string())
        }
    }

    // Helper method to check if the current character is part of a word (i.e. not a segmentation
    // character and not a numeric character)
    fn is_word_character(&self) -> bool {
        matches!(self.ch, Some(ch) if !is_segment_character(&ch) && ch.is_ascii_alphabetic())
    }

    // Method to match a specific keyword without consuming the input
    fn match_keyword(&self, word: &str) -> bool {
        self.input[self.position..].starts_with(word)
    }

    fn read_next_word(&mut self) -> String {
        let starting_pos = self.position;
        while let Some(ch) = self.ch {
            if is_segment_character(&ch) || ch == '-' || ch == '+' {
                break;
            }
            self.read_char();
        }
        self.input[starting_pos..self.position].to_string()
    }

    fn read_word(&mut self, word: &str) -> String {
        if !self.match_keyword(word) {
            panic!("error in read_word: Trying to read a word that can't be found");
        }

        let start_pos = self.position;
        for _ in 0..word.len() {
            self.read_char();
        }

        self.input[start_pos..self.position].to_string()
    }

    pub fn next_token(&mut self) -> Result<Token, String> {
        let mut whitespaces = String::default();
        while matches!(self.ch, Some(ch) if ch.is_whitespace()) {
            whitespaces += &self.ch.unwrap().to_string();
            self.read_char();
        }
        if !whitespaces.is_empty() {
            return Ok(Token {
                literal: whitespaces,
                token_type: TokenType::Blank,
            });
        }

        let token = match self.ch {
            None => Token {
                token_type: TokenType::Eof,
                literal: String::new(),
            },
            Some(ch) => match ch {
                _ if self.is_uuid() => Token {
                    literal: self.read_uuid()?,
                    token_type: TokenType::Uuid,
                },
                _ if self.is_digit() => Token {
                    token_type: TokenType::Int,
                    literal: self.read_int(),
                },
                _ if ch == '+' => {
                    self.read_char();
                    Token {
                        token_type: TokenType::TagPlusPrefix,
                        literal: "+".to_owned(),
                    }
                }
                _ if ch == '-' => {
                    self.read_char();
                    Token {
                        token_type: TokenType::TagMinusPrefix,
                        literal: "-".to_owned(),
                    }
                }
                _ if self.match_keyword("and") => {
                    let mut literal_value = self.read_word("and");

                    let token_type = match self.ch {
                        Some(c) if !is_segment_character(&c) => {
                            literal_value += &self.read_next_word();
                            TokenType::WordString
                        }
                        _ => TokenType::OperatorAnd,
                    };

                    Token {
                        literal: literal_value,
                        token_type,
                    }
                }
                _ if self.match_keyword("or") => {
                    let mut literal_value = self.read_word("or");

                    let token_type = match self.ch {
                        Some(c) if !is_segment_character(&c) => {
                            literal_value += &self.read_next_word();
                            TokenType::WordString
                        }
                        _ => TokenType::OperatorOr,
                    };

                    Token {
                        literal: literal_value,
                        token_type,
                    }
                }
                _ if self.match_keyword("xor") => {
                    let mut literal_value = self.read_word("xor");

                    let token_type = match self.ch {
                        Some(c) if !is_segment_character(&c) => {
                            literal_value += &self.read_next_word();
                            TokenType::WordString
                        }
                        _ => TokenType::OperatorXor,
                    };

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
                _ if self.match_keyword("proj:") => Token {
                    literal: self.read_word("proj:"),
                    token_type: TokenType::ProjectPrefix,
                },
                _ if ch == ')' => {
                    self.read_char();
                    Token {
                        literal: ")".to_string(),
                        token_type: TokenType::RightParenthesis,
                    }
                }
                _ if ch == '(' => {
                    self.read_char();
                    Token {
                        literal: "(".to_string(),
                        token_type: TokenType::LeftParenthesis,
                    }
                }
                _ if self.is_word_character() => Token {
                    literal: self.read_next_word(),
                    token_type: TokenType::WordString,
                },
                _ => Token {
                    literal: self.read_next_word(),
                    token_type: TokenType::String,
                },
            },
        };

        Ok(token)
    }
}
