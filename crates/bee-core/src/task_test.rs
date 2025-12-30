use all_asserts::{assert_false, assert_true};
use chrono::{Local, NaiveTime, TimeZone};
use uuid::Uuid;

use super::*;
use crate::CoreError;

#[test]
fn test_task_status_from_str() {
    assert_eq!(
        TaskStatus::from_string("pending").unwrap(),
        TaskStatus::Pending
    );
    assert_eq!(
        TaskStatus::from_string("completed").unwrap(),
        TaskStatus::Completed
    );
    assert_eq!(
        TaskStatus::from_string("deleted").unwrap(),
        TaskStatus::Deleted
    );
    assert_eq!(
        TaskStatus::from_string("PeNdiNg").unwrap(),
        TaskStatus::Pending
    );
    assert_eq!(
        TaskStatus::from_string("CoMplEted").unwrap(),
        TaskStatus::Completed
    );
    assert_eq!(
        TaskStatus::from_string("DelEtEd").unwrap(),
        TaskStatus::Deleted
    );

    assert!(
        matches!(
            TaskStatus::from_string("invalid"),
            Err(CoreError::Task { .. })
        ),
        "expected invalid status to return a CoreError::Task"
    );
}

fn setup_task() -> Task {
    Task {
        id: Some(1),
        status: TaskStatus::Pending, // Use an appropriate variant
        uuid: Uuid::new_v4(),
        summary: "Initial summary".to_string(),
        tags: vec!["initial_tag1".to_string(), "initial_tag2".to_string()],
        date_created: chrono::Local::now(),
        ..Task::default()
    }
}

fn setup_task_property() -> TaskProperties {
    TaskProperties::default()
}

#[test]
fn test_apply_active() {
    let mut task = setup_task();
    let props = TaskProperties {
        active_status: Some(true),
        ..Default::default()
    };

    assert_true!(task.get_history().is_empty());
    assert_eq!(task.get_status(), &TaskStatus::Pending);
    let _ = task.apply(&props);
    assert_eq!(task.get_status(), &TaskStatus::Active);
    assert_false!(task.get_history().is_empty());

    let mut task = Task {
        status: TaskStatus::Deleted,
        ..Default::default()
    };

    assert_true!(task.get_history().is_empty());
    assert_eq!(task.get_status(), &TaskStatus::Deleted);
    let res = task.apply(&props);
    assert_true!(res.is_err());

    let mut task = Task {
        status: TaskStatus::Completed,
        ..Default::default()
    };

    assert_true!(task.get_history().is_empty());
    assert_eq!(task.get_status(), &TaskStatus::Completed);
    let res = task.apply(&props);
    assert_true!(res.is_err());

    let mut task = Task {
        status: TaskStatus::Active,
        ..Default::default()
    };

    // Assert that history is still empty
    assert_true!(task.get_history().is_empty());
    assert_eq!(task.get_status(), &TaskStatus::Active);
    let _ = task.apply(&props);
    assert_eq!(task.get_status(), &TaskStatus::Active);
    assert_true!(task.get_history().is_empty());
}

#[test]
fn test_apply_stop() {
    let mut task = Task {
        status: TaskStatus::Active,
        ..Default::default()
    };
    let props = TaskProperties {
        active_status: Some(false),
        ..Default::default()
    };

    assert_true!(task.get_history().is_empty());
    assert_eq!(task.get_status(), &TaskStatus::Active);
    let _ = task.apply(&props);
    assert_eq!(task.get_status(), &TaskStatus::Pending);
    assert_false!(task.get_history().is_empty());

    let mut task = Task {
        status: TaskStatus::Deleted,
        ..Default::default()
    };

    assert_true!(task.get_history().is_empty());
    assert_eq!(task.get_status(), &TaskStatus::Deleted);
    let res = task.apply(&props);
    assert_true!(res.is_err());

    let mut task = Task {
        status: TaskStatus::Completed,
        ..Default::default()
    };

    assert_true!(task.get_history().is_empty());
    assert_eq!(task.get_status(), &TaskStatus::Completed);
    let res = task.apply(&props);
    assert_true!(res.is_err());

    let mut task = Task {
        status: TaskStatus::Pending,
        ..Default::default()
    };

    // Assert that history is still empty
    assert_true!(task.get_history().is_empty());
    assert_eq!(task.get_status(), &TaskStatus::Pending);
    let _ = task.apply(&props);
    assert_eq!(task.get_status(), &TaskStatus::Pending);
    assert_true!(task.get_history().is_empty());
}

