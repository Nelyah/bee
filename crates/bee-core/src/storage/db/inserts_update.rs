//! This module is being refactored. The implementations have been moved to:
//! - connection.rs: Database connection
//! - filter_sql.rs: Filter to SQL translation
//! - blocking.rs: Dependency/blocking status management
//! - undo.rs: Undo persistence
//! - sync_relations.rs: Sync functions for annotations, history, links, tags
//! - task_read.rs: Loading tasks
//! - task_write.rs: Writing tasks
//!
//! Tests remain here for now.

#[cfg(test)]
mod tests {
    use super::super::tables;
    use super::super::{
        blocking::{StatusStrings, build_status_case_expr, determine_status_transitions},
        connection::get_database,
        task_read::load_tasks_impl,
        task_write::write_tasks_impl,
        undo::{append_undo_action_impl, load_undos_impl},
    };
    use crate::{
        filters::{
            Filter,
            filters_impl::{
                AndFilter, DateCreatedFilter, DateDueFilter, DateDueFilterType, DateEndFilter,
                DependsOnFilter, OrFilter, ProjectFilter, StatusFilter, StringFilter, TagFilter,
                TaskIdFilter, UuidFilter, XorFilter,
            },
        },
        task::{
            ActionUndo, ActionUndoType, DependsOnIdentifier, Link, LinkType, Project, Task,
            TaskAnnotation, TaskHistory, TaskProperties, TaskStatus,
        },
    };
    use all_asserts::{assert_false, assert_true};
    use chrono::{Duration, Local, TimeZone};
    use log::debug;
    use sea_orm::sea_query::Query;
    use sea_orm::{ColumnTrait, EntityTrait, QueryFilter, QueryOrder};
    use sea_orm_migration::prelude::SqliteQueryBuilder;
    use std::collections::HashSet;
    use tables::{annotations, history, links, tags, tasks, tasks_tags};
    use uuid::Uuid;

    async fn assert_single_match(
        db: &sea_orm::DatabaseConnection,
        filter: Box<dyn Filter>,
        expected_task: &Task,
    ) {
        let results_data = load_tasks_impl(db, Some(filter), None).await.unwrap();
        let results = results_data.to_vec();

        assert_eq!(results.len(), 1, "expected a single matching task");
        let result = results[0];
        let mut expected_task_mut = expected_task.clone();
        expected_task_mut.db_id = result.db_id;
        if let Some(proj) = &mut expected_task_mut.project {
            proj.id = result.project.to_owned().unwrap().id;
        }
        for ann_idx in 0..expected_task_mut.annotations.len() {
            expected_task_mut.annotations[ann_idx].id = result.annotations[ann_idx].id;
        }
        for link_idx in 0..expected_task_mut.links.len() {
            expected_task_mut.links[link_idx].id = result.links[link_idx].id;
        }
        for history_idx in 0..expected_task_mut.history.len() {
            expected_task_mut.history[history_idx].id = result.history[history_idx].id;
        }

        // we set that here because this ID is set automatically when we write to the DB, so not
        // something I want to be testing
        expected_task_mut.id = result.id;
        assert_eq!(result, &expected_task_mut);
    }

    #[test]
    fn test_determine_status_transitions_assigns_correct_sets() {
        let dependency_pairs = vec![(1, 2), (3, 4)];
        let currently_blocked: HashSet<i32> = HashSet::from([1, 5]);
        let dependents: HashSet<i32> = HashSet::from([1, 3]);
        let blockers_done: HashSet<i32> = HashSet::from([2]);

        let (to_block, to_unblock) = determine_status_transitions(
            &dependency_pairs,
            &currently_blocked,
            &dependents,
            &blockers_done,
        );

        let expected_block: HashSet<i32> = HashSet::from([3]);
        let expected_unblock: HashSet<i32> = HashSet::from([1, 5]);

        assert_eq!(to_block, expected_block);
        assert_eq!(to_unblock, expected_unblock);
    }

