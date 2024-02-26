use super::*;

#[test]
fn test_task_status_from_str() {
    assert_eq!(TaskStatus::from_string("pending"), Ok(TaskStatus::PENDING));
    assert_eq!(TaskStatus::from_string("completed"), Ok(TaskStatus::COMPLETED));
    assert_eq!(TaskStatus::from_string("deleted"), Ok(TaskStatus::DELETED));
    assert_eq!(TaskStatus::from_string("PeNdiNg"), Ok(TaskStatus::PENDING));
    assert_eq!(TaskStatus::from_string("CoMplEted"), Ok(TaskStatus::COMPLETED));
    assert_eq!(TaskStatus::from_string("DelEtEd"), Ok(TaskStatus::DELETED));

    assert_eq!(
        TaskStatus::from_string("invalid"),
        Err("Invalid task status".to_string())
    );
}

