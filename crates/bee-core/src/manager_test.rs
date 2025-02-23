use all_asserts::assert_true;
use chrono::{Duration, Local};

use crate::filters;

use super::*;
use crate::task::TaskStatus;

#[test]
fn test_task_data_serialize() {
    let mut tasks = HashMap::new();
    let task1 = Task {
        uuid: Uuid::new_v4(),
        status: TaskStatus::Pending,
        date_created: Local::now() - Duration::try_seconds(2).unwrap(),
        ..Task::default()
    };
    let task2 = Task {
        uuid: Uuid::new_v4(),
        status: TaskStatus::Completed,
        date_created: Local::now(),
        ..Task::default()
    };
    tasks.insert(task1.uuid, task1.clone());
    tasks.insert(task2.uuid, task2.clone());

    let task_data = TaskData {
        tasks,
        max_id: 0,
        ..TaskData::default()
    };

    let serialized = serde_json::to_string(&task_data).unwrap();
    let expected = format!(
        r#"[{},{}]"#,
        serde_json::to_string(&task1).unwrap(),
        serde_json::to_string(&task2).unwrap(),
    );
    assert_eq!(serialized, expected);
}

#[test]
fn test_task_data_deserialize() {
    let json = r#"[
                {
                    "uuid": "00000000-0000-0000-0000-000000000001",
                    "date_created": "2023-05-25T21:25:24.899710+02:00",
                    "status": "Completed",
                    "summary": "task1",
                    "sub": [],
                    "tags": []
                },
                {
                    "uuid": "00000000-0000-0000-0000-000000000002",
                    "date_created": "2023-05-25T21:25:24.899710+02:00",
                    "status": "Completed",
                    "summary": "task3",
                    "sub": [],
                    "tags": []
                },
                {
                    "uuid": "00000000-0000-0000-0000-000000000003",
                    "date_created": "2023-05-25T21:25:24.899710+02:00",
                    "status": "Completed",
                    "summary": "task3",
                    "sub": [],
                    "tags": []
                }
        ]"#;

    let task_data: TaskData = serde_json::from_str(json).unwrap();

    assert_eq!(task_data.tasks.len(), 3);
    assert_true!(
        task_data
            .tasks
            .contains_key(&Uuid::parse_str("00000000-0000-0000-0000-000000000001").unwrap())
    );
    assert_true!(
        task_data
            .tasks
            .contains_key(&Uuid::parse_str("00000000-0000-0000-0000-000000000002").unwrap())
    );
    assert_true!(
        task_data
            .tasks
            .contains_key(&Uuid::parse_str("00000000-0000-0000-0000-000000000003").unwrap())
    );
}

#[test]
fn test_update_task_property_depends_on_none() {
    let data = TaskData::default();
    let props = TaskProperties::default();

    let result = data.update_task_property_depends_on(&props).unwrap();

    assert_eq!(result.depends_on, None);
}

#[test]
fn test_update_task_property_depends_on_uuid() {
    let mut data = TaskData::default();
    let uuid = Uuid::new_v4();
    data.insert_id_to_uuid(1, uuid);

    let props = TaskProperties {
        depends_on: Some(vec![DependsOnIdentifier::Uuid(uuid)]),
        ..TaskProperties::default()
    };

    let result = data.update_task_property_depends_on(&props).unwrap();

    assert_eq!(
        result.depends_on,
        Some(vec![DependsOnIdentifier::Uuid(uuid)])
    );
}

#[test]
fn test_update_task_property_depends_on_usize() {
    let mut data = TaskData::default();
    let uuid = Uuid::new_v4();
    data.insert_id_to_uuid(1, uuid);

    let props = TaskProperties {
        depends_on: Some(vec![DependsOnIdentifier::Usize(1)]),
        ..TaskProperties::default()
    };

    let result = data.update_task_property_depends_on(&props).unwrap();

    assert_eq!(
        result.depends_on,
        Some(vec![DependsOnIdentifier::Uuid(uuid)])
    );
}