    #[test]
    fn test_build_status_case_expr_generates_case_when_targets_present() {
        let statuses = StatusStrings::new();
        let case_expr = build_status_case_expr(&[1, 2], &[3], &statuses);
        let sql = Query::select()
            .expr(case_expr)
            .from(tasks::Entity)
            .to_string(SqliteQueryBuilder);

        assert!(sql.contains("CASE"));
        assert!(sql.contains(&statuses.blocked));

        assert!(sql.contains(&statuses.pending));
    }

    #[test]
    fn test_build_status_case_expr_falls_back_to_status_column() {
        let statuses = StatusStrings::new();
        let case_expr = build_status_case_expr(&[], &[], &statuses);
        let sql = Query::select()
            .expr(case_expr)
            .from(tasks::Entity)
            .to_string(SqliteQueryBuilder);

        assert!(!sql.contains("CASE"));
        assert!(sql.contains("\"status\""));
    }

    /// Ensure undo actions are persisted and the most recent entry is fetched.

    #[tokio::test]
    async fn test_append_undo_action_persists_and_fetches_latest() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut first_task = Task::default();
        first_task.set_summary("First undo task");
        let first_undo = ActionUndo {
            action_type: ActionUndoType::Add,
            tasks: vec![first_task],
        };

        let mut second_task = Task::default();
        second_task.set_summary("Second undo task");
        let second_undo = ActionUndo {
            action_type: ActionUndoType::Modify,
            tasks: vec![second_task],
        };
        let expected_latest = second_undo.clone();

        append_undo_action_impl(&db, 1, vec![first_undo])
            .await
            .unwrap();
        append_undo_action_impl(&db, 1, vec![second_undo.to_owned()])
            .await
            .unwrap();

        let recent = load_undos_impl(&db, 1).await.unwrap();
        assert_eq!(recent.len(), 1, "Expected a single undo action returned");
        let latest = &recent[0];

        assert_eq!(latest.action_type, expected_latest.action_type);
        assert_eq!(latest.tasks, expected_latest.tasks);

        let mut third_task = Task::default();
        third_task.set_summary("Third undo task");
        let third_undo = ActionUndo {
            action_type: ActionUndoType::Modify,
            tasks: vec![third_task],
        };

        // If we are removing all of them
        append_undo_action_impl(&db, 2, vec![third_undo.to_owned()])
            .await
            .unwrap();
        // Check we pass a number larger than what we have
        let undos = load_undos_impl(&db, 10).await.unwrap();
        assert_eq!(undos.len(), 1);
        assert_eq!(undos[0], third_undo);

        // Check if we are not removing anything
        append_undo_action_impl(&db, 0, vec![second_undo.to_owned()])
            .await
            .unwrap();
        let undos = load_undos_impl(&db, 2).await.unwrap();
        assert_eq!(undos.len(), 2);
        assert_eq!(undos[0], third_undo);
        assert_eq!(undos[1], second_undo);

        // Should be the same if we replace the last one
        append_undo_action_impl(&db, 1, vec![second_undo.to_owned()])
            .await
            .unwrap();
        let undos = load_undos_impl(&db, 2).await.unwrap();
        assert_eq!(undos.len(), 2);
        assert_eq!(undos[0], third_undo);
        assert_eq!(undos[1], second_undo);

