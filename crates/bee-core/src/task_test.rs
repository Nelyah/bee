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

#[test]
fn test_task_done_with_invalid_uuid_returns_error() {
    let mut task_data = TaskData::default();
    let invalid_uuid = Uuid::new_v4();

    let result = task_data.task_done(&invalid_uuid);

    assert!(result.is_err());
    match result.unwrap_err() {
        CoreError::NotFound { message } => {
            assert!(message.contains(&invalid_uuid.to_string()));
        }
        _ => panic!("Expected NotFound error"),
    }
}

#[test]
fn test_task_delete_with_invalid_uuid_returns_error() {
    let mut task_data = TaskData::default();
    let invalid_uuid = Uuid::new_v4();

    let result = task_data.task_delete(&invalid_uuid);

    assert!(result.is_err());
    match result.unwrap_err() {
        CoreError::NotFound { message } => {
            assert!(message.contains(&invalid_uuid.to_string()));
        }
        _ => panic!("Expected NotFound error"),
    }
}

#[test]
fn test_task_done_with_valid_uuid_succeeds() {
    let mut task_data = TaskData::default();
    let task = task_data
        .add_task(
            &TaskProperties::from(&["test task".to_owned()]).unwrap(),
            TaskStatus::Pending,
        )
        .unwrap()
        .clone();

    let result = task_data.task_done(task.get_uuid());

    assert!(result.is_ok());
    assert_eq!(
        task_data
            .get_task_map()
            .get(task.get_uuid())
            .unwrap()
            .status,
        TaskStatus::Completed
    );
}

#[test]
fn test_task_delete_with_valid_uuid_succeeds() {
    let mut task_data = TaskData::default();
    let task = task_data
        .add_task(
            &TaskProperties::from(&["test task".to_owned()]).unwrap(),
            TaskStatus::Pending,
        )
        .unwrap()
        .clone();

    let result = task_data.task_delete(task.get_uuid());

    assert!(result.is_ok());
    assert_eq!(
        task_data
            .get_task_map()
            .get(task.get_uuid())
            .unwrap()
            .status,
        TaskStatus::Deleted
    );
}

#[test]
fn test_compute_urgency_deleted_task_returns_none() {
    let mut task = Task {
        status: TaskStatus::Deleted,
        ..Default::default()
    };

    let result = task.compute_urgency();

    assert!(result.is_ok());
    assert_eq!(result.unwrap(), 0);
    assert!(
        task.urgency.is_none(),
        "Deleted tasks should have urgency = None"
    );
}

#[test]
fn test_compute_urgency_completed_task_returns_none() {
    let mut task = Task {
        status: TaskStatus::Completed,
        ..Default::default()
    };

    let result = task.compute_urgency();

    assert!(result.is_ok());
    assert_eq!(result.unwrap(), 0);
    assert!(
        task.urgency.is_none(),
        "Completed tasks should have urgency = None"
    );
}

#[test]
fn test_apply_properties_to_deleted_task_succeeds() {
    let mut task = Task {
        status: TaskStatus::Deleted,
        summary: "Original".to_string(),
        ..Default::default()
    };

    let props = TaskProperties {
        summary: Some("Updated".to_string()),
        ..Default::default()
    };

    let result = task.apply(&props);

    assert!(
        result.is_ok(),
        "Applying properties to deleted task should succeed"
    );
    assert_eq!(task.summary, "Updated");
    assert!(
        task.urgency.is_none(),
        "Deleted task should still have urgency = None"
    );
}

#[test]
fn test_apply_properties_to_completed_task_succeeds() {
    let mut task = Task {
        status: TaskStatus::Completed,
        summary: "Original".to_string(),
        ..Default::default()
    };

    let props = TaskProperties {
        summary: Some("Updated".to_string()),
        ..Default::default()
    };

    let result = task.apply(&props);

    assert!(
        result.is_ok(),
        "Applying properties to completed task should succeed"
    );
    assert_eq!(task.summary, "Updated");
    assert!(
        task.urgency.is_none(),
        "Completed task should still have urgency = None"
    );
}

// ===== Email Link Tests =====

#[test]
fn test_apply_email_link_add() {
    let mut task = setup_task();
    assert!(task.email_links.is_empty());

    let input = crate::email_link::EmailLinkInput::new(
        "<test123@example.com>".to_string(),
        "Meeting Notes".to_string(),
        "alice@example.com".to_string(),
        None,
    );

    let props = TaskProperties {
        email_link_add: Some(input),
        ..Default::default()
    };

    let result = task.apply(&props);
    assert!(result.is_ok());

    // Email link should be added
    assert_eq!(task.email_links.len(), 1);
    assert_eq!(task.email_links[0].message_id, "<test123@example.com>");
    assert_eq!(task.email_links[0].subject, "Meeting Notes");
    assert_eq!(task.email_links[0].sender, "alice@example.com");

    // History should record the addition
    let history_entry = task.history.last().unwrap();
    assert!(history_entry.value.contains("Added email link"));
    assert!(history_entry.value.contains("Meeting Notes"));
}

#[test]
fn test_apply_email_link_add_with_sent_date() {
    let mut task = setup_task();
    let sent_date = Local::now();

    let input = crate::email_link::EmailLinkInput::new(
        "<dated@example.com>".to_string(),
        "With Date".to_string(),
        "bob@example.com".to_string(),
        Some(sent_date),
    );

    let props = TaskProperties {
        email_link_add: Some(input),
        ..Default::default()
    };

    task.apply(&props).unwrap();

    assert_eq!(task.email_links.len(), 1);
    assert_eq!(task.email_links[0].get_sent_date(), Some(sent_date));
}