#[test]
fn test_update_task_property_depends_on_usize_not_found() {
    let data = TaskData::default();
    let props = TaskProperties {
        depends_on: Some(vec![DependsOnIdentifier::Usize(1)]),
        ..TaskProperties::default()
    };

    let result = data.update_task_property_depends_on(&props);

    assert!(result.is_err());
    assert_true!(result.is_err());
}

// Make sure we load the extra tasks from the blocking and the depends_on fields
#[test]
fn test_filter_taskdata() {
    let mut data = TaskData::default();
    let task1_uuid = Uuid::new_v4();
    let task2_uuid = Uuid::new_v4();
    let task1 = Task {
        status: TaskStatus::Pending,
        uuid: task1_uuid,
        depends_on: vec![task2_uuid],
        ..Task::default()
    };
    let task2 = Task {
        status: TaskStatus::Pending,
        uuid: task2_uuid,
        blocking: vec![task1_uuid],
        ..Task::default()
    };
    data.tasks.insert(task1.uuid.to_owned(), task1.clone());
    data.tasks.insert(task2.uuid.to_owned(), task2.clone());

    let filter = filters::from(&[task1_uuid.to_string()]).unwrap();
    let new_data = data.filter(&filter);
    assert_true!(data.get_extra_tasks().is_empty());
    assert_eq!(new_data.get_extra_tasks().len(), 1);
    assert_true!(new_data.get_extra_tasks().get(&task2_uuid).is_some());
    assert_eq!(new_data.get_extra_tasks().get(&task2_uuid).unwrap(), &task2);

    let filter = filters::from(&[task2_uuid.to_string()]).unwrap();
    let new_data = data.filter(&filter);
    assert_true!(data.get_extra_tasks().is_empty());
    assert_eq!(new_data.get_extra_tasks().len(), 1);
    assert_true!(new_data.get_extra_tasks().get(&task1_uuid).is_some());
    assert_eq!(new_data.get_extra_tasks().get(&task1_uuid).unwrap(), &task1);
}

#[test]
fn test_upkeep() {
    let mut data = TaskData::default();
    let task1_uuid = Uuid::new_v4();
    let task2_uuid = Uuid::new_v4();
    let now = Local::now();

    let task1 = Task {
        status: TaskStatus::Pending,
        uuid: task1_uuid,
        date_created: now,
        depends_on: vec![task2_uuid],
        ..Task::default()
    };
    let task2 = Task {
        status: TaskStatus::Pending,
        uuid: task2_uuid,
        date_created: now + Duration::try_hours(1).unwrap(),
        ..Task::default()
    };
    data.tasks.insert(task1.uuid.to_owned(), task1.clone());
    data.tasks.insert(task2.uuid.to_owned(), task2.clone());

    // Make sure it is being set by order of creation date
    assert_eq!(data.tasks.get(&task1_uuid).unwrap().id, None);
    assert_eq!(data.tasks.get(&task2_uuid).unwrap().id, None);

    // Check that we are updating the blocking status
    assert_true!(data.tasks.get(&task2_uuid).unwrap().blocking.is_empty());

    let _ = data.upkeep();

    assert_eq!(data.tasks.get(&task1_uuid).unwrap().id, Some(1));
    assert_eq!(data.tasks.get(&task2_uuid).unwrap().id, Some(2));

    assert_eq!(data.tasks.get(&task2_uuid).unwrap().blocking.len(), 1);
    assert_eq!(data.tasks.get(&task2_uuid).unwrap().blocking[0], task1_uuid);

    // Make sure that the delete and done functions correctly erase the blocking / done status
    // and that upkeep also checks that we need to update when task is complete
    let tmp_task2 = data.tasks.get_mut(&task2_uuid).unwrap().clone();
    data.tasks.get_mut(&task2_uuid).unwrap().done();

    let _ = data.upkeep();
    assert_true!(data.tasks.get(&task1_uuid).unwrap().depends_on.is_empty());

    data.tasks.insert(tmp_task2.uuid, tmp_task2);
    let _ = data.upkeep();
    data.tasks.get_mut(&task1_uuid).unwrap().depends_on = vec![task2_uuid];
    data.tasks.get_mut(&task2_uuid).unwrap().delete();
    let _ = data.upkeep();
    assert_true!(data.tasks.get(&task1_uuid).unwrap().depends_on.is_empty());
}
