mod config;
pub mod parser;
pub mod lexer;
pub mod storage;
pub mod task;
pub mod actions;

use config::CONFIG;

fn main() {

    println!("hello world");

    println!("{}", CONFIG.default_report);
    println!("default report is {}", CONFIG.default_report);
}
