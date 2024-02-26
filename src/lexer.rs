use uuid::Uuid;

#[derive(Debug, PartialEq)]
enum TokenType {
    String,
    TagPlus,
    TagMinus,
    FilterStatus,
    Int,
    Uuid,
    Eof,
    LeftParenthesis,
    RightParenthesis,
    OperatorAnd,
    OperatorOr,
    OperatorXor,
}

#[derive(Debug)]
struct Token {
    token_type: TokenType,
    literal: String,
}

struct Lexer {
    input: String,
    position: usize,
    read_position: usize,
    ch: Option<char>,
}

impl Lexer {
    fn new(input: String) -> Lexer {
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
        matches!(self.ch, Some(ch) if ch.is_digit(10))
    }

    // Method to read an integer
    fn read_int(&mut self) -> String {
        let starting_pos = self.position;
        while self.is_digit() {
            self.read_char();
        }
        self.input[starting_pos..self.position].to_string()
    }

    // Helper method to check if a character is a space
    fn is_space_character(&self) -> bool {
        matches!(self.ch, Some(ch) if ch.is_whitespace())
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

    fn is_tag_prefix(&self) -> bool {
        matches!(self.ch, Some('+') | Some('-'))
    }

    // Method to read a tag
    fn read_tag(&mut self) -> Result<String, String> {
        if !self.is_tag_prefix() {
            return Err("Input doesn't start with a tag prefix".to_string());
        }
        let starting_pos = self.position;
        self.read_char(); // Skip tag prefix

        // Check for word characters after tag prefix
        while matches!(self.ch, Some(ch) if ch.is_alphanumeric() || ch == '_') {
            self.read_char();
        }

        Ok(self.input[starting_pos..self.position].to_string())
    }

    // Helper method to check if the current character is part of a word
    fn is_word_character(&self) -> bool {
        matches!(self.ch, Some(ch) if ch.is_alphanumeric() || ch == '_')
    }

    // Method to match a specific keyword
    fn match_keyword(&self, word: &str) -> bool {
        self.input[self.position..].starts_with(word) && !self.is_word_character()
    }

    // Method to read the next word
    fn read_next_word(&mut self) -> String {
        let starting_pos = self.position;
        while !matches!(self.ch, Some(ch) if ch.is_whitespace() || ch == '(' || ch == ')' || ch == '\0')
        {
            self.read_char();
        }
        self.input[starting_pos..self.position].to_string()
    }

    // Method to tokenize the next part of the input
    fn next_token(&mut self) -> Result<Token, String> {
        // Skip whitespace
        while self.is_space_character() {
            self.read_char();
        }

        // Define the token based on the current character
        let token = match self.ch {
            None => Token {
                token_type: TokenType::Eof,
                literal: String::new(),
            },
            Some(ch) => match ch {
                // Handle different character types (e.g., digits, parentheses)
                // ...

                // Example for a digit
                _ if ch.is_digit(10) => Token {
                    token_type: TokenType::Int,
                    literal: self.read_int(),
                },

                // Example for a UUID
                _ => {
                    let uuid = self.read_uuid()?;
                    Token {
                        token_type: TokenType::Uuid,
                        literal: uuid,
                    }
                }
            },
        };

        // Read the next character and return the token
        self.read_char();
        Ok(token)
    }

    // Other helper methods...
}