#[test]
fn test_apply_project() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    let new_proj = Project {
        name: "a.b.c".to_string(),
        id: None,
    };
    props.project = Some(Some(new_proj.clone()));

    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    assert_eq!(task.project, Some(new_proj));
    assert_false!(task.get_history().is_empty());
}

#[test]
fn test_apply_summary() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.summary = Some("New summary".to_string());

    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    assert_eq!(task.summary, "New summary");
    assert_false!(task.get_history().is_empty());
}

#[test]
fn test_apply_status() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.status = Some(TaskStatus::Completed);

    assert_true!(task.get_history().is_empty());
    assert_eq!(task.status, TaskStatus::Pending);
    let _ = task.apply(&props);
    assert_eq!(task.status, TaskStatus::Completed);
    assert_false!(task.get_history().is_empty());
}

#[test]
fn test_apply_tags_add() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.tags_add = Some(vec!["new_tag".to_string()]);

    // Test adding a new tag
    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    task.tags.sort();
    assert_eq!(task.tags, vec!["initial_tag1", "initial_tag2", "new_tag"]);
    assert_false!(task.get_history().is_empty());

    let mut task = setup_task();
    let mut props = setup_task_property();
    props.tags_add = Some(vec!["initial_tag1".to_string()]);

    // Test adding an existing tag
    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    task.tags.sort();
    assert_true!(task.get_history().is_empty());

    let mut task = setup_task();
    let mut props = setup_task_property();
    props.tags_add = Some(vec!["initial_tag1".to_string(), "new_tag".to_string()]);

    // Test adding a mix of existing and new tags
    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    task.tags.sort();
    assert_false!(task.get_history().is_empty());
    assert_true!(
        task.get_history()
            .first()
            .unwrap()
            .value
            .contains("new_tag")
    );
}

#[test]
fn test_apply_tags_remove() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.tags_remove = Some(vec!["initial_tag2".to_string()]);

    // Test removing an existing tag
    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    assert_eq!(task.tags, vec!["initial_tag1"]);
    assert_false!(task.get_history().is_empty());
    assert_true!(
        task.get_history()
            .first()
            .unwrap()
            .value
            .contains("initial_tag2")
    );

    let mut task = setup_task();
    let mut props = setup_task_property();
    props.tags_remove = Some(vec!["not_a_tag".to_string()]);

    // Test removing a non-existing tag
    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    assert_true!(task.get_history().is_empty());
}

#[test]
fn test_apply_annotation() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.annotation = Some("hello there".to_owned());

    assert_true!(task.get_history().is_empty());
    assert_true!(task.annotations.is_empty());
    let _ = task.apply(&props);
    assert_false!(task.annotations.is_empty());
    assert_false!(task.get_history().is_empty());
    assert_eq!(
        task.annotations.first().unwrap().get_value(),
        &"hello there".to_owned()
    );
}

#[test]
fn test_apply_combined() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.summary = Some("Updated summary".to_string());
    props.tags_remove = Some(vec!["initial_tag1".to_string()]);
    props.tags_add = Some(vec!["additional_tag".to_string()]);

    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    assert_false!(task.get_history().is_empty());
    assert_eq!(task.summary, "Updated summary");
    assert_eq!(task.tags, vec!["initial_tag2", "additional_tag"]);
}

#[test]
fn test_apply_no_change() {
    let mut task = setup_task();
    let props = TaskProperties::default(); // Assumes no change

    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    assert_true!(task.get_history().is_empty());
    assert_eq!(task.summary, "Initial summary");
    assert_eq!(task.tags, vec!["initial_tag1", "initial_tag2"]);
}

