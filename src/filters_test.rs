#[cfg(test)]
use super::*;

#[test]
fn test_split_parenthesis() {
    let expected = vec![
        String::from("hello"),
        String::from("and"),
        String::from("("),
        String::from("you"),
        String::from(")"),
    ];

    let actual = split_out_parenthesis(&[
        String::from("hello"),
        String::from("and"),
        String::from("("),
        String::from("you"),
        String::from(")"),
    ]);
    assert_eq!(expected, actual);

    let actual = split_out_parenthesis(&[
        String::from("hello"),
        String::from("and"),
        String::from("("),
        String::from("you)"),
    ]);
    assert_eq!(expected, actual);

    let actual = split_out_parenthesis(&[
        String::from("hello"),
        String::from("and"),
        String::from("(you)"),
    ]);
    assert_eq!(expected, actual);

    let actual = split_out_parenthesis(&[
        String::from("hello"),
        String::from("and"),
        String::from("(you"),
        String::from(")"),
    ]);
    assert_eq!(expected, actual);

    let actual = split_out_parenthesis(&[
        String::from("hello"),
        String::from("and"),
        String::from("you"),
    ]);
    assert_ne!(expected, actual);
}

#[test]
fn test_filters() {
    // Empty input
    let expected = Filter::default();

    let actual = build_filter_from_strings(&[]);
    assert_eq!(expected, actual);

    // Operator AND and empty operator
    let expected = Filter {
        operator: FilterCombinationType::And,
        childs: vec![
            Filter {
                has_value: true,
                value: "one".to_owned(),
                ..Default::default()
            },
            Filter {
                has_value: true,
                value: "two".to_owned(),
                ..Default::default()
            },
        ],
        ..Default::default()
    };
    let actual = build_filter_from_strings(&[
        String::from("one"),
        String::from("and"),
        String::from("two"),
    ]);
    // The default view filter is applied, and we just skip it here
    assert_eq!(expected, actual);
    let actual = build_filter_from_strings(&[String::from("one"), String::from("two")]);
    assert_eq!(expected, actual);

    // Operator OR
    let expected = Filter {
        operator: FilterCombinationType::Or,
        childs: vec![
            Filter {
                has_value: true,
                value: "one".to_owned(),
                ..Default::default()
            },
            Filter {
                has_value: true,
                value: "two".to_owned(),
                ..Default::default()
            },
        ],
        ..Default::default()
    };
    let actual =
        build_filter_from_strings(&[String::from("one"), String::from("or"), String::from("two")]);
    assert_eq!(expected, actual);

    let actual = build_filter_from_strings(&[String::from("one or two")]);
    assert_ne!(expected, actual);

    // Operator XOR
    let expected = Filter {
        operator: FilterCombinationType::Xor,
        childs: vec![
            Filter {
                has_value: true,
                value: "one".to_owned(),
                ..Default::default()
            },
            Filter {
                has_value: true,
                value: "two".to_owned(),
                ..Default::default()
            },
        ],
        ..Default::default()
    };
    let actual = build_filter_from_strings(&[
        String::from("one"),
        String::from("xor"),
        String::from("two"),
    ]);
    assert_eq!(expected, actual);

    // Operator OR and AND
    let expected = Filter {
        operator: FilterCombinationType::Or,
        childs: vec![
            Filter {
                has_value: true,
                value: "one".to_owned(),
                ..Default::default()
            },
            Filter {
                operator: FilterCombinationType::And,
                childs: vec![
                    Filter {
                        has_value: true,
                        value: "two".to_owned(),
                        ..Default::default()
                    },
                    Filter {
                        has_value: true,
                        value: "three".to_owned(),
                        ..Default::default()
                    },
                ],
                ..Default::default()
            },
        ],
        ..Default::default()
    };
    let actual = build_filter_from_strings(&[
        String::from("one"),
        String::from("or"),
        String::from("two"),
        String::from("and"),
        String::from("three"),
    ]);
    assert_eq!(expected, actual);

    // Operator OR and AND with parenthesis
    let actual = build_filter_from_strings(&[
        String::from("(one"),
        String::from("or"),
        String::from("two)"),
        String::from("and"),
        String::from("three"),
    ]);
    assert_ne!(expected, actual);

    let expected = Filter {
        operator: FilterCombinationType::And,
        childs: vec![
            Filter {
                operator: FilterCombinationType::Or,
                childs: vec![
                    Filter {
                        has_value: true,
                        value: "one".to_owned(),
                        ..Default::default()
                    },
                    Filter {
                        has_value: true,
                        value: "two".to_owned(),
                        ..Default::default()
                    },
                ],
                ..Default::default()
            },
            Filter {
                has_value: true,
                value: "three".to_owned(),
                ..Default::default()
            },
        ],
        ..Default::default()
    };
    assert_eq!(expected, actual);

    // Operator OR and AND with parenthesis
    let actual = build_filter_from_strings(&[
        String::from("(one"),
        String::from("or"),
        String::from("two)"),
        String::from("xor"),
        String::from("three"),
    ]);
    assert_ne!(expected, actual);

    let expected = Filter {
        operator: FilterCombinationType::Xor,
        childs: vec![
            Filter {
                operator: FilterCombinationType::Or,
                childs: vec![
                    Filter {
                        has_value: true,
                        value: "one".to_owned(),
                        ..Default::default()
                    },
                    Filter {
                        has_value: true,
                        value: "two".to_owned(),
                        ..Default::default()
                    },
                ],
                ..Default::default()
            },
            Filter {
                has_value: true,
                value: "three".to_owned(),
                ..Default::default()
            },
        ],
        ..Default::default()
    };
    assert_eq!(expected, actual);

    let actual = build_filter_from_strings(&[
        String::from("(one"),
        String::from("or"),
        String::from("two)"),
        String::from("xor"),
        String::from("three"),
        String::from("and"),
        String::from("four"),
    ]);
    assert_ne!(expected, actual);

    let expected = Filter {
        operator: FilterCombinationType::Xor,
        childs: vec![
            Filter {
                operator: FilterCombinationType::Or,
                childs: vec![
                    Filter {
                        has_value: true,
                        value: "one".to_owned(),
                        ..Default::default()
                    },
                    Filter {
                        has_value: true,
                        value: "two".to_owned(),
                        ..Default::default()
                    },
                ],
                ..Default::default()
            },
            Filter {
                operator: FilterCombinationType::And,
                childs: vec![
                    Filter {
                        has_value: true,
                        value: "three".to_owned(),
                        ..Default::default()
                    },
                    Filter {
                        has_value: true,
                        value: "four".to_owned(),
                        ..Default::default()
                    },
                ],
                ..Default::default()
            },
        ],
        ..Default::default()
    };
    assert_eq!(expected, actual);

    let actual = build_filter_from_strings(&[String::from("1"), String::from("4")]);
    let expected = Filter {
        operator: FilterCombinationType::Or,
        childs: vec![
            Filter {
                has_value: true,
                value: "1".to_owned(),
                ..Default::default()
            },
            Filter {
                has_value: true,
                value: "4".to_owned(),
                ..Default::default()
            },
        ],
        ..Default::default()
    };
    assert_eq!(expected, actual);

    let actual =
        build_filter_from_strings(&[String::from("1"), String::from("4"), String::from("hello")]);
    let expected = Filter {
        operator: FilterCombinationType::And,
        childs: vec![
            Filter {
                has_value: true,
                value: "1".to_owned(),
                ..Default::default()
            },
            Filter {
                has_value: true,
                value: "4".to_owned(),
                ..Default::default()
            },
            Filter {
                has_value: true,
                value: "hello".to_owned(),
                ..Default::default()
            },
        ],
        ..Default::default()
    };
    assert_eq!(expected, actual);
}

