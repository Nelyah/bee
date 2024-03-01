#[cfg(test)]
use super::*; // Import necessary structs, enums, and functions from the parent module

#[test]
fn test_is_number() {
    let test_cases = vec![
        ("123", true),
        ("abc", false),
        ("123abc", false),
        ("1.23", false),
        ("1-23", false),
        ("", false),
    ];

    for (input, expected) in test_cases {
        let result = is_number(input);
        assert_eq!(
            result, expected,
            "is_number result should match expected for input {}",
            input
        );
    }
}

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
    assert_eq!(
        add_string_to_current_filter(
            "testValue",
            &filters::new_with_value("first value"),
            ScopeOperator::None
        ),
        Filter {
            value: "".to_string(),
            has_value: false,
            operator: FilterCombinationType::And,
            children: vec![
                filters::new_with_value("first value"),
                filters::new_with_value("testValue")
            ]
        }
    );

    assert_eq!(
        add_string_to_current_filter(
            "testValue",
            &filters::new_with_value("first value"),
            ScopeOperator::Or
        ),
        Filter {
            value: "".to_string(),
            has_value: false,
            operator: FilterCombinationType::Or,
            children: vec![
                filters::new_with_value("first value"),
                filters::new_with_value("testValue")
            ]
        }
    );

    assert_eq!(
        add_string_to_current_filter(
            "testValue",
            &filters::new_with_value("first value"),
            ScopeOperator::Xor
        ),
        Filter {
            value: "".to_string(),
            has_value: false,
            operator: FilterCombinationType::Xor,
            children: vec![
                filters::new_with_value("first value"),
                filters::new_with_value("testValue")
            ]
        }
    );

    assert_eq!(
        add_string_to_current_filter(
            "testValue",
            &filters::new_with_value("first value"),
            ScopeOperator::And
        ),
        Filter {
            value: "".to_string(),
            has_value: false,
            operator: FilterCombinationType::And,
            children: vec![
                filters::new_with_value("first value"),
                filters::new_with_value("testValue")
            ]
        }
    );
}

#[test]
fn test_parse_filter() {
    let lexer = Lexer::new("some status: completed or status:pending".to_string());
    let mut p = ParserN::new(lexer);
    let f = p.parse_filter();

    let expected_filter = Filter {
        operator: FilterCombinationType::Or,
        has_value: false,
        value: "".to_string(),
        children: vec![
            Filter {
                operator: FilterCombinationType::And,
                has_value: false,
                value: "".to_string(),
                children: vec![
                    filters::new_with_value("some"),
                    filters::new_with_value("status:completed"),
                ],
            },
            filters::new_with_value("status:pending"),
        ],
    };
    assert_eq!(f, expected_filter);
}

#[test]
fn test_build_filter() {
    // Empty input
    let expected = filters::new_empty();
    let actual = build_filter_from_strings(vec![]);
    assert_eq!(expected, actual, "they should be equal");

    // Operator AND and empty operator
    let expected = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::And,
        children: vec![
            filters::new_with_value("one"),
            filters::new_with_value("two"),
        ],
    };
    let actual = build_filter_from_strings(
        vec!["one", "and", "two"]
            .iter()
            .map(|&s| s.to_string())
            .collect(),
    );
    assert_eq!(expected, actual, "they should be equal");
    let actual =
        build_filter_from_strings(vec!["one", "two"].iter().map(|&s| s.to_string()).collect());
    assert_eq!(expected, actual, "they should be equal");

    // Operator OR
    let expected = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::Or,
        children: vec![
            filters::new_with_value("one"),
            filters::new_with_value("two"),
        ],
    };
    let actual = build_filter_from_strings(
        vec!["one", "or", "two"]
            .iter()
            .map(|&s| s.to_string())
            .collect(),
    );
    assert_eq!(expected, actual, "they should be equal");

    // Operator XOR
    let expected = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::Xor,
        children: vec![
            filters::new_with_value("one"),
            filters::new_with_value("two"),
        ],
    };
    let actual = build_filter_from_strings(
        vec!["one", "xor", "two"]
            .iter()
            .map(|&s| s.to_string())
            .collect(),
    );
    assert_eq!(expected, actual, "they should be equal");

    // Operator OR and AND
    let expected = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::Or,
        children: vec![
            filters::new_with_value("one"),
            Filter {
                has_value: false,
                value: "".to_string(),
                operator: FilterCombinationType::And,
                children: vec![
                    filters::new_with_value("two"),
                    filters::new_with_value("three"),
                ],
            },
        ],
    };
    let actual = build_filter_from_strings(
        vec!["one", "or", "two", "and", "three"]
            .iter()
            .map(|&s| s.to_string())
            .collect(),
    );
    assert_eq!(expected, actual, "they should be equal");

    // Operator OR and AND with parenthesis
    // Note: Handling parenthesis might require additional parsing logic
    let actual = build_filter_from_strings(
        vec!["(one", "or", "two)", "and", "three"]
            .iter()
            .map(|&s| s.to_string())
            .collect(),
    );
    assert_ne!(expected, actual, "they should not be equal");

    let expected = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::And,
        children: vec![
            Filter {
                has_value: false,
                value: "".to_string(),
                operator: FilterCombinationType::Or,
                children: vec![
                    filters::new_with_value("one"),
                    filters::new_with_value("two"),
                ],
            },
            filters::new_with_value("three"),
        ],
    };
    assert_eq!(expected, actual, "they should be equal");

    // Operator OR and AND with parenthesis and XOR
    let actual = build_filter_from_strings(
        vec!["(one", "or", "two)", "xor", "three"]
            .iter()
            .map(|&s| s.to_string())
            .collect(),
    );
    assert_ne!(expected, actual, "they should not be equal");

    let expected = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::Xor,
        children: vec![
            Filter {
                has_value: false,
                value: "".to_string(),
                operator: FilterCombinationType::Or,
                children: vec![
                    filters::new_with_value("one"),
                    filters::new_with_value("two"),
                ],
            },
            filters::new_with_value("three"),
        ],
    };
    assert_eq!(expected, actual, "they should be equal");

    // Extended XOR case
    let actual = build_filter_from_strings(
        vec!["(one", "or", "two)", "xor", "three", "and", "four"]
            .iter()
            .map(|&s| s.to_string())
            .collect(),
    );
    assert_ne!(expected, actual, "they should not be equal");

    let expected = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::Xor,
        children: vec![
            Filter {
                has_value: false,
                value: "".to_string(),
                operator: FilterCombinationType::Or,
                children: vec![
                    filters::new_with_value("one"),
                    filters::new_with_value("two"),
                ],
            },
            Filter {
                has_value: false,
                value: "".to_string(),
                operator: FilterCombinationType::And,
                children: vec![
                    filters::new_with_value("three"),
                    filters::new_with_value("four"),
                ],
            },
        ],
    };
    assert_eq!(expected, actual, "they should be equal");

    // Simple OR case with numbers
    let actual = build_filter_from_strings(vec!["1", "4"].iter().map(|&s| s.to_string()).collect());
    let expected = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::Or,
        children: vec![filters::new_with_value("1"), filters::new_with_value("4")],
    };
    assert_eq!(expected, actual, "they should be equal");

    // Simple AND case with mixed inputs
    let actual = build_filter_from_strings(
        vec!["1", "4", "hello"]
            .iter()
            .map(|&s| s.to_string())
            .collect(),
    );
    let expected = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::And,
        children: vec![
            filters::new_with_value("1"),
            filters::new_with_value("4"),
            filters::new_with_value("hello"),
        ],
    };
    assert_eq!(expected, actual, "they should be equal");
}
