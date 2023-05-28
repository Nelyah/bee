#[cfg(test)]

use super::*;

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
