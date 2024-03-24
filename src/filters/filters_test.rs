use super::*;
use crate::task::{TaskData, TaskProperties, TaskStatus};
use all_asserts::{assert_false, assert_true};

#[test]
fn test_clone() {
    let mut f: Box<dyn Filter> = Box::new(AndFilter {
        children: vec![Box::new(StringFilter {
            value: "hey".to_owned(),
        })],
    });
    assert_eq!(&f, &f.clone());

    f = Box::new(OrFilter {
        children: vec![Box::new(StringFilter {
            value: "hey".to_owned(),
        })],
    });
    assert_eq!(&f, &f.clone());

    f = Box::new(XorFilter {
        children: vec![Box::new(StringFilter {
            value: "hey".to_owned(),
        })],
    });
    assert_eq!(&f, &f.clone());

    f = Box::new(RootFilter {
        child: Some(Box::new(StringFilter {
            value: "hey".to_owned(),
        })),
    });
    assert_eq!(&f, &f.clone());

    f = Box::new(RootFilter { child: None });
    assert_eq!(&f, &f.clone());

    f = Box::new(StatusFilter {
        status: TaskStatus::Pending,
    });
    assert_eq!(&f, &f.clone());

    f = Box::new(StringFilter {
        value: "Hey".to_owned(),
    });
    assert_eq!(&f, &f.clone());

    f = Box::new(TagFilter {
        include: true,
        tag_name: "main".to_owned(),
    });
    assert_eq!(&f, &f.clone());

    f = Box::new(TaskIdFilter { id: 42 });
    assert_eq!(&f, &f.clone());

    f = Box::new(UuidFilter {
        uuid: uuid::Uuid::new_v4(),
    });
    assert_eq!(&f, &f.clone());
}

#[test]
fn test_task_matches_status_filter() {
    let mut task_data = TaskData::default();
    let task = task_data
        .add_task(
            &TaskProperties::from(&["foo".to_owned()]).unwrap(),
            TaskStatus::Completed,
        )
        .unwrap()
        .clone();

    let completed_filter = StatusFilter {
        status: TaskStatus::Completed,
    };

    let pending_filter = StatusFilter {
        status: TaskStatus::Pending,
    };

    let deleted_filter = StatusFilter {
        status: TaskStatus::Deleted,
    };

    let other_filter = StringFilter {
        value: "random_stuff".to_owned(),
    };

    assert_true!(completed_filter.validate_task(&task));
    assert_false!(pending_filter.validate_task(&task));
    assert_false!(deleted_filter.validate_task(&task));
    assert_false!(other_filter.validate_task(&task));

    let task = task_data
        .add_task(
            &TaskProperties::from(&["foo".to_owned()]).unwrap(),
            TaskStatus::Pending,
        )
        .unwrap()
        .clone();

    assert_false!(completed_filter.validate_task(&task));
    assert_true!(pending_filter.validate_task(&task));
    assert_false!(deleted_filter.validate_task(&task));
    assert_false!(other_filter.validate_task(&task));

    let task = task_data
        .add_task(
            &TaskProperties::from(&["foo".to_owned()]).unwrap(),
            TaskStatus::Deleted,
        )
        .unwrap()
        .clone();

    assert_false!(completed_filter.validate_task(&task));
    assert_false!(pending_filter.validate_task(&task));
    assert_true!(deleted_filter.validate_task(&task));
    assert_false!(other_filter.validate_task(&task));
}

#[test]
fn test_validate_task() {
    let mut task_data = TaskData::default();
    let mut t = task_data
        .add_task(
            &TaskProperties::from(&["this is a task".to_owned()]).unwrap(),
            TaskStatus::Pending,
        )
        .unwrap()
        .clone();

    let f_or = OrFilter {
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

    let f_string = StringFilter {
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

    let f_root = new_empty();
    assert_true!(f_root.validate_task(&t));

    let f_xor = XorFilter {
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

    t.set_summary("hello task!");
    assert_false!(f_xor.validate_task(&t));

    f_and = AndFilter {
        children: vec![
            Box::new(StringFilter {
                value: "task".to_owned(),
            }),
            Box::new(TaskIdFilter {
                id: t.get_id().unwrap(),
            }),
        ],
    };
    assert_true!(f_and.validate_task(&t));

    f_and = AndFilter {
        children: vec![
            Box::new(StringFilter {
                value: "task".to_owned(),
            }),
            Box::new(TaskIdFilter {
                id: t.get_id().unwrap() + 1,
            }),
        ],
    };
    assert_false!(f_and.validate_task(&t));

    let f_uuid = UuidFilter {
        uuid: t.get_uuid().to_owned(),
    };
    assert_true!(f_uuid.validate_task(&t));

    t.set_summary("this is a task");

    let f_xor = XorFilter {
        children: vec![
            Box::new(StringFilter {
                value: "this".to_owned(),
            }),
            Box::new(AndFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "task".to_owned(),
                    }),
                    Box::new(TaskIdFilter {
                        id: t.get_id().unwrap() + 1,
                    }),
                ],
            }),
        ],
    };
    assert_true!(f_xor.validate_task(&t));

    t.set_summary("This is a task");
    assert_true!(f_xor.validate_task(&t));

    t.delete();
    let f_id = TaskIdFilter { id: 0 };
    assert_false!(f_id.validate_task(&t));

    t.done();
    assert_false!(f_id.validate_task(&t));
}
