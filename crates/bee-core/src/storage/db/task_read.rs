use super::filter_sql::{condition_expression_to_condition, filter_to_condition_expr};
use super::tables;
use crate::{
    filters::{
        self, Filter,
        filters_impl::{OrFilter, TaskIdFilter, UuidFilter},
    },
    task::{
        DependsOnIdentifier, Link, LinkType, Project, Task, TaskAnnotation, TaskData, TaskHistory,
        TaskProperties, TaskStatus,
    },
};
use tables::{annotations, history, links, projects, tags, tasks, tasks_tags};

use chrono::{DateTime, Local};
use std::collections::HashMap;
use uuid::Uuid;

use sea_orm::{
    ColumnTrait, ConnectionTrait, DatabaseConnection, EntityTrait, QueryFilter, QueryOrder,
};

pub(super) async fn load_tasks_impl(
    db: &DatabaseConnection,
    filter_opt: Option<Box<dyn Filter>>,
    props: Option<TaskProperties>,
) -> Result<TaskData, Box<dyn std::error::Error>> {
    let filter = filter_opt.unwrap_or_else(filters::new_empty);
    let tasks_obj = tasks_from_filter(db, filter.as_ref()).await?;

    let mut task_data = TaskData::default();
    for t in tasks_obj {
        task_data.add_task_object(t);
    }
    if let Some(props) = props {
        let mut extra_task_filter = OrFilter::default();

        for task_identifier in props.get_referenced_tasks() {
            match task_identifier {
                DependsOnIdentifier::Uuid(uuid) => {
                    extra_task_filter
                        .children
                        .push(Box::new(UuidFilter { uuid }));
                }
                DependsOnIdentifier::Id(id) => {
                    extra_task_filter
                        .children
                        .push(Box::new(TaskIdFilter { id }));
                }
            }
        }
        let f: Box<dyn Filter> = Box::new(extra_task_filter);
        let extra_tasks_obj = tasks_from_filter(db, f.as_ref()).await?;
        for t in extra_tasks_obj {
            task_data.insert_extra_task(t);
        }
    }

    Ok(task_data)
}

pub(super) async fn tasks_from_filter(
    db: &DatabaseConnection,
    filter: &dyn Filter,
) -> Result<Vec<Task>, Box<dyn std::error::Error>> {
    let models = tables::tasks::Entity::find()
        .filter(condition_expression_to_condition(filter_to_condition_expr(
            filter,
        )))
        .all(db)
        .await?;
    let mut tasks_obj = Vec::new();
    for model in models {
        tasks_obj.push(task_model_to_object(db, &model).await?);
    }
    Ok(tasks_obj)
}

