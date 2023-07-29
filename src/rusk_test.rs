#[cfg(test)]
use super::*;

// Tests for the parse_command_line function
#[test]
fn test_parse_command_line_add_command() {
    let args = vec!["prgm".to_string(), "arg1".to_string(), "arg2".to_string(), "add".to_string(), "This is a task".to_string()];
    let cmd_args = parse_command_line(&args);
    assert_eq!(cmd_args.command, Command::Add);
    assert_eq!(cmd_args.text, Some("This is a task".to_string()));
    assert_eq!(cmd_args.filters, vec!["arg1".to_string(), "arg2".to_string()]);
}

#[test]
fn test_parse_command_line_list_command() {
    let args = vec!["prgm".to_string(), "arg1".to_string(), "list".to_string()];
    let cmd_args = parse_command_line(&args);
    assert_eq!(cmd_args.command, Command::List);
    assert_eq!(cmd_args.text, None);
    assert_eq!(cmd_args.filters, vec!["arg1".to_string()]);
}

#[test]
fn test_parse_command_line_sync_command() {
    let args = vec!["prgm".to_string(), "sync".to_string()];
    let cmd_args = parse_command_line(&args);
    assert_eq!(cmd_args.command, Command::Sync);
    assert_eq!(cmd_args.text, None);
    assert_eq!(cmd_args.filters, Vec::<String>::default());
}

#[test]
fn test_parse_command_line_default_command() {
    let args = vec!["prgm".to_string(), "arg1".to_string(), "arg2".to_string()];
    let cmd_args = parse_command_line(&args);
    assert_eq!(cmd_args.command, Command::List);
    assert_eq!(cmd_args.text, None);
    assert_eq!(cmd_args.filters, vec!["arg1".to_string(), "arg2".to_string()]);
}

// Tests for is_command function
#[test]
fn test_is_command_valid_command() {
    assert_eq!(is_command("add"), true);
    assert_eq!(is_command("done"), true);
    assert_eq!(is_command("delete"), true);
    assert_eq!(is_command("list"), true);
    assert_eq!(is_command("sync"), true);
}

#[test]
fn test_is_command_invalid_command() {
    assert_eq!(is_command("update"), false);
    assert_eq!(is_command("show"), false);
    assert_eq!(is_command("create"), false);
    assert_eq!(is_command("invalid"), false);
}

// Tests for parse_command function
#[test]
fn test_parse_command_valid_command() {
    assert_eq!(parse_command("add"), Command::Add);
    assert_eq!(parse_command("done"), Command::Complete);
    assert_eq!(parse_command("delete"), Command::Delete);
    assert_eq!(parse_command("list"), Command::List);
    assert_eq!(parse_command("sync"), Command::Sync);
}

#[test]
fn test_parse_command_invalid_command() {
    assert_eq!(parse_command("update"), Command::List);
    assert_eq!(parse_command("show"), Command::List);
    assert_eq!(parse_command("create"), Command::List);
    assert_eq!(parse_command("invalid"), Command::List);
}