        // Should be the same if we replace the last one
        append_undo_action_impl(&db, 100, vec![]).await.unwrap();
        let undos = load_undos_impl(&db, 100).await.unwrap();
        assert_true!(undos.is_empty());
    }
    #[tokio::test]
    async fn test_insert_load_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        // 1. Create an in-memory task and save its UUID
        let t = Task {
            summary: "foo bar cafe".to_string(),
            ..Default::default()
        };
        let saved_uuid = t.uuid; // UUID auto-generated in default impl

        // 2. First insert
        write_tasks_impl(&db, &t).await.unwrap();

        // 3. Retrieve task by saved UUID
        let initial_db_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(saved_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should have been inserted");
        assert_eq!(saved_uuid.to_string(), initial_db_task.uuid);

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "foo bar cafe".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 1, "Should have one task retrieved");

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "FOO".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 1, "Should be case insensitive");

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "cafe".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 1, "Should be case insensitive");

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "CAFE".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(
            loaded.to_vec().len(),
            1,
            "Should be case insensitive with non-ascii char"
        );

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "NO".to_string(),
        });
        let loaded = load_tasks_impl(&db, Some(f), None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 0, "Should not be matching");
    }

    #[tokio::test]
    async fn test_insert_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        // 1. Create an in-memory task and save its UUID
        let mut t = Task::default();
        let saved_uuid = t.uuid; // UUID auto-generated in default impl

        // 2. First insert
        write_tasks_impl(&db, &t).await.unwrap();

        // 3. Retrieve task by saved UUID
        let initial_db_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(saved_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should have been inserted");
        assert_eq!(saved_uuid.to_string(), initial_db_task.uuid);

        // Ensure there are currently no annotations linked
        let annotations_before = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(initial_db_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            annotations_before.is_empty(),
            "Expected no annotations after first insert"
        );

        // 4. Add annotation to in-memory task (value + current time)
        t.annotations.push(TaskAnnotation {
            id: None,
            value: "Test annotation".to_string(),
            time: chrono::Local::now(),
        });

        // 5. Re-insert (should update existing row by UUID, not duplicate)
        write_tasks_impl(&db, &t).await.unwrap();

        // Fetch task again to ensure we are still referencing same db_id
        let updated_db_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(saved_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should still exist after update");
        assert_eq!(
            initial_db_task.db_id, updated_db_task.db_id,
            "Task update should not create a new row"
        );

        let annotations_after = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(updated_db_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            !annotations_after.is_empty(),
            "Expected at least one annotation row after update"
        );
    }

    #[tokio::test]
    async fn test_annotation_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        task.annotations.push(TaskAnnotation {
            id: None,
            value: "Initial annotation".to_string(),
            time: chrono::Local::now(),
        });

        write_tasks_impl(&db, &task).await.unwrap();

        let persisted_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        let annotations_before = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(
            annotations_before.len(),
            1,
            "Expected one annotation after initial insert"
        );

        task.annotations.clear();
        write_tasks_impl(&db, &task).await.unwrap();

        let annotations_after = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            annotations_after.is_empty(),
            "Annotation should be removed after sync with empty annotations"
        );
    }

    #[tokio::test]
    async fn test_history_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        task.history.push(TaskHistory {
            id: None,
            value: "Created".to_string(),
            datetime: chrono::Local::now(),
        });

        write_tasks_impl(&db, &task).await.unwrap();

        let persisted_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        let history_before = history::Entity::find()
            .filter(history::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(
            history_before.len(),
            1,
            "Expected one history event after initial insert"
        );

        task.history.clear();
        write_tasks_impl(&db, &task).await.unwrap();

        let history_after = history::Entity::find()
            .filter(history::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            history_after.is_empty(),
            "History should be removed after sync with empty events"
        );
    }

    #[tokio::test]
    async fn test_links_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let target_task = Task {
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        let target_uuid = target_task.uuid;
        write_tasks_impl(&db, &target_task).await.unwrap();

        let mut source_task = Task {
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        let source_uuid = source_task.uuid;
        source_task.links.push(Link {
            id: None,
            from: source_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });

        write_tasks_impl(&db, &source_task).await.unwrap();

        let persisted_source = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(source_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Source task should exist after insert");

        let links_before = links::Entity::find()
            .filter(links::Column::FromTaskId.eq(persisted_source.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(
            links_before.len(),
            1,
            "Expected one link after initial insert"
        );

        source_task.links.clear();
        write_tasks_impl(&db, &source_task).await.unwrap();

        let links_after = links::Entity::find()
            .filter(links::Column::FromTaskId.eq(persisted_source.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            links_after.is_empty(),
            "Links should be removed after sync with empty collection"
        );
    }

    #[tokio::test]
    async fn test_project_cleared_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let project_name = "sync-project".to_string();
        let mut task = Task {
            project: Some(Project {
                id: None,
                name: project_name.clone(),
            }),
            ..Default::default()
        };
        let task_uuid = task.uuid;

        write_tasks_impl(&db, &task).await.unwrap();

        let persisted_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");
        assert!(
            persisted_task.project_id.is_some(),
            "Project should be set after initial insert"
        );

        task.project = None;
        write_tasks_impl(&db, &task).await.unwrap();

        let updated_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should still exist after project removal");
        assert!(
            updated_task.project_id.is_none(),
            "Project should be cleared after sync with None"
        );
    }

    #[tokio::test]
    async fn test_tags_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        task.tags.push("alpha".to_string());

        write_tasks_impl(&db, &task).await.unwrap();

        let persisted_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");

        let tags_before = tasks_tags::Entity::find()
            .filter(tasks_tags::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(
            tags_before.len(),
            1,
            "Expected one task-tag link after initial insert"
        );

        let tag_ids: Vec<i32> = tags_before.iter().map(|t| t.tag_id).collect();
        let tag_alpha = tags::Entity::find()
            .filter(tags::Column::Id.is_in(tag_ids))
            .all(&db)
            .await
            .unwrap();
        assert_eq!(tag_alpha.len(), 1, "Expected matching tag row to exist");
        assert_eq!(
            tag_alpha.first().unwrap().name,
            "alpha",
            "Tag should still have the same name"
        );

        task.tags.clear();
        write_tasks_impl(&db, &task).await.unwrap();

        let tags_after = tasks_tags::Entity::find()
            .filter(tasks_tags::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(
            tags_after.is_empty(),
            "Task-tag links should be removed after sync with empty tags"
        );
    }
    fn init() {
        let _ = env_logger::builder()
            .is_test(true)
            .filter_module("sqlx", log::LevelFilter::Off)
            .try_init();
    }

    #[tokio::test]
    async fn test_filter_status_matches_single_task() {
        init();
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let active_task = Task {
            summary: "active-task".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &active_task).await.unwrap();

        let pending_task = Task {
            summary: "pending-task".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &pending_task).await.unwrap();

        let all_tasks = tables::tasks::Entity::find().all(&db).await.unwrap();
        debug!("FOO {:?}", &all_tasks);
        assert_eq!(all_tasks.len(), 2);
        let statuses: Vec<_> = all_tasks.iter().map(|t| t.status.clone()).collect();
        assert!(statuses.contains(&TaskStatus::Active.to_db_string()));
        assert!(statuses.contains(&TaskStatus::Pending.to_db_string()));

        assert_single_match(
            &db,
            Box::new(StatusFilter {
                status: TaskStatus::Active,
            }),
            &active_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_string_matches_single_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_task = Task {
            summary: "Alpha Project".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_task).await.unwrap();

        let beta_task = Task {
            summary: "Beta Project".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &beta_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(StringFilter {
                value: "alpha".to_string(),
            }),
            &alpha_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_task_id_matches_only_exact_id() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let task_one = Task {
            summary: "Task-1".to_string(),
            id: Some(1),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &task_one).await.unwrap();

        let task_two = Task {
            summary: "Task-2".to_string(),
            id: Some(2),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &task_two).await.unwrap();

        assert_single_match(&db, Box::new(TaskIdFilter { id: 1 }), &task_one).await;
    }

    #[tokio::test]
    async fn test_filter_uuid_matches_single_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let matched = Task {
            summary: "Uuid-Match".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &matched).await.unwrap();

        let other = Task {
            summary: "Uuid-Other".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &other).await.unwrap();

        assert_single_match(&db, Box::new(UuidFilter { uuid: matched.uuid }), &matched).await;
    }

    #[tokio::test]
    async fn test_filter_project_matches_prefix() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_task = Task {
            summary: "Alpha Task".to_string(),
            project: Some(Project {
                id: None,
                name: "alpha.core".to_string(),
            }),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_task).await.unwrap();

        let beta_task = Task {
            summary: "Beta Task".to_string(),
            project: Some(Project {
                id: None,
                name: "beta.core".to_string(),
            }),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &beta_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(ProjectFilter {
                name: Project {
                    id: None,
                    name: "alpha".to_string(),
                },
            }),
            &alpha_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_tag_include_matches_only_tagged_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let tagged_task = Task {
            summary: "Tagged Task".to_string(),
            tags: vec!["urgent".to_string()],
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &tagged_task).await.unwrap();

        let untagged_task = Task {
            summary: "Untagged Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &untagged_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(TagFilter {
                include: true,
                tag_name: "urgent".to_string(),
            }),
            &tagged_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_tag_exclude_omits_tagged_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let tagged_task = Task {
            summary: "Tagged Task".to_string(),
            tags: vec!["chore".to_string()],
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &tagged_task).await.unwrap();

        let clean_task = Task {
            summary: "Clean Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &clean_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(TagFilter {
                include: false,
                tag_name: "chore".to_string(),
            }),
            &clean_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_created_before() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early = Local.with_ymd_and_hms(2024, 1, 1, 9, 0, 0).unwrap();
        let late = Local.with_ymd_and_hms(2024, 1, 3, 9, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 1, 2, 9, 0, 0).unwrap();

        let early_task = Task {
            summary: "Early Task".to_string(),
            date_created: early,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &early_task).await.unwrap();

        let late_task = Task {
            summary: "Late Task".to_string(),
            date_created: late,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &late_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateCreatedFilter {
                time: threshold,
                before: true,
            }),
            &early_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_created_after_or_equal() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early = Local.with_ymd_and_hms(2024, 1, 1, 9, 0, 0).unwrap();
        let late = Local.with_ymd_and_hms(2024, 1, 3, 9, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 1, 2, 9, 0, 0).unwrap();

        let early_task = Task {
            summary: "Early Task".to_string(),
            date_created: early,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &early_task).await.unwrap();

        let late_task = Task {
            summary: "Late Task".to_string(),
            date_created: late,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &late_task).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateCreatedFilter {
                time: threshold,
                before: false,
            }),
            &late_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_due_day() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let reference = Local.with_ymd_and_hms(2024, 2, 10, 10, 0, 0).unwrap();

        let due_today = Task {
            summary: "Due Today".to_string(),
            date_due: Some(reference),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_today).await.unwrap();

        let due_tomorrow = Task {
            summary: "Due Tomorrow".to_string(),
            date_due: Some(reference + Duration::days(1)),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_tomorrow).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateDueFilter {
                time: reference,
                type_when: DateDueFilterType::Day,
            }),
            &due_today,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_due_before() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early_due = Local.with_ymd_and_hms(2024, 3, 1, 12, 0, 0).unwrap();
        let late_due = Local.with_ymd_and_hms(2024, 3, 5, 12, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 3, 4, 12, 0, 0).unwrap();

        let due_early = Task {
            summary: "Due Early".to_string(),
            date_due: Some(early_due),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_early).await.unwrap();

        let due_late = Task {
            summary: "Due Late".to_string(),
            date_due: Some(late_due),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_late).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateDueFilter {
                time: threshold,
                type_when: DateDueFilterType::Before,
            }),
            &due_early,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_date_due_after() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early_due = Local.with_ymd_and_hms(2024, 4, 1, 12, 0, 0).unwrap();
        let late_due = Local.with_ymd_and_hms(2024, 4, 5, 12, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 4, 3, 12, 0, 0).unwrap();

        let due_early = Task {
            summary: "Due Early".to_string(),
            date_due: Some(early_due),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_early).await.unwrap();

        let due_later = Task {
            summary: "Due Later".to_string(),
            date_due: Some(late_due),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &due_later).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateDueFilter {
                time: threshold,
                type_when: DateDueFilterType::After,
            }),
            &due_later,
        )
        .await;
    }

    #[tokio::test]
    async fn test_resequence_task_ids_orders_active_and_pending() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let base = Local.with_ymd_and_hms(2024, 6, 1, 8, 0, 0).unwrap();

        let pending_early = Task {
            summary: "pending-early".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            date_created: base,
            ..Default::default()
        };
        write_tasks_impl(&db, &pending_early).await.unwrap();

        let active_late = Task {
            summary: "active-late".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            date_created: base + Duration::days(1),
            ..Default::default()
        };
        write_tasks_impl(&db, &active_late).await.unwrap();

        let completed_latest = Task {
            summary: "completed".to_string(),
            status: TaskStatus::Completed,
            uuid: Uuid::new_v4(),
            date_created: base + Duration::days(2),
            ..Default::default()
        };
        write_tasks_impl(&db, &completed_latest).await.unwrap();

        let rows = tasks::Entity::find()
            .order_by_asc(tasks::Column::DateCreated)
            .all(&db)
            .await
            .unwrap();
        assert_false!(rows.is_empty());
        debug!("{:?}", rows);

        let mut sequential = Vec::new();
        for row in &rows {
            match TaskStatus::from_string(row.status.as_str()).unwrap() {
                TaskStatus::Pending | TaskStatus::Active => sequential.push(row.id),
                TaskStatus::Completed => {
                    assert!(row.id.is_none(), "completed task should not have an id")
                }
                other => panic!("unexpected status {other}"),
            }
        }

        assert_eq!(sequential, vec![Some(1), Some(2)]);
    }

    #[tokio::test]
    async fn test_filter_date_end_before() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let early_complete = Local.with_ymd_and_hms(2024, 5, 1, 8, 0, 0).unwrap();
        let late_complete = Local.with_ymd_and_hms(2024, 5, 3, 8, 0, 0).unwrap();
        let threshold = Local.with_ymd_and_hms(2024, 5, 2, 8, 0, 0).unwrap();

        let completed_early = Task {
            summary: "Completed Early".to_string(),
            date_completed: Some(early_complete),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &completed_early).await.unwrap();

        let completed_late = Task {
            summary: "Completed Late".to_string(),
            date_completed: Some(late_complete),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &completed_late).await.unwrap();

        assert_single_match(
            &db,
            Box::new(DateEndFilter {
                time: threshold,
                before: true,
            }),
            &completed_early,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_depends_on_returns_only_dependents() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let target_task = Task {
            summary: "Target Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        let target_uuid = target_task.uuid;
        write_tasks_impl(&db, &target_task).await.unwrap();

        let mut dependent_task = Task {
            summary: "Dependent Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        let dependent_uuid = dependent_task.uuid;
        dependent_task.links.push(Link {
            id: None,
            from: dependent_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });
        write_tasks_impl(&db, &dependent_task).await.unwrap();

        let independent_task = Task {
            summary: "Independent Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &independent_task).await.unwrap();

        dependent_task.status = TaskStatus::Blocked;
        assert_single_match(
            &db,
            Box::new(DependsOnFilter {
                id: None,
                uuid: Some(target_uuid),
            }),
            &dependent_task,
        )
        .await;
    }

    #[tokio::test]
    async fn test_load_extra_tasks() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let target_task = Task {
            summary: "Target Task".to_string(),
            uuid: Uuid::new_v4(),
            id: Some(1),
            ..Default::default()
        };
        let target_uuid = target_task.uuid;
        write_tasks_impl(&db, &target_task).await.unwrap();

        let mut dependent_task = Task {
            summary: "Dependent Task".to_string(),
            uuid: Uuid::new_v4(),
            id: Some(2),
            ..Default::default()
        };
        let dependent_uuid = dependent_task.uuid;
        dependent_task.links.push(Link {
            id: None,
            from: dependent_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });
        write_tasks_impl(&db, &dependent_task).await.unwrap();

        let independent_task = Task {
            summary: "Independent Task".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &independent_task).await.unwrap();

        // Check for the uuid props extra task
        let filter: Box<dyn Filter> = Box::new(UuidFilter { uuid: target_uuid });

        let mut task_props = TaskProperties::default();
        task_props.depends_on = Some(vec![DependsOnIdentifier::Uuid(dependent_uuid.to_owned())]);
        let results_data = load_tasks_impl(&db, Some(filter.clone()), Some(task_props))
            .await
            .unwrap();
        assert_eq!(results_data.to_vec().len(), 1);
        assert_eq!(results_data.to_vec()[0].uuid, target_uuid);
        assert_eq!(results_data.get_extra_tasks().len(), 1);
        assert_true!(
            results_data
                .get_extra_tasks()
                .get(&dependent_uuid)
                .is_some()
        );

        // check with the ID props extra task
        let mut task_props = TaskProperties::default();
        task_props.depends_on = Some(vec![DependsOnIdentifier::Id(
            dependent_task.id.unwrap().to_owned(),
        )]);
        let results_data = load_tasks_impl(&db, Some(filter.clone()), Some(task_props))
            .await
            .unwrap();
        assert_eq!(results_data.to_vec().len(), 1);
        assert_eq!(results_data.to_vec()[0].uuid, target_uuid);
        assert_eq!(results_data.get_extra_tasks().len(), 1);
        assert_true!(
            results_data
                .get_extra_tasks()
                .get(&dependent_uuid)
                .is_some()
        );
        assert_eq!(
            results_data
                .get_extra_tasks()
                .get(&dependent_uuid)
                .unwrap()
                .id,
            dependent_task.id
        );

        // check with No Task props, should be no extra tasks (?)
        let results_data = load_tasks_impl(&db, Some(filter), None).await.unwrap();
        assert_eq!(results_data.to_vec().len(), 1);
        assert_eq!(results_data.to_vec()[0].uuid, target_uuid);
        assert_true!(results_data.get_extra_tasks().is_empty());
    }

    #[tokio::test]
    async fn test_filter_and_combination() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_active = Task {
            summary: "Alpha Active".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_active).await.unwrap();

        let alpha_pending = Task {
            summary: "Alpha Pending".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_pending).await.unwrap();

        assert_single_match(
            &db,
            Box::new(AndFilter {
                children: vec![
                    Box::new(StatusFilter {
                        status: TaskStatus::Active,
                    }),
                    Box::new(StringFilter {
                        value: "alpha".to_string(),
                    }),
                ],
            }),
            &alpha_active,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_or_combination() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_pending = Task {
            summary: "Alpha Pending".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_pending).await.unwrap();

        let beta_pending = Task {
            summary: "Beta Pending".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &beta_pending).await.unwrap();

        assert_single_match(
            &db,
            Box::new(OrFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "alpha".to_string(),
                    }),
                    Box::new(StatusFilter {
                        status: TaskStatus::Active,
                    }),
                ],
            }),
            &alpha_pending,
        )
        .await;
    }

    #[tokio::test]
    async fn test_filter_xor_combination() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let alpha_pending = Task {
            summary: "Alpha Pending".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_pending).await.unwrap();

        let beta_pending = Task {
            summary: "Beta Pending".to_string(),
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &beta_pending).await.unwrap();

        let alpha_active = Task {
            summary: "Alpha Active".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };
        write_tasks_impl(&db, &alpha_active).await.unwrap();

        assert_single_match(
            &db,
            Box::new(XorFilter {
                children: vec![
                    Box::new(StringFilter {
                        value: "alpha".to_string(),
                    }),
                    Box::new(StatusFilter {
                        status: TaskStatus::Active,
                    }),
                ],
            }),
            &alpha_pending,
        )
        .await;
    }

    #[tokio::test]
    async fn test_update_blocking_status_blocked_has_no_links() {
        init();
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut blocked_task = Task {
            summary: "blocked-task".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };

        let mut blocking_task = Task {
            summary: "blocking-task".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };

        blocking_task.links.push(Link {
            from: blocking_task.uuid,
            to: blocked_task.uuid,
            link_type: LinkType::Blocking,
            id: None,
        });

        write_tasks_impl(&db, &blocked_task).await.unwrap();
        write_tasks_impl(&db, &blocking_task).await.unwrap();
        blocked_task.links.push(Link {
            from: blocked_task.uuid,
            to: blocking_task.uuid,
            link_type: LinkType::DependsOn,
            id: None,
        });
        write_tasks_impl(&db, &blocked_task).await.unwrap();

        let all_tasks = tables::tasks::Entity::find().all(&db).await.unwrap();
        assert_eq!(all_tasks.len(), 2);
        let statuses: Vec<_> = all_tasks.iter().map(|t| t.status.clone()).collect();
        assert!(statuses.contains(&TaskStatus::Active.to_db_string()));
        assert!(statuses.contains(&TaskStatus::Blocked.to_db_string()));

        blocked_task.status = TaskStatus::Blocked;
        assert_single_match(
            &db,
            Box::new(StatusFilter {
                status: TaskStatus::Blocked,
            }),
            &blocked_task,
        )
        .await;

        blocking_task.status = TaskStatus::Completed;
        debug!("hey");
        write_tasks_impl(&db, &blocking_task).await.unwrap();
        let blocked_task_filter: Box<dyn Filter> = Box::new(UuidFilter {
            uuid: blocked_task.uuid.to_owned(),
        });
        let results_data = load_tasks_impl(&db, Some(blocked_task_filter.clone()), None)
            .await
            .unwrap();
        assert_eq!(results_data.to_vec()[0].uuid, blocked_task.uuid);
        assert_eq!(results_data.to_vec()[0].status, TaskStatus::Pending);
    }

    #[tokio::test]
    async fn test_delete_link_blocking() {
        init();
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut blocked_task = Task {
            summary: "blocked-task".to_string(),
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };

        let mut blocking_task = Task {
            summary: "blocking-task".to_string(),
            status: TaskStatus::Active,
            uuid: Uuid::new_v4(),
            ..Default::default()
        };

        blocking_task.links.push(Link {
            from: blocking_task.uuid,
            to: blocked_task.uuid,
            link_type: LinkType::Blocking,
            id: None,
        });

        debug!("first");
        write_tasks_impl(&db, &blocked_task).await.unwrap();
        debug!("second");
        write_tasks_impl(&db, &blocking_task).await.unwrap();
        blocked_task.links.push(Link {
            from: blocked_task.uuid,
            to: blocking_task.uuid,
            link_type: LinkType::DependsOn,
            id: None,
        });
        debug!("third");
        blocked_task.db_id = Some(1);
        debug!("{:?}", blocked_task);
        write_tasks_impl(&db, &blocked_task).await.unwrap();

        let all_links = tables::links::Entity::find().all(&db).await.unwrap();
        debug!("{:?}", all_links);
        // Only DependsOn links are stored in DB; Blocking links are virtual
        assert_eq!(all_links.len(), 1);

        let all_tasks = tables::tasks::Entity::find().all(&db).await.unwrap();
        assert_eq!(all_tasks.len(), 2);
        let statuses: Vec<_> = all_tasks.iter().map(|t| t.status.clone()).collect();
        assert!(statuses.contains(&TaskStatus::Active.to_db_string()));
        assert!(statuses.contains(&TaskStatus::Blocked.to_db_string()));

        let blocked_task_filter: Box<dyn Filter> = Box::new(UuidFilter {
            uuid: blocked_task.uuid.to_owned(),
        });
        blocked_task.status = TaskStatus::Blocked;

        blocked_task.links = [].to_vec();
        blocking_task.links = [].to_vec();
        write_tasks_impl(&db, &blocking_task).await.unwrap();
        write_tasks_impl(&db, &blocked_task).await.unwrap();
        let all_links = tables::links::Entity::find().all(&db).await.unwrap();
        assert_eq!(all_links.len(), 0);

        let results_data = load_tasks_impl(&db, Some(blocked_task_filter), None)
            .await
            .unwrap();
        assert_eq!(results_data.to_vec()[0].uuid, blocked_task.uuid);
        assert_eq!(results_data.to_vec()[0].status, TaskStatus::Pending);
    }
}