#[test]
fn test_validate_task() {
    let mut my_task = Task {
        uuid: Uuid::new_v4(),
        id: Some(1),
        description: "this is a task".to_owned(),
        ..Default::default()
    };

    let f = build_filter_from_strings(&[
        String::from("task"),
        String::from("or"),
        String::from("hello"),
    ]);
    assert_eq!(validate_task(&my_task, &f), true);

    let f = build_filter_from_strings(&[String::from("hello")]);
    assert_eq!(validate_task(&my_task, &f), false);

    let f = build_filter_from_strings(&["task", "and", "hello"].map(|t| String::from(t)));
    assert_eq!(validate_task(&my_task, &f), false);

    let f = build_filter_from_strings(&[]);
    assert_eq!(validate_task(&my_task, &f), true);

    let f = build_filter_from_strings(&[
        String::from("task"),
        String::from("xor"),
        String::from("hello"),
    ]);
    assert_eq!(validate_task(&my_task, &f), true);

    my_task.description = "hello task!".to_owned();
    assert_eq!(validate_task(&my_task, &f), false);

    let f =
        build_filter_from_strings(&[String::from("task"), String::from("and"), String::from("1")]);
    assert_eq!(validate_task(&my_task, &f), true);

    let f =
        build_filter_from_strings(&[String::from("task"), String::from("and"), String::from("2")]);
    assert_eq!(validate_task(&my_task, &f), false);

    let f = build_filter_from_strings(&[format!("{}", my_task.uuid)]);
    assert_eq!(validate_task(&my_task, &f), true);

    my_task.description = "this is a task".to_owned();
    let f = build_filter_from_strings(&[
        String::from("this"),
        String::from("xor"),
        String::from("(task"),
        String::from("and"),
        String::from("2)"),
    ]);
    assert_eq!(validate_task(&my_task, &f), true);

    my_task.description = "This is a task".to_owned();
    assert_eq!(validate_task(&my_task, &f), true);
}

