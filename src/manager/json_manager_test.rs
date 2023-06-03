#[cfg(test)]
use super::*;


#[test]
fn test_task_manager_add_task() {
    let mut task_manager = JsonTaskManager::default();
    task_manager.add_task("Task 1", vec![], vec![]);
    task_manager.add_task("Task 2", vec![], vec![]);
    task_manager.add_task("Task 3", vec![], vec![]);

    assert_eq!(task_manager.data.tasks.len(), 3);
    assert_eq!(task_manager.data.get_pending_count(), 3);
    assert_eq!(
        task_manager.data.tasks[&task_manager.id_to_uuid(&1)].description,
        "Task 1"
    );
    let uuid_1 = Uuid::new_v4();
    let uuid_2 = Uuid::new_v4();
    task_manager.add_task(
        "Task 4",
        vec!["a".to_string(), "b".to_string()],
        vec![uuid_1.clone(), uuid_2.clone()],
    );
    assert_eq!(
        task_manager.data.tasks[&task_manager.id_to_uuid(&4)].description,
        "Task 4"
    );

    assert_eq!(
        task_manager.data.tasks[&task_manager.id_to_uuid(&4)].tags,
        vec!["a", "b"]
    );
    assert_eq!(
        task_manager.data.tasks[&task_manager.id_to_uuid(&4)].sub,
        vec![uuid_1, uuid_2]
    );
}

#[cfg(test)]
#[test]
fn test_task_handler_complete_task() {
    let mut task_manager = JsonTaskManager::default();
    let task_uuid = Uuid::new_v4();
    task_manager.add_task("Task 1", vec![], vec![]);
    task_manager.add_task("Task 2", vec![], vec![]);
    task_manager.data.tasks.insert(
        task_uuid.clone(),
        Task {
            uuid: task_uuid.clone(),
            status: TaskStatus::PENDING,
            ..Default::default()
        },
    );

    assert_eq!(
        task_manager.data.tasks[&task_uuid].status,
        TaskStatus::PENDING
    );

    task_manager.complete_task(&task_uuid);

    assert_eq!(
        task_manager.data.tasks[&task_uuid].status,
        TaskStatus::COMPLETED
    );
    assert!(task_manager.data.tasks[&task_uuid].date_completed.is_some());
}

#[test]
fn test_task_handler_delete_task() {
    let mut task_manager = JsonTaskManager::default();
    let task_uuid = Uuid::new_v4();
    task_manager.add_task("Task 1", vec![], vec![]);
    task_manager.add_task("Task 2", vec![], vec![]);
    task_manager.data.tasks.insert(
        task_uuid.clone(),
        Task {
            uuid: task_uuid,
            status: TaskStatus::PENDING,
            ..Default::default()
        },
    );

    assert_eq!(
        task_manager.data.tasks[&task_uuid].status,
        TaskStatus::PENDING
    );

    task_manager.delete_task(&task_uuid);

    assert_eq!(
        task_manager.data.tasks[&task_uuid].status,
        TaskStatus::DELETED
    );
}

#[test]
fn test_task_handler_filter_tasks() {
    let mut task_manager = JsonTaskManager::default();
    task_manager.add_task("Task 1", vec![], vec![]);
    task_manager.add_task("Task 2", vec![], vec![]);

    let filter_str = "task 1".to_owned();
    let filter = build_filter_from_strings(&[filter_str]);

    let filtered_tasks = task_manager.filter_tasks(&filter);

    assert_eq!(filtered_tasks.len(), 1);
    assert_eq!(filtered_tasks[0].description, "Task 1");
}

#[test]
fn test_filter_tasks_from_string() {
    let mut manager = JsonTaskManager::default();
    manager.add_task("A task about llamss", vec![], vec![]);
    manager.add_task(
        "Socket is the most beautiful cat in the world",
        vec![],
        vec![],
    );
    manager.add_task("Task 1", vec![], vec![]);

    let tokens = vec!["some".to_owned(), "filter".to_owned(), "string".to_owned()];
    assert_eq!(manager.filter_tasks_from_string(&tokens).len(), 0);

    let tokens = vec!["1".to_owned()];
    assert_eq!(manager.filter_tasks_from_string(&tokens).len(), 1);

    let tokens = vec!["task".to_owned()];
    assert_eq!(manager.filter_tasks_from_string(&tokens).len(), 2);

    let tokens = vec!["task".to_owned(), "and".to_owned(), "cat".to_owned()];
    assert_eq!(manager.filter_tasks_from_string(&tokens).len(), 0);

    let tokens = vec!["task".to_owned(), "or".to_owned(), "cat".to_owned()];
    assert_eq!(manager.filter_tasks_from_string(&tokens).len(), 3);
}
