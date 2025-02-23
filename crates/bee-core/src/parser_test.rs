use super::*;

fn init() {
    let _ = env_logger::builder().is_test(true).try_init();
}

#[derive(Debug, Default)]
pub struct MockParser {
    lexer: Lexer,
    current_token: Token,
    peek_token: Token,
    buffer_tokens: Vec<Token>,
    buffer_index: usize,
}

impl MockParser {
    pub fn new(lexer: Lexer) -> MockParser {
        let mut parser = MockParser {
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
}

impl BaseParser for MockParser {
    fn get_buffer_index(&self) -> usize {
        self.buffer_index
    }
    fn set_buffer_index(&mut self, value: usize) {
        self.buffer_index = value;
    }

    fn get_current_token(&self) -> &Token {
        &self.current_token
    }
    fn set_current_token(&mut self, tok: Token) {
        self.current_token = tok;
    }

    fn get_buffer_tokens(&self) -> &Vec<Token> {
        &self.buffer_tokens
    }
    fn get_mut_buffer_tokens(&mut self) -> &mut Vec<Token> {
        &mut self.buffer_tokens
    }

    fn get_peek_token(&self) -> &Token {
        &self.peek_token
    }
    fn set_peek_token(&mut self, tok: Token) {
        self.peek_token = tok;
    }

    fn get_mut_lexer(&mut self) -> &mut Lexer {
        &mut self.lexer
    }
}

#[test]
fn test_read_date_expr() {
    init();
    let now = Local::now();
    let today_start = Local
        .from_local_datetime(
            &now.date_naive()
                .and_time(NaiveTime::from_hms_opt(0, 0, 0).unwrap()),
        )
        .single()
        .unwrap();

    let lexer = Lexer::new("today".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    assert_eq!(res, today_start);

    let lexer = Lexer::new("tomorrow".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    assert_eq!(
        res.to_rfc2822(),
        (today_start + Duration::try_days(1).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("yesterday".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    assert_eq!(
        res.to_rfc2822(),
        (today_start - Duration::try_days(1).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("eod".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    assert_eq!(
        res.to_rfc2822(),
        (today_start + Duration::try_hours(18).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("now".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(res.to_rfc2822(), now.to_rfc2822());

    let lexer = Lexer::new("today - 1h".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (today_start - Duration::try_hours(1).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("today - 1m".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (today_start - Duration::try_minutes(1).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("today - 1s".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (today_start - Duration::try_seconds(1).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("today-11d".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (today_start - Duration::try_days(11).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("today - 1d".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (today_start - Duration::try_days(1).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("today - 1d + 1d".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(res.to_rfc2822(), today_start.to_rfc2822());

    let lexer = Lexer::new("today - 2w".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (today_start - Duration::try_days(14).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("today - 3 months".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (today_start - Duration::try_days(90).unwrap()).to_rfc2822()
    );

    let lexer = Lexer::new("in 3 days ago".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (now - Duration::try_days(3).unwrap()).to_rfc2822()
    );
    assert_eq!(p.current_token.token_type, TokenType::Blank);
    p.next_token();
    assert_eq!(p.current_token.token_type, TokenType::WordString);
    assert_eq!(p.current_token.literal, "ago".to_owned());

    let lexer = Lexer::new("today - 3 year".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (today_start - Duration::try_days(365 * 3).unwrap()).to_rfc2822()
    );

    // Ensure we stop after seeing 'ago'
    let lexer = Lexer::new("3 years ago today".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(
        res.to_rfc2822(),
        (now - Duration::try_days(365 * 3).unwrap()).to_rfc2822()
    );
    p.skip_whitespace();
    assert_eq!(p.current_token.token_type, TokenType::WordString);
    assert_eq!(p.current_token.literal, "today".to_owned());

    let lexer = Lexer::new("today -foo".to_string());
    let mut p = MockParser::new(lexer);

    let res = p.read_date_expr().unwrap();
    // This format doesn't print smaller units than seconds
    assert_eq!(res.to_rfc2822(), today_start.to_rfc2822());
    assert_eq!(p.current_token.token_type, TokenType::Blank);
    p.next_token();
    assert_eq!(p.current_token.token_type, TokenType::TagMinusPrefix);
    assert_eq!(p.peek_token.token_type, TokenType::WordString);
    assert_eq!(p.peek_token.literal, "foo".to_owned());
}
