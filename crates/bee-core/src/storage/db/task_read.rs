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
