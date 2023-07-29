use super::*;
use chrono::Local;

#[test]
fn test_task_status_from_str() {
    assert_eq!(TaskStatus::from_str("pending"), Ok(TaskStatus::PENDING));
    assert_eq!(TaskStatus::from_str("completed"), Ok(TaskStatus::COMPLETED));
    assert_eq!(TaskStatus::from_str("deleted"), Ok(TaskStatus::DELETED));
    assert_eq!(TaskStatus::from_str("PeNdiNg"), Ok(TaskStatus::PENDING));
    assert_eq!(TaskStatus::from_str("CoMplEted"), Ok(TaskStatus::COMPLETED));
    assert_eq!(TaskStatus::from_str("DelEtEd"), Ok(TaskStatus::DELETED));

    assert_eq!(
        TaskStatus::from_str("invalid"),
        Err("Invalid task status".to_string())
    );
}

#[test]
fn test_generate_operation() {
    let task1 = Task {
        id: Some(1),
        status: TaskStatus::PENDING,
        uuid: Uuid::new_v4(),
        description: "Task 1".to_string(),
        tags: vec!["tag1".to_string(), "tag2".to_string()],
        date_created: Local::now(),
        date_completed: None,
        sub: vec![Uuid::new_v4(), Uuid::new_v4()],
    };

    let task2 = Task {
        id: Some(2),
        status: TaskStatus::COMPLETED,
        uuid: Uuid::new_v4(),
        description: "Task 2".to_string(),
        tags: vec!["tag1".to_string(), "tag2".to_string()],
        date_created: Local::now(),
        date_completed: Some(Local::now()),
        sub: vec![Uuid::new_v4(), Uuid::new_v4()],
    };

    let operation = task1.generate_operation::<Task>(&task2);

    assert_eq!(operation.input.len(), 6);
    assert_eq!(operation.output.len(), 6);

    assert_eq!(operation.input.get("status").is_some(), true);
    assert_eq!(operation.input.get("uuid").is_some(), true);
    assert_eq!(operation.input.get("description").is_some(), true);
    assert_eq!(operation.input.get("tags").is_some(), false);
    assert_eq!(operation.input.get("date_created").is_some(), true);
    assert_eq!(operation.input.get("date_completed").is_some(), true);
    assert_eq!(operation.input.get("sub").is_some(), true);

    assert_eq!(operation.output.get("status").is_some(), true);
    assert_eq!(operation.output.get("uuid").is_some(), true);
    assert_eq!(operation.output.get("description").is_some(), true);
    assert_eq!(operation.output.get("tags").is_some(), false);
    assert_eq!(operation.output.get("date_created").is_some(), true);
    assert_eq!(operation.output.get("date_completed").is_some(), true);
    assert_eq!(operation.output.get("sub").is_some(), true);
}

#[test]
fn test_apply_operation() {
    let mut task = Task {
        id: Some(1),
        status: TaskStatus::PENDING,
        uuid: Uuid::new_v4(),
        description: "Task 1".to_string(),
        tags: vec!["tag1".to_string(), "tag2".to_string()],
        date_created: Local::now(),
        date_completed: None,
        sub: vec![Uuid::new_v4(), Uuid::new_v4()],
    };

    let operation = Operation {
        input: vec![
            (
                "status".to_string(),
                serde_json::to_vec(&task.status).unwrap(),
            ),
            (
                "description".to_string(),
                serde_json::to_vec(&task.description).unwrap(),
            ),
            ("tags".to_string(), serde_json::to_vec(&task.tags).unwrap()),
            ("sub".to_string(), serde_json::to_vec(&task.sub).unwrap()),
        ]
        .into_iter()
        .collect(),
        output: vec![
            (
                "status".to_string(),
                serde_json::to_vec(&TaskStatus::COMPLETED).unwrap(),
            ),
            (
                "description".to_string(),
                serde_json::to_vec(&"Task 1 Updated".to_string()).unwrap(),
            ),
            (
                "tags".to_string(),
                serde_json::to_vec(&vec![
                    "tag1".to_string(),
                    "tag2".to_string(),
                    "tag3".to_string(),
                ])
                .unwrap(),
            ),
            (
                "sub".to_string(),
                serde_json::to_vec(&vec![Uuid::new_v4(), Uuid::new_v4(), Uuid::new_v4()]).unwrap(),
            ),
        ]
        .into_iter()
        .collect(),
        ..Default::default()
    };

    let result = task.apply_operation(&operation);

    assert_eq!(result, Ok(()));
    assert_eq!(task.status, TaskStatus::COMPLETED);
    assert_eq!(task.description, "Task 1 Updated");
    assert_eq!(
        task.tags,
        vec!["tag1".to_string(), "tag2".to_string(), "tag3".to_string()]
    );
    assert_eq!(task.sub.len(), 3);
}