#[test]
fn test_apply_email_link_add_duplicate_ignored() {
    let mut task = setup_task();

    let input = crate::email_link::EmailLinkInput::new(
        "<unique@example.com>".to_string(),
        "First Add".to_string(),
        "alice@example.com".to_string(),
        None,
    );

    // Add first time
    let props1 = TaskProperties {
        email_link_add: Some(input.clone()),
        ..Default::default()
    };
    task.apply(&props1).unwrap();
    assert_eq!(task.email_links.len(), 1);
    let history_count_after_first = task.history.len();

    // Try to add same message_id again
    let input2 = crate::email_link::EmailLinkInput::new(
        "<unique@example.com>".to_string(), // Same message_id
        "Second Add Attempt".to_string(),   // Different subject
        "bob@example.com".to_string(),
        None,
    );
    let props2 = TaskProperties {
        email_link_add: Some(input2),
        ..Default::default()
    };
    task.apply(&props2).unwrap();

    // Should still be only 1 email link (duplicate ignored)
    assert_eq!(task.email_links.len(), 1);
    // Original subject should be preserved
    assert_eq!(task.email_links[0].subject, "First Add");
    // No new history entry for duplicate
    assert_eq!(task.history.len(), history_count_after_first);
}

#[test]
fn test_apply_email_link_remove() {
    let mut task = setup_task();

    // First add an email link
    let input = crate::email_link::EmailLinkInput::new(
        "<to-remove@example.com>".to_string(),
        "Will Be Removed".to_string(),
        "alice@example.com".to_string(),
        None,
    );
    task.apply(&TaskProperties {
        email_link_add: Some(input),
        ..Default::default()
    })
    .unwrap();
    assert_eq!(task.email_links.len(), 1);

    // Now remove it
    let props = TaskProperties {
        email_link_remove: Some(vec!["<to-remove@example.com>".to_string()]),
        ..Default::default()
    };
    task.apply(&props).unwrap();

    // Email link should be removed
    assert!(task.email_links.is_empty());

    // History should record the removal
    let history_entry = task.history.last().unwrap();
    assert!(history_entry.value.contains("Removed email link"));
    assert!(history_entry.value.contains("Will Be Removed"));
}

#[test]
fn test_apply_email_link_remove_nonexistent_no_error() {
    let mut task = setup_task();
    let history_before = task.history.len();

    // Try to remove a non-existent email link
    let props = TaskProperties {
        email_link_remove: Some(vec!["<nonexistent@example.com>".to_string()]),
        ..Default::default()
    };

    // Should not error
    let result = task.apply(&props);
    assert!(result.is_ok());

    // No history entry should be added
    assert_eq!(task.history.len(), history_before);
}

#[test]
fn test_apply_email_link_add_and_remove_multiple() {
    let mut task = setup_task();

    // Add two email links
    for i in 1..=2 {
        let input = crate::email_link::EmailLinkInput::new(
            format!("<email{}@example.com>", i),
            format!("Email {}", i),
            "sender@example.com".to_string(),
            None,
        );
        task.apply(&TaskProperties {
            email_link_add: Some(input),
            ..Default::default()
        })
        .unwrap();
    }
    assert_eq!(task.email_links.len(), 2);

    // Remove the first one
    let props = TaskProperties {
        email_link_remove: Some(vec!["<email1@example.com>".to_string()]),
        ..Default::default()
    };
    task.apply(&props).unwrap();

    assert_eq!(task.email_links.len(), 1);
    assert_eq!(task.email_links[0].message_id, "<email2@example.com>");
}

#[test]
fn test_apply_email_link_combined_with_other_changes() {
    let mut task = setup_task();

    // Apply multiple changes including email link
    let input = crate::email_link::EmailLinkInput::new(
        "<combined@example.com>".to_string(),
        "Combined Test".to_string(),
        "sender@example.com".to_string(),
        None,
    );

    let props = TaskProperties {
        summary: Some("Updated Summary".to_string()),
        tags_add: Some(vec!["new_tag".to_string()]),
        email_link_add: Some(input),
        ..Default::default()
    };

    task.apply(&props).unwrap();

    // All changes should be applied
    assert_eq!(task.summary, "Updated Summary");
    assert!(task.tags.contains(&"new_tag".to_string()));
    assert_eq!(task.email_links.len(), 1);
    assert_eq!(task.email_links[0].subject, "Combined Test");
}

#[test]
fn test_email_link_getter() {
    let mut task = setup_task();

    let input = crate::email_link::EmailLinkInput::new(
        "<getter@example.com>".to_string(),
        "Getter Test".to_string(),
        "sender@example.com".to_string(),
        None,
    );

    task.apply(&TaskProperties {
        email_link_add: Some(input),
        ..Default::default()
    })
    .unwrap();

    // Test the getter method
    let links = task.get_email_links();
    assert_eq!(links.len(), 1);
    assert_eq!(links[0].get_message_id(), "<getter@example.com>");
}

#[test]
fn test_apply_attachment_add() {
    let mut task = setup_task();
    let initial_history_len = task.history.len();

    let input = crate::attachment::AttachmentAddInput::new("document.pdf".to_string());

    let props = TaskProperties {
        attachment_add: Some(input),
        ..Default::default()
    };

    let result = task.apply(&props);
    assert!(result.is_ok());

    // History should record the addition
    assert_eq!(task.history.len(), initial_history_len + 1);
    let history_entry = task.history.last().unwrap();
    assert!(history_entry.value.contains("Added attachment"));
    assert!(history_entry.value.contains("document.pdf"));
}