#[test]
fn test_task_matches_status_filter() {
    let task = Task {
        status: TaskStatus::COMPLETED,
        ..Default::default()
    };

    let completed_filter = Filter {
        has_value: true,
        value: "status:completed".to_owned(),
        ..Default::default()
    };

    let pending_filter = Filter {
        has_value: true,
        value: "status:pending".to_owned(),
        ..Default::default()
    };

    let deleted_filter = Filter {
        has_value: true,
        value: "status:deleted".to_owned(),
        ..Default::default()
    };

    let other_filter = Filter {
        has_value: true,
        value: "random_stuff".to_owned(),
        ..Default::default()
    };

    assert_eq!(task_matches_status_filter(&task, &completed_filter), true);
    assert_eq!(task_matches_status_filter(&task, &pending_filter), false);
    assert_eq!(task_matches_status_filter(&task, &deleted_filter), false);
    assert_eq!(task_matches_status_filter(&task, &other_filter), false);

    let task = Task {
        status: TaskStatus::PENDING,
        ..Default::default()
    };

    assert_eq!(task_matches_status_filter(&task, &completed_filter), false);
    assert_eq!(task_matches_status_filter(&task, &pending_filter), true);
    assert_eq!(task_matches_status_filter(&task, &deleted_filter), false);
    assert_eq!(task_matches_status_filter(&task, &other_filter), false);

    let task = Task {
        status: TaskStatus::DELETED,
        ..Default::default()
    };

    assert_eq!(task_matches_status_filter(&task, &completed_filter), false);
    assert_eq!(task_matches_status_filter(&task, &pending_filter), false);
    assert_eq!(task_matches_status_filter(&task, &deleted_filter), true);
    assert_eq!(task_matches_status_filter(&task, &other_filter), false);
}

#[test]
fn test_filterview() {
    let filter_view = FilterView::default();

    // Test the `iter()` method
    let iter_values: Vec<_> = filter_view.iter().collect();
    assert_eq!(iter_values.len(), 4); // Make sure all 4 views are present

    // Test the `values()` method
    let values: Vec<_> = filter_view.values().collect();
    assert_eq!(values.len(), 4); // Make sure all 4 views are present

    // Test the `get_view()` method
    let view = filter_view.get_view("pending");
    assert_eq!(view.value, "status:pending");
    let view = filter_view.get_view("completed");
    assert_eq!(view.value, "status:completed");
    let view = filter_view.get_view("deleted");
    assert_eq!(view.value, "status:deleted");
    let view = filter_view.get_view("all");
    assert_eq!(view.value, "");

    // Test a non-existent view
    assert!(std::panic::catch_unwind(|| filter_view.get_view("nonexistent")).is_err());
}