#[test]
fn test_apply_depends_on_taskdata() {
    let task1 = setup_task();
    let task2 = setup_task();
    let props = TaskProperties {
        depends_on: Some(vec![DependsOnIdentifier::Uuid(task2.uuid.to_owned())]),
        ..Default::default()
    };
    let mut taskdata = TaskData::default();
    taskdata.add_task_object(task1.to_owned());
    taskdata.add_task_object(task2.to_owned());

    taskdata.apply(&task1.uuid, &props).unwrap();
    assert_eq!(
        taskdata.get_task_map().get(&task1.uuid).unwrap().links[0],
        Link {
            from: task1.uuid.to_owned(),
            to: task2.uuid.to_owned(),
            link_type: LinkType::DependsOn,
            id: None,
        }
    );
    assert_eq!(
        taskdata.get_task_map().get(&task2.uuid).unwrap().links[0],
        Link {
            from: task2.uuid.to_owned(),
            to: task1.uuid.to_owned(),
            link_type: LinkType::Blocking,
            id: None,
        }
    );
}

#[test]
fn test_apply_depends_on() {
    let mut task = setup_task();
    let mut props = TaskProperties::default();
    let uuid_1 = Uuid::new_v4();
    let uuid_2 = Uuid::new_v4();
    props.depends_on = Some(vec![DependsOnIdentifier::Uuid(uuid_1)]);

    assert_true!(task.get_depends_on().is_empty());
    assert_true!(task.get_history().is_empty());
    let _ = task.apply(&props);
    assert_false!(task.get_history().is_empty());
    assert_eq!(task.get_depends_on().len(), 1);
    // Evene if we apply if a second time we still have a single value because it's the same uuid
    assert_eq!(task.get_history().len(), 1);
    let _ = task.apply(&props);
    assert_eq!(task.get_history().len(), 1);
    assert_eq!(task.get_depends_on().len(), 1);
    assert_eq!(*task.get_depends_on().first().unwrap(), &uuid_1);

    props.depends_on = Some(vec![
        DependsOnIdentifier::Uuid(uuid_1),
        DependsOnIdentifier::Uuid(uuid_2),
    ]);
    assert_eq!(task.get_depends_on().len(), 1);
    let _ = task.apply(&props);
    assert_eq!(task.get_depends_on().len(), 2);
    assert_true!(
        *task.get_depends_on().first().unwrap() == &uuid_1
            || *task.get_depends_on().first().unwrap() == &uuid_2
    );
    assert_true!(
        *task.get_depends_on().last().unwrap() == &uuid_1
            || *task.get_depends_on().last().unwrap() == &uuid_2
    );
    assert_ne!(
        task.get_depends_on().first().unwrap(),
        task.get_depends_on().last().unwrap()
    )
}

#[test]
fn test_sort_tasks() {
    let now = Local::now();
    let today_start = Local
        .from_local_datetime(
            &now.date_naive()
                .and_time(NaiveTime::from_hms_opt(0, 0, 0).unwrap()),
        )
        .single()
        .unwrap();
    let mut tasks = [
        Task {
            id: Some(2),
            urgency: Some(2),
            date_created: now,
            ..Task::default()
        },
        Task {
            id: Some(1),
            urgency: Some(1),
            date_created: today_start,
            ..Task::default()
        },
    ];
    tasks.sort();

    assert_eq!(tasks[0].id, Some(1));
    assert_eq!(tasks[1].id, Some(2));

    let mut tasks = [
        Task {
            id: Some(2),
            urgency: Some(2),
            date_created: now,
            ..Task::default()
        },
        Task {
            id: Some(1),
            urgency: Some(2),
            date_created: today_start,
            ..Task::default()
        },
    ];
    tasks.sort();

    assert_eq!(tasks[0].id, Some(1));
    assert_eq!(tasks[1].id, Some(2));

    let mut tasks = [
        Task {
            id: Some(2),
            urgency: None,
            date_created: now,
            ..Task::default()
        },
        Task {
            id: Some(1),
            urgency: Some(2),
            date_created: today_start,
            ..Task::default()
        },
    ];
    tasks.sort();

    assert_eq!(tasks[0].id, Some(1));
    assert_eq!(tasks[1].id, Some(2));

    let mut tasks = [
        Task {
            id: Some(2),
            urgency: None,
            date_created: now,
            ..Task::default()
        },
        Task {
            id: Some(1),
            urgency: None,
            date_created: today_start,
            ..Task::default()
        },
    ];
    tasks.sort();

    assert_eq!(tasks[0].id, Some(1));
    assert_eq!(tasks[1].id, Some(2));
}
