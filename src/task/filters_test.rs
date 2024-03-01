#[cfg(test)]
use super::*;


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
fn test_validate_task() {
    let mut t = Task{
        description: "this is a task".to_string(),
        id: Some(1),
        ..Default::default()
    };

    let mut f = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::Or,
        children: vec![
            new_with_value("task"),
            new_with_value("hello"),
        ],
    };
    assert_eq!(validate_task(&t, &f), true);

    f = new_with_value("hello");
    assert_eq!(validate_task(&t, &f), false);

    f = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::And,
        children: vec![
            new_with_value("task"),
            new_with_value("hello"),
        ],
    };
    assert_eq!(validate_task(&t, &f), false);

    f = new_empty();
    assert_eq!(validate_task(&t, &f), true);

    f = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::Xor,
        children: vec![
            new_with_value("task"),
            new_with_value("hello"),
        ],
    };
    assert_eq!(validate_task(&t, &f), true);

    t.description = "hello task!".to_string();
    assert_eq!(validate_task(&t, &f), false);

    f = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::And,
        children: vec![
            new_with_value("task"),
            new_with_value("1"),
        ],
    };
    assert_eq!(validate_task(&t, &f), true);

    f = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::And,
        children: vec![
            new_with_value("task"),
            new_with_value("2"),
        ],
    };
    assert_eq!(validate_task(&t, &f), false);

    f = new_with_value(&t.get_uuid().to_string());
    assert_eq!(validate_task(&t, &f), true);

    t.description = "this is a task".to_string();
    f = Filter {
        has_value: false,
        value: "".to_string(),
        operator: FilterCombinationType::Xor,
        children: vec![
            new_with_value("this"),
            Filter{
                has_value: false,
                value: "".to_string(),
                operator: FilterCombinationType::And,
                children: vec![
                    new_with_value("task"),
                    new_with_value("2"),
                ],
            }
        ],
    };
    assert_eq!(validate_task(&t, &f), true);

    t.description = "This is a task".to_string();
    assert_eq!(validate_task(&t, &f), true);

    t.delete();
    f = new_with_value("0");
    assert_eq!(validate_task(&t, &f), false);

    t.done();
    assert_eq!(validate_task(&t, &f), false);
}
