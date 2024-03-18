#[cfg(test)]
use super::*;

#[test]
fn test_lexer() {
    let mut lexer = Lexer::new("00.".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "00");
    assert_eq!(tok.token_type, TokenType::Int);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, ".");
    assert_eq!(tok.token_type, TokenType::String);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "");
    assert_eq!(tok.token_type, TokenType::Eof);

    let mut lexer = Lexer::new("1y".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "1");
    assert_eq!(tok.token_type, TokenType::Int);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "y");
    assert_eq!(tok.token_type, TokenType::WordString);

    let mut lexer = Lexer::new("y1y".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "y1y");
    assert_eq!(tok.token_type, TokenType::WordString);

    let mut lexer = Lexer::new("00".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "00");
    assert_eq!(tok.token_type, TokenType::Int);

    let mut lexer = Lexer::new("+main".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "+");
    assert_eq!(tok.token_type, TokenType::TagPlusPrefix);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "main");
    assert_eq!(tok.token_type, TokenType::WordString);

    let mut lexer = Lexer::new("-main".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "-");
    assert_eq!(tok.token_type, TokenType::TagMinusPrefix);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "main");
    assert_eq!(tok.token_type, TokenType::WordString);

    let mut lexer = Lexer::new("- main".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "-");
    assert_eq!(tok.token_type, TokenType::TagMinusPrefix);

    let mut lexer = Lexer::new("end.after:".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "end.after:");
    assert_eq!(tok.token_type, TokenType::FilterTokDateEndAfter);

    let mut lexer = Lexer::new("end.before:".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "end.before:");
    assert_eq!(tok.token_type, TokenType::FilterTokDateEndBefore);

    let mut lexer = Lexer::new("status:pending".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "status:");
    assert_eq!(tok.token_type, TokenType::FilterStatus);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "pending");
    assert_eq!(tok.token_type, TokenType::WordString);

    let mut lexer = Lexer::new(")(".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, ")");
    assert_eq!(tok.token_type, TokenType::RightParenthesis);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "(");
    assert_eq!(tok.token_type, TokenType::LeftParenthesis);
}

#[test]
fn test_lexer_operators() {
    let mut lexer = Lexer::new("and".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "and");
    assert_eq!(tok.token_type, TokenType::OperatorAnd);

    let mut lexer = Lexer::new("or".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "or");
    assert_eq!(tok.token_type, TokenType::OperatorOr);

    let mut lexer = Lexer::new("xor".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "xor");
    assert_eq!(tok.token_type, TokenType::OperatorXor);

    let mut lexer = Lexer::new("ands".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "ands");
    assert_eq!(tok.token_type, TokenType::WordString);

    let mut lexer = Lexer::new("ore".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "ore");
    assert_eq!(tok.token_type, TokenType::WordString);

    let mut lexer = Lexer::new("xore".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "xore");
    assert_eq!(tok.token_type, TokenType::WordString);

    let mut lexer = Lexer::new("xore xor hand(".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "xore");
    assert_eq!(tok.token_type, TokenType::WordString);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, " ");
    assert_eq!(tok.token_type, TokenType::Blank);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "xor");
    assert_eq!(tok.token_type, TokenType::OperatorXor);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, " ");
    assert_eq!(tok.token_type, TokenType::Blank);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "hand");
    assert_eq!(tok.token_type, TokenType::WordString);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "(");
    assert_eq!(tok.token_type, TokenType::LeftParenthesis);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "");
    assert_eq!(tok.token_type, TokenType::Eof);
}

#[test]
fn test_lexer_with_spaces() {
    let mut lexer = Lexer::new("status:  pending".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "status:");
    assert_eq!(tok.token_type, TokenType::FilterStatus);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "  ");
    assert_eq!(tok.token_type, TokenType::Blank);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "pending");
    assert_eq!(tok.token_type, TokenType::WordString);

    let mut lexer = Lexer::new("\t)   (\n".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "\t");
    assert_eq!(tok.token_type, TokenType::Blank);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, ")");
    assert_eq!(tok.token_type, TokenType::RightParenthesis);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "   ");
    assert_eq!(tok.token_type, TokenType::Blank);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "(");
    assert_eq!(tok.token_type, TokenType::LeftParenthesis);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "\n");
    assert_eq!(tok.token_type, TokenType::Blank);
}
