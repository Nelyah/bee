mod config;
pub mod parser;
pub mod lexer;
pub mod storage;
pub mod task;
pub mod actions;

// use crate::task::manager::TaskData;
// use crate::storage::Store;
use crate::lexer::{Lexer,TokenType};

fn main() {
    print!("hello world");
    // storage::JsonStore::write_tasks(&TaskData::default())
    let mut lexer = Lexer::new("00.".to_string());
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, "00");
    assert_eq!(tok.token_type, TokenType::Int);
    let tok = lexer.next_token().unwrap();
    assert_eq!(tok.literal, ".");
    assert_eq!(tok.token_type, TokenType::String);

}