/// Build an in-memory [`Task`] from the persisted database model and its related tables.
pub(super) async fn task_model_to_object<C>(
    db: &C,
    task_model: &tasks::Model,
) -> Result<Task, Box<dyn std::error::Error>>
where
    C: ConnectionTrait,
{
    let parse_datetime = |value: &str| -> Result<DateTime<Local>, chrono::ParseError> {
        DateTime::parse_from_rfc3339(value).map(|dt| dt.with_timezone(&Local))
    };

    let uuid = Uuid::parse_str(&task_model.uuid)?;
    let status = TaskStatus::from_string(&task_model.status)
        .map_err(|err| std::io::Error::new(std::io::ErrorKind::InvalidData, err))?;
    let date_created = parse_datetime(&task_model.date_created)?;
    let date_completed = task_model
        .date_completed
        .as_ref()
        .map(|value| parse_datetime(value))
        .transpose()?;
    let date_due = task_model
        .date_due
        .as_ref()
        .map(|value| parse_datetime(value))
        .transpose()?;
    let urgency = task_model.urgency.map(|value| value as i64);

    let project = match task_model.project_id {
        Some(project_id) => {
            let project_model = projects::Entity::find_by_id(project_id).one(db).await?;
            project_model.map(|model| Project {
                id: Some(model.id),
                name: model.name,
            })
        }
        None => None,
    };

    let tag_links = tasks_tags::Entity::find()
        .filter(tasks_tags::Column::TaskId.eq(task_model.db_id))
        .all(db)
        .await?;
    let tag_ids: Vec<i32> = tag_links.iter().map(|link| link.tag_id).collect();
    let tags = if tag_ids.is_empty() {
        Vec::new()
    } else {
        tags::Entity::find()
            .filter(tags::Column::Id.is_in(tag_ids))
            .order_by_asc(tags::Column::Name)
            .all(db)
            .await?
            .into_iter()
            .map(|model| model.name)
            .collect()
    };

    let annotation_models = annotations::Entity::find()
        .filter(annotations::Column::TaskId.eq(task_model.db_id))
        .order_by_asc(annotations::Column::Datetime)
        .all(db)
        .await?;

    let mut annotations_vec = Vec::with_capacity(annotation_models.len());
    for model in annotation_models {
        annotations_vec.push(TaskAnnotation {
            id: Some(model.id),
            value: model.value,
            time: parse_datetime(&model.datetime)?,
        });
    }

    let history_models = history::Entity::find()
        .filter(history::Column::TaskId.eq(task_model.db_id))
        .order_by_asc(history::Column::Datetime)
        .all(db)
        .await?;
    let mut history_vec = Vec::with_capacity(history_models.len());
    for model in history_models {
        history_vec.push(TaskHistory {
            id: Some(model.id),
            value: model.value,
            datetime: parse_datetime(&model.datetime)?,
        });
    }

    // Load outgoing DependsOn links (this task depends on others)
    let outgoing_link_models = links::Entity::find()
        .filter(links::Column::FromTaskId.eq(task_model.db_id))
        .filter(links::Column::Type.eq(LinkType::DependsOn.to_string()))
        .all(db)
        .await?;

    // Load incoming DependsOn links (other tasks depend on this one)
    // These will be converted to Blocking links from this task's perspective
    let incoming_link_models = links::Entity::find()
        .filter(links::Column::ToTaskId.eq(task_model.db_id))
        .filter(links::Column::Type.eq(LinkType::DependsOn.to_string()))
        .all(db)
        .await?;

    let mut links_vec = Vec::with_capacity(outgoing_link_models.len() + incoming_link_models.len());

    // Process outgoing DependsOn links
    if !outgoing_link_models.is_empty() {
        let to_ids: Vec<i32> = outgoing_link_models
            .iter()
            .map(|link| link.to_task_id)
            .collect();
        let target_models = tasks::Entity::find()
            .filter(tasks::Column::DbId.is_in(to_ids))
            .all(db)
            .await?;

        let mut to_uuid_map: HashMap<i32, Uuid> = HashMap::new();
        for model in target_models {
            let target_uuid = Uuid::parse_str(&model.uuid)?;
            to_uuid_map.insert(model.db_id, target_uuid);
        }

        for link in outgoing_link_models {
            let to_uuid = *to_uuid_map.get(&link.to_task_id).ok_or_else(|| {
                std::io::Error::new(
                    std::io::ErrorKind::NotFound,
                    format!(
                        "Could not resolve linked task id {} to a UUID",
                        link.to_task_id
                    ),
                )
            })?;

            links_vec.push(Link {
                id: Some(link.id),
                from: uuid,
                to: to_uuid,
                link_type: LinkType::DependsOn,
            });
        }
    }

    // Process incoming DependsOn links -> convert to Blocking links
    // If task A depends on this task (B), then B blocks A
    if !incoming_link_models.is_empty() {
        let from_ids: Vec<i32> = incoming_link_models
            .iter()
            .map(|link| link.from_task_id)
            .collect();
        let source_models = tasks::Entity::find()
            .filter(tasks::Column::DbId.is_in(from_ids))
            .all(db)
            .await?;

        let mut from_uuid_map: HashMap<i32, Uuid> = HashMap::new();
        for model in source_models {
            let source_uuid = Uuid::parse_str(&model.uuid)?;
            from_uuid_map.insert(model.db_id, source_uuid);
        }

        for link in incoming_link_models {
            let blocked_task_uuid = *from_uuid_map.get(&link.from_task_id).ok_or_else(|| {
                std::io::Error::new(
                    std::io::ErrorKind::NotFound,
                    format!(
                        "Could not resolve linked task id {} to a UUID",
                        link.from_task_id
                    ),
                )
            })?;

            // Create a virtual Blocking link (id: None since it's not directly stored)
            links_vec.push(Link {
                id: None, // Virtual link, reconstructed from incoming DependsOn
                from: uuid,
                to: blocked_task_uuid,
                link_type: LinkType::Blocking,
            });
        }
    }

    Ok(Task {
        db_id: Some(task_model.db_id),
        id: task_model.id,
        status,
        uuid,
        summary: task_model.summary.to_owned(),
        annotations: annotations_vec,
        tags,
        date_created,
        date_completed,
        links: links_vec,
        project,
        date_due,
        urgency,
        history: history_vec,
    })
}

#[cfg(test)]
mod tests {
    use super::super::{connection::get_database, tables, task_write::write_tasks_impl};
    use super::*;
    use crate::{
        filters::{
            Filter,
            filters_impl::{
                AndFilter, DateCreatedFilter, DateDueFilter, DateDueFilterType, DateEndFilter,
                DependsOnFilter, OrFilter, ProjectFilter, StatusFilter, StringFilter, TagFilter,
                TaskIdFilter, UuidFilter, XorFilter,
            },
        },
        task::{DependsOnIdentifier, Link, LinkType, Project, Task, TaskProperties, TaskStatus},
    };
    use all_asserts::assert_true;
    use chrono::{Duration, Local, TimeZone};
    use log::debug;
    use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};
    use uuid::Uuid;

    /// Compare the filtered results against a single expected task.
    async fn assert_single_match(
        db: &DatabaseConnection,
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

        expected_task_mut.id = result.id;
        assert_eq!(result, &expected_task_mut);
    }

    /// Initialize a test logger once for noisy DB tests.
    fn init_logger() {
        let _ = env_logger::builder()
            .is_test(true)
            .filter_module("sqlx", log::LevelFilter::Off)
            .try_init();
    }

    #[tokio::test]
    async fn test_insert_load_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        let t = Task {
            summary: "foo bar cafe".to_string(),
            ..Default::default()
        };
        let saved_uuid = t.uuid;

        write_tasks_impl(&db, &t).await.unwrap();

        let initial_db_task = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(saved_uuid.to_string()))
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
    async fn test_filter_status_matches_single_task() {
        init_logger();
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
}
