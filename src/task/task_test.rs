use all_asserts::{assert_false, assert_true};
use chrono::{Local, NaiveTime, TimeZone};

use super::*;

fn new_task(summary: &str, status: TaskStatus) -> Task {
    Task {
        summary: summary.to_string(),
        id: None,
        status,
        uuid: Uuid::new_v4(),
        date_created: Local::now(),
        ..Default::default()
    }
}

#[test]
fn test_task_status_from_str() {
    assert_eq!(TaskStatus::from_string("pending"), Ok(TaskStatus::Pending));
    assert_eq!(
        TaskStatus::from_string("completed"),
        Ok(TaskStatus::Completed)
    );
    assert_eq!(TaskStatus::from_string("deleted"), Ok(TaskStatus::Deleted));
    assert_eq!(TaskStatus::from_string("PeNdiNg"), Ok(TaskStatus::Pending));
    assert_eq!(
        TaskStatus::from_string("CoMplEted"),
        Ok(TaskStatus::Completed)
    );
    assert_eq!(TaskStatus::from_string("DelEtEd"), Ok(TaskStatus::Deleted));

    assert_eq!(
        TaskStatus::from_string("invalid"),
        Err("Invalid task status name".to_string())
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
fn test_apply_summary() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.summary = Some("New summary".to_string());

    let _ = task.apply(&props);
    assert_eq!(task.summary, "New summary");
}

#[test]
fn test_apply_status() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.status = Some(TaskStatus::Completed);

    assert_eq!(task.status, TaskStatus::Pending);
    let _ = task.apply(&props);
    assert_eq!(task.status, TaskStatus::Completed);
}

#[test]
fn test_apply_tags_add() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.tags_add = Some(vec!["new_tag".to_string()]);

    let _ = task.apply(&props);
    task.tags.sort();
    assert_eq!(task.tags, vec!["initial_tag1", "initial_tag2", "new_tag"]);
}

#[test]
fn test_apply_tags_remove() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.tags_remove = Some(vec!["initial_tag2".to_string()]);

    let _ = task.apply(&props);
    assert_eq!(task.tags, vec!["initial_tag1"]);
}

#[test]
fn test_apply_annotation() {
    let mut task = setup_task();
    let mut props = setup_task_property();
    props.annotation = Some("hello there".to_owned());

    assert_true!(task.annotations.is_empty());
    let _ = task.apply(&props);
    assert_false!(task.annotations.is_empty());
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

    let _ = task.apply(&props);
    assert_eq!(task.summary, "Updated summary");
    assert_eq!(task.tags, vec!["initial_tag2", "additional_tag"]);
}

#[test]
fn test_apply_no_change() {
    let mut task = setup_task();
    let props = TaskProperties::default(); // Assumes no change

    let _ = task.apply(&props);
    assert_eq!(task.summary, "Initial summary");
    assert_eq!(task.tags, vec!["initial_tag1", "initial_tag2"]);
}

#[test]
fn test_apply_depends_on() {
    let mut task = setup_task();
    let mut props = TaskProperties::default();
    let uuid_1 = Uuid::new_v4();
    let uuid_2 = Uuid::new_v4();
    props.depends_on = Some(vec![DependsOnIdentifier::Uuid(uuid_1)]);

    assert_true!(task.depends_on.is_empty());
    let _ = task.apply(&props);
    assert_eq!(task.depends_on.len(), 1);
    // Evene if we apply if a second time we still have a single value because it's the same uuid
    let _ = task.apply(&props);
    assert_eq!(task.depends_on.len(), 1);
    assert_eq!(task.depends_on.first().unwrap(), &uuid_1);

    props.depends_on = Some(vec![
        DependsOnIdentifier::Uuid(uuid_1),
        DependsOnIdentifier::Uuid(uuid_2),
    ]);
    assert_eq!(task.depends_on.len(), 1);
    let _ = task.apply(&props);
    assert_eq!(task.depends_on.len(), 2);
    assert_true!(
        task.depends_on.first().unwrap() == &uuid_1 || task.depends_on.first().unwrap() == &uuid_2
    );
    assert_true!(
        task.depends_on.last().unwrap() == &uuid_1 || task.depends_on.last().unwrap() == &uuid_2
    );
    assert_ne!(
        task.depends_on.first().unwrap(),
        task.depends_on.last().unwrap()
    )
}

#[test]
fn test_upkeep_sorts_tasks_and_updates_ids() {
    let mut task_data = TaskData {
        max_id: 0,
        ..TaskData::default()
    };

    let t1 = new_task("Task 1", TaskStatus::Pending);
    let t2 = new_task("Task 2", TaskStatus::Pending);
    let t3 = new_task("Task 3", TaskStatus::Pending);

    task_data.tasks.insert(t3.uuid, t3.clone());

    task_data.tasks.insert(t2.uuid, t2.clone());

    task_data.tasks.insert(t1.uuid, t1.clone());

    // Run upkeep
    let _ = task_data.upkeep();

    // Verify the tasks are sorted and ids are updated correctly
    let task1 = task_data.tasks.get(&t1.uuid).unwrap();
    let task2 = task_data.tasks.get(&t2.uuid).unwrap();
    let task3 = task_data.tasks.get(&t3.uuid).unwrap();

    assert_eq!(task1.id, Some(1));
    assert_eq!(task2.id, Some(2));
    assert_eq!(task3.id, Some(3));
}

#[test]
fn test_upkeep_handles_deleted_and_completed_tasks() {
    let mut task_data = TaskData {
        max_id: 0,
        ..TaskData::default()
    };

    let t1 = new_task("Task 1", TaskStatus::Pending);
    let t2 = new_task("Task 2", TaskStatus::Completed);
    let t4 = new_task("Task 4", TaskStatus::Pending);
    let t3 = new_task("Task 3", TaskStatus::Deleted);

    task_data.tasks.insert(t1.uuid, t1.clone());
    task_data.tasks.insert(t2.uuid, t2.clone());
    task_data.tasks.insert(t3.uuid, t3.clone());
    task_data.tasks.insert(t4.uuid, t4.clone());

    // Run upkeep
    let _ = task_data.upkeep();

    // Verify the tasks are sorted and ids are updated correctly
    let task1 = task_data.tasks.get(&t1.uuid).unwrap();
    let task2 = task_data.tasks.get(&t2.uuid).unwrap();
    let task3 = task_data.tasks.get(&t3.uuid).unwrap();
    let task4 = task_data.tasks.get(&t4.uuid).unwrap();

    assert_eq!(task1.id, Some(1));
    assert_eq!(task2.id, None);
    assert_eq!(task3.id, None);
    assert_eq!(task4.id, Some(2));
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
    let mut tasks = vec![
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

    let mut tasks = vec![
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

    let mut tasks = vec![
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

    let mut tasks = vec![
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
