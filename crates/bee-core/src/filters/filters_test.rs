use super::*;
use crate::task::{Project, TaskData, TaskProperties, TaskStatus};
use all_asserts::{assert_false, assert_true};
use chrono::{Duration, Local, NaiveTime, TimeZone};
use filters_test::filters_impl::DateDueFilterType;

fn init() {
    let _ = env_logger::builder().is_test(true).try_init();
}

#[test]
fn test_serialize() {
    let filter = ProjectFilter {
        name: Project::from("hey".to_owned()),
    };
    assert_eq!(
        serde_json::to_string(&filter).unwrap(),
        "{\"name\":{\"name\":\"hey\"}}"
    );
    let filter = Box::new(RootFilter {});
    assert_eq!(serde_json::to_string(&filter).unwrap(), "{}");

    let filter: Box<dyn Filter> =
        serde_json::from_str("{\"type\":\"RootFilter\",\"value\":{\"child\":null}}").unwrap();
    assert_eq!(filter.get_kind(), FilterKind::Root);

    // Without the type annotation of being the trait type, we just serialise it like we do any
    // other struct.
    let and_filter = Box::new(AndFilter { children: vec![] });
    assert_eq!(
        serde_json::to_string(&and_filter).unwrap(),
        "{\"children\":[]}"
    );

    // When dealing with the dyn trait, typetag adds the relevent information to distiguing the
    // types
    let and_filter: Box<dyn Filter> = Box::new(AndFilter { children: vec![] });
    assert_eq!(
        serde_json::to_string(&and_filter).unwrap(),
        "{\"type\":\"AndFilter\",\"value\":{\"children\":[]}}"
    );
    let or_filter: Box<dyn Filter> = Box::new(OrFilter { children: vec![] });
    assert_eq!(
        serde_json::to_string(&or_filter).unwrap(),
        "{\"type\":\"OrFilter\",\"value\":{\"children\":[]}}"
    );
    assert_ne!(
        serde_json::to_string(&and_filter).unwrap(),
        serde_json::to_string(&or_filter).unwrap()
    );
}

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
fn test_project_filter() {
    let mut task_data = TaskData::default();
    let task = task_data
        .add_task(
            &TaskProperties::from(&["foo proj:hey.a.b.c".to_owned()]).unwrap(),
            TaskStatus::Pending,
        )
        .unwrap()
        .clone();

    assert_true!(
        ProjectFilter {
            name: Project::from("hey.a.b.c".to_owned())
        }
        .validate_task(&task)
    );

    assert_true!(
        ProjectFilter {
            name: Project::from("hey.a".to_owned())
        }
        .validate_task(&task)
    );

    assert_true!(
        ProjectFilter {
            name: Project::from("hey".to_owned())
        }
        .validate_task(&task)
    );

    assert_false!(
        ProjectFilter {
            name: Project::from("hey.b".to_owned())
        }
        .validate_task(&task)
    );
}

#[test]
fn test_due_filter() {
    init();
    let now = Local::now();
    let today_start = Local
        .from_local_datetime(
            &now.date_naive()
                .and_time(NaiveTime::from_hms_opt(0, 0, 0).unwrap()),
        )
        .single()
        .unwrap();

    let mut task_data = TaskData::default();
    let task = task_data
        .add_task(
            &TaskProperties::from(&["summary due: today".to_owned()]).unwrap(),
            TaskStatus::Pending,
        )
        .unwrap()
        .clone();

    assert_true!(
        DateDueFilter {
            time: today_start,
            type_when: DateDueFilterType::Day,
        }
        .validate_task(&task)
    );

    let task = task_data
        .add_task(
            &TaskProperties::from(&["summary due: today+10h".to_owned()]).unwrap(),
            TaskStatus::Pending,
        )
        .unwrap()
        .clone();

    assert_true!(
        DateDueFilter {
            time: today_start + Duration::try_hours(20).unwrap(),
            type_when: DateDueFilterType::Day,
        }
        .validate_task(&task)
    );
    assert_true!(
        DateDueFilter {
            time: today_start + Duration::try_hours(20).unwrap(),
            type_when: DateDueFilterType::Before,
        }
        .validate_task(&task)
    );
    assert_false!(
        DateDueFilter {
            time: today_start + Duration::try_hours(20).unwrap(),
            type_when: DateDueFilterType::After,
        }
        .validate_task(&task)
    );
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
fn test_filter_depends_on() {
    let depends_uuid = Uuid::new_v4();
    let mut task = Task::default();
    let mut props = TaskProperties::default();
    props.add_depends_on(&crate::task::DependsOnIdentifier::Uuid(depends_uuid));
    task.apply(&props).unwrap();

    let filter = DependsOnFilter {
        uuid: Some(depends_uuid),
        id: None,
    };
    assert_true!(filter.validate_task(&task));

    let filter = DependsOnFilter {
        uuid: Some(depends_uuid),
        id: task.get_id(),
    };
    assert_true!(filter.validate_task(&task));

    let filter = DependsOnFilter {
        uuid: Some(depends_uuid),
        id: Some(1234), // not a real ID
    };
    assert_true!(filter.validate_task(&task));

    let filter = DependsOnFilter {
        uuid: Some(Uuid::new_v4()),
        id: None,
    };
    assert_false!(filter.validate_task(&task));
}

#[test]
fn test_depends_on_convert_id_to_uuid_already_has_uuid() {
    let uuid = Uuid::new_v4();
    let mut filter = DependsOnFilter {
        id: Some(1),
        uuid: Some(uuid),
    };

    let mut id_to_uuid = HashMap::new();
    id_to_uuid.insert(1, Uuid::new_v4());

    filter.convert_id_to_uuid(&id_to_uuid);

    assert_eq!(filter.uuid, Some(uuid));
}

#[test]
fn test_depends_on_convert_id_to_uuid_success() {
    let id = 1;
    let uuid = Uuid::new_v4();
    let mut filter = DependsOnFilter {
        id: Some(id),
        uuid: None,
    };

    let mut id_to_uuid = HashMap::new();
    id_to_uuid.insert(id, uuid);

    filter.convert_id_to_uuid(&id_to_uuid);

    assert_eq!(filter.uuid, Some(uuid));
}

#[test]
fn test_depends_on_convert_id_to_uuid_id_not_found() {
    let id = 1;
    let mut filter = DependsOnFilter {
        id: Some(id),
        uuid: None,
    };

    let id_to_uuid = HashMap::new();

    filter.convert_id_to_uuid(&id_to_uuid);

    assert_eq!(filter.uuid, None);
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
