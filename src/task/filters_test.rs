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
