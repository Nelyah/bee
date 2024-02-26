use crate::{filters, task::TaskStatus};

use super::*; // Import necessary structs, enums, and functions from the parent module

#[test]
fn test_new_parser() {
    let lexer = Lexer::new("some input string".to_string());
    let mut p = ParserN::new(lexer);

    assert_eq!(
        p.current_token.literal, "some",
        "should have been correctly initialised"
    );
    assert_eq!(
        p.peek_token.literal, "input",
        "should have been correctly initialised"
    );

    p.next_token();
    assert_eq!(p.current_token.literal, "input", "advances correctly");
    assert_eq!(p.peek_token.literal, "string", "advances correctly");

    p.next_token();
    assert_eq!(p.current_token.literal, "string", "advances correctly");
    assert_eq!(
        p.peek_token.token_type,
        TokenType::Eof,
        "advances correctly"
    );
}

#[test]
fn test_add_string_to_current_filter() {
    let mut lhs: Box<dyn Filter> = add_to_current_filter(
        Box::new(StringFilter {
            value: "testValue".to_owned(),
        }),
        Box::new(StringFilter {
            value: "first value".to_owned(),
        }),
        &ScopeOperator::None,
    );
    let mut rhs: Box<dyn Filter> = Box::new(AndFilter {
        children: vec![
            Box::new(StringFilter {
                value: "testValue".to_owned(),
            }),
            Box::new(StringFilter {
                value: "first value".to_owned(),
            }),
        ],
    });
    assert_eq!(&lhs, &rhs,);

    lhs = add_to_current_filter(
        Box::new(StringFilter {
            value: "testValue".to_owned(),
        }),
        Box::new(StringFilter {
            value: "first value".to_owned(),
        }),
        &ScopeOperator::And,
    );
    rhs = Box::new(AndFilter {
        children: vec![
            Box::new(StringFilter {
                value: "testValue".to_owned(),
            }),
            Box::new(StringFilter {
                value: "first value".to_owned(),
            }),
        ],
    });
    assert_eq!(&lhs, &rhs);
}

#[test]
fn test_parse_filter() {
    let lexer = Lexer::new("some status: completed or status:pending".to_string());
    let mut p = ParserN::new(lexer);
    let f = p.parse_filter();

    let expected_filter: Box<dyn Filter> = Box::new(OrFilter {
        children: vec![
            Box::new(AndFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "some".to_owned(),
                    }),
                    Box::new(StatusFilter {
                        status: TaskStatus::Completed,
                    }),
                ],
            }),
            Box::new(StatusFilter {
                status: TaskStatus::Pending,
            }),
        ],
    });
    assert_eq!(&f, &expected_filter);
}

#[test]
fn test_build_filter() {
    // Empty input
    let expected = filters::new_empty();
    let actual = filters::from(&[]);
    assert_eq!(&expected, &actual, "they should be equal");

    // Operator AND and empty operator
    let mut expected: Box<dyn Filter> = Box::new(AndFilter {
        children: vec![
            Box::new(StringFilter {
                value: "one".to_owned(),
            }),
            Box::new(StringFilter {
                value: "two".to_owned(),
            }),
        ],
    });
    let actual = filters::from(
        &["one", "and", "two"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    assert_eq!(&actual, &expected);
    let actual = filters::from(
        &["one", "two"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    assert_eq!(&expected, &actual);

    // Operator OR
    expected = Box::new(OrFilter {
        children: vec![
            Box::new(StringFilter {
                value: "one".to_owned(),
            }),
            Box::new(StringFilter {
                value: "two".to_owned(),
            }),
        ],
    });
    let actual = filters::from(
        &["one", "or", "two"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    assert_eq!(&expected, &actual, "they should be equal");

    // Operator XOR
    expected = Box::new(XorFilter {
        children: vec![
            Box::new(StringFilter {
                value: "one".to_owned(),
            }),
            Box::new(StringFilter {
                value: "two".to_owned(),
            }),
        ],
    });
    let actual = filters::from(
        &["one", "xor", "two"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    assert_eq!(&expected, &actual, "they should be equal");

    // Operator OR and AND
    let uuid_test = uuid::Uuid::new_v4();
    expected = Box::new(OrFilter {
        children: vec![
            Box::new(UuidFilter { uuid: uuid_test }),
            Box::new(AndFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "two".to_owned(),
                    }),
                    Box::new(StringFilter {
                        value: "three".to_owned(),
                    }),
                ],
            }),
        ],
    });
    let actual = filters::from(
        &[&uuid_test.to_string(), "or", "two", "and", "three"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    assert_eq!(&expected, &actual, "they should be equal");

    // Operator OR and AND with parenthesis
    // Note: Handling parenthesis might require additional parsing logic
    let actual = filters::from(
        &["(one", "or", "+two)", "and", "-three"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    assert_ne!(&expected, &actual, "they should not be equal");

    expected = Box::new(AndFilter {
        children: vec![
            Box::new(OrFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "one".to_owned(),
                    }),
                    Box::new(TagFilter {
                        include: true,
                        tag_name: "two".to_owned(),
                    }),
                ],
            }),
            Box::new(TagFilter {
                include: false,
                tag_name: "three".to_owned(),
            }),
        ],
    });
    assert_eq!(&expected, &actual, "they should be equal");

    // Operator OR and AND with parenthesis and XOR
    let actual = filters::from(
        &["(one", "or", "two)", "xor", "three"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    assert_ne!(&expected, &actual, "they should not be equal");

    expected = Box::new(XorFilter {
        children: vec![
            Box::new(OrFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "one".to_owned(),
                    }),
                    Box::new(StringFilter {
                        value: "two".to_owned(),
                    }),
                ],
            }),
            Box::new(StringFilter {
                value: "three".to_owned(),
            }),
        ],
    });
    assert_eq!(&expected, &actual, "they should be equal");

    // Extended XOR case
    let actual = filters::from(
        &["(one", "or", "two)", "xor", "three", "and", "four"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    assert_ne!(&expected, &actual, "they should not be equal");

    expected = Box::new(XorFilter {
        children: vec![
            Box::new(OrFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "one".to_owned(),
                    }),
                    Box::new(StringFilter {
                        value: "two".to_owned(),
                    }),
                ],
            }),
            Box::new(AndFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "three".to_owned(),
                    }),
                    Box::new(StringFilter {
                        value: "four".to_owned(),
                    }),
                ],
            }),
        ],
    });
    assert_eq!(&expected, &actual, "they should be equal");

    // Simple OR case with numbers
    let actual = filters::from(
        &["1", "4"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    expected = Box::new(OrFilter {
        children: vec![
            Box::new(TaskIdFilter { id: 1 }),
            Box::new(TaskIdFilter { id: 4 }),
        ],
    });
    assert_eq!(&expected, &actual, "they should be equal");

    // Simple AND case with mixed inputs
    let actual = filters::from(
        &["1", "4", "hello"]
            .iter()
            .map(|&s| s.to_string())
            .collect::<Vec<String>>(),
    );
    expected = Box::new(AndFilter {
        children: vec![
            Box::new(AndFilter {
                children: vec![
                    Box::new(TaskIdFilter { id: 1 }),
                    Box::new(TaskIdFilter { id: 4 }),
                ],
            }),
            Box::new(StringFilter {
                value: "hello".to_owned(),
            }),
        ],
    });
    assert_eq!(&expected, &actual, "they should be equal");
}
