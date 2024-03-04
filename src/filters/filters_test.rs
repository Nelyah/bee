use super::*;
use all_asserts::{assert_false, assert_true};

#[test]
fn test_task_matches_status_filter() {
    let task = Task {
        status: TaskStatus::COMPLETED,
        ..Default::default()
    };

    let completed_filter = StatusFilter {
        status: TaskStatus::COMPLETED,
    };

    let pending_filter = StatusFilter {
        status: TaskStatus::PENDING,
    };

    let deleted_filter = StatusFilter {
        status: TaskStatus::DELETED,
    };

    let other_filter = StringFilter {
        value: "random_stuff".to_owned(),
    };

    assert_true!(completed_filter.validate_task(&task));
    assert_false!(pending_filter.validate_task(&task));
    assert_false!(deleted_filter.validate_task(&task));
    assert_false!(other_filter.validate_task(&task));

    let task = Task {
        status: TaskStatus::PENDING,
        ..Default::default()
    };

    assert_false!(completed_filter.validate_task(&task));
    assert_true!(pending_filter.validate_task(&task));
    assert_false!(deleted_filter.validate_task(&task));
    assert_false!(other_filter.validate_task(&task));

    let task = Task {
        status: TaskStatus::DELETED,
        ..Default::default()
    };

    assert_false!(completed_filter.validate_task(&task));
    assert_false!(pending_filter.validate_task(&task));
    assert_true!(deleted_filter.validate_task(&task));
    assert_false!(other_filter.validate_task(&task));
}

#[test]
fn test_validate_task() {
    let mut t = Task {
        description: "this is a task".to_string(),
        id: Some(1),
        ..Default::default()
    };

    let mut f_or = OrFilter {
        children: vec![
            Box::new(StringFilter {
                value: "task".to_owned(),
            }),
            Box::new(StringFilter {
                value: "hello".to_owned(),
            }),
        ],
    };
    assert_true!(f_or.validate_task(&t));

    let mut f_and = AndFilter { children: vec![] };
    assert_true!(f_and.validate_task(&t));

    let mut f_string = StringFilter {
        value: "hello".to_owned(),
    };
    assert_false!(f_string.validate_task(&t));

    f_and = AndFilter {
        children: vec![
            Box::new(StringFilter {
                value: "task".to_owned(),
            }),
            Box::new(StringFilter {
                value: "hello".to_owned(),
            }),
        ],
    };
    assert_false!(f_and.validate_task(&t));

    let mut f_root = new_empty();
    assert_true!(f_root.validate_task(&t));

    let mut f_xor = XorFilter {
        children: vec![
            Box::new(StringFilter {
                value: "task".to_owned(),
            }),
            Box::new(StringFilter {
                value: "hello".to_owned(),
            }),
        ],
    };
    assert_true!(f_xor.validate_task(&t));

    t.description = "hello task!".to_string();
    assert_false!(f_xor.validate_task(&t));

    f_and = AndFilter {
        children: vec![
            Box::new(StringFilter {
                value: "task".to_owned(),
            }),
            Box::new(TaskIdFilter { id: 1 }),
        ],
    };
    assert_true!(f_and.validate_task(&t));

    f_and = AndFilter {
        children: vec![
            Box::new(StringFilter {
                value: "task".to_owned(),
            }),
            Box::new(TaskIdFilter { id: 2 }),
        ],
    };
    assert_false!(f_and.validate_task(&t));

    let mut f_uuid = UuidFilter {
        uuid: t.get_uuid().to_owned(),
    };
    assert_true!(f_uuid.validate_task(&t));

    t.description = "this is a task".to_string();

    let mut f_xor = XorFilter {
        children: vec![
            Box::new(StringFilter {
                value: "this".to_owned(),
            }),
            Box::new(AndFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "task".to_owned(),
                    }),
                    Box::new(TaskIdFilter { id: 2 }),
                ],
            }),
        ],
    };
    assert_true!(f_xor.validate_task(&t));

    t.description = "This is a task".to_string();
    assert_true!(f_xor.validate_task(&t));

    t.delete();
    let mut f_id = TaskIdFilter { id: 0 };
    assert_false!(f_id.validate_task(&t));

    t.done();
    assert_false!(f_id.validate_task(&t));
}
