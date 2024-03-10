use super::*;

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
        date_completed: None,
        sub: vec![],
    }
}

#[test]
fn test_apply_summary() {
    let mut task = setup_task();
    let props = TaskProperties {
        summary: Some("New summary".to_string()),
        tags_remove: None,
        tags_add: None,
        status: None,
    };

    task.apply(&props);
    assert_eq!(task.summary, "New summary");
}

#[test]
fn test_apply_status() {
    let mut task = setup_task();
    let props = TaskProperties {
        summary: None,
        tags_remove: None,
        tags_add: None,
        status: Some(TaskStatus::Completed),
    };

    assert_eq!(task.status, TaskStatus::Pending);
    task.apply(&props);
    assert_eq!(task.status, TaskStatus::Completed);
}

#[test]
fn test_apply_tags_add() {
    let mut task = setup_task();
    let props = TaskProperties {
        summary: None,
        tags_remove: None,
        tags_add: Some(vec!["new_tag".to_string()]),
        status: None,
    };

    task.apply(&props);
    task.tags.sort();
    assert_eq!(task.tags, vec!["initial_tag1", "initial_tag2", "new_tag"]);
}

#[test]
fn test_apply_tags_remove() {
    let mut task = setup_task();
    let props = TaskProperties {
        summary: None,
        tags_remove: Some(vec!["initial_tag2".to_string()]),
        tags_add: None,
        status: None,
    };

    task.apply(&props);
    assert_eq!(task.tags, vec!["initial_tag1"]);
}

#[test]
fn test_apply_combined() {
    let mut task = setup_task();
    let props = TaskProperties {
        summary: Some("Updated summary".to_string()),
        tags_remove: Some(vec!["initial_tag1".to_string()]),
        tags_add: Some(vec!["additional_tag".to_string()]),
        status: None,
    };

    task.apply(&props);
    assert_eq!(task.summary, "Updated summary");
    assert_eq!(task.tags, vec!["initial_tag2", "additional_tag"]);
}

#[test]
fn test_apply_no_change() {
    let mut task = setup_task();
    let props = TaskProperties::default(); // Assumes no change

    task.apply(&props);
    assert_eq!(task.summary, "Initial summary");
    assert_eq!(task.tags, vec!["initial_tag1", "initial_tag2"]);
}
