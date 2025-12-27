use super::tables;
use crate::task::{Link, LinkType, TaskAnnotation, TaskHistory};
use tables::{annotations, history, links, tags, tasks, tasks_tags};

use log::debug;
use std::collections::{HashMap, HashSet};
use uuid::Uuid;

use sea_orm::{
    ActiveModelTrait,
    ActiveValue::{self, Set},
    ColumnTrait, Condition, ConnectionTrait, DatabaseTransaction, DbErr, EntityTrait,
    IntoActiveModel, QueryFilter,
};

/// Placeholder function for converting a Uuid to the corresponding database id.
pub(super) async fn resolve_uuid_to_db_id<C>(db: &C, id: Uuid) -> Result<Option<i32>, DbErr>
where
    C: ConnectionTrait,
{
    let task = tasks::Entity::find()
        .filter(tasks::Column::Uuid.eq(id.to_string()))
        .one(db)
        .await?;

    Ok(task.map(|model| model.db_id))
}

/// Convert a database id to the corresponding UUID.
pub(super) async fn resolve_db_id_to_uuid<C>(db: &C, db_id: i32) -> Result<Option<Uuid>, DbErr>
where
    C: ConnectionTrait,
{
    let task = tasks::Entity::find_by_id(db_id).one(db).await?;
    match task {
        Some(model) => Ok(Uuid::parse_str(&model.uuid).ok()),
        None => Ok(None),
    }
}

pub(super) async fn sync_annotations(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_annotations: &[TaskAnnotation],
) -> Result<(), DbErr> {
    let existing_rows: Vec<annotations::Model> = annotations::Entity::find()
        .filter(annotations::Column::TaskId.eq(task_model.db_id))
        .all(db)
        .await?;

    let mut existing_map: HashMap<i32, annotations::Model> = HashMap::new();
    let mut existing_ids = Vec::new();
    for row in existing_rows {
        existing_ids.push(row.id);
        existing_map.insert(row.id, row);
    }

    let desired_ids: HashSet<i32> = desired_annotations
        .iter()
        .filter_map(|ann| ann.id)
        .collect();

    let to_delete: Vec<i32> = existing_ids
        .into_iter()
        .filter(|id| !desired_ids.contains(id))
        .collect();
    if !to_delete.is_empty() {
        annotations::Entity::delete_many()
            .filter(
                Condition::all()
                    .add(annotations::Column::TaskId.eq(task_model.db_id))
                    .add(annotations::Column::Id.is_in(to_delete)),
            )
            .exec(db)
            .await?;
    }

    for ann in desired_annotations {
        let datetime = ann.time.to_rfc3339();
        if let Some(id) = ann.id
            && let Some(existing_model) = existing_map.get(&id)
        {
            let mut active = existing_model.clone().into_active_model();
            let mut changed = false;

            if existing_model.value != ann.value {
                active.value = Set(ann.value.clone());
                changed = true;
            } else {
                active.value = ActiveValue::Unchanged(existing_model.value.clone());
            }

            if existing_model.datetime != datetime {
                active.datetime = Set(datetime.clone());
                changed = true;
            } else {
                active.datetime = ActiveValue::Unchanged(existing_model.datetime.clone());
            }

            if existing_model.task_id != task_model.db_id {
                active.task_id = Set(task_model.db_id);
                changed = true;
            } else {
                active.task_id = ActiveValue::Unchanged(existing_model.task_id);
            }

            if changed {
                active.save(db).await?;
            }
            continue;
        }

        annotations::ActiveModel {
            id: ActiveValue::NotSet,
            value: Set(ann.value.clone()),
            datetime: Set(datetime.clone()),
            task_id: Set(task_model.db_id),
        }
        .save(db)
        .await?;
    }
    Ok(())
}

pub(super) async fn sync_history(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_history: &[TaskHistory],
) -> Result<(), DbErr> {
    let existing_rows: Vec<history::Model> = history::Entity::find()
        .filter(history::Column::TaskId.eq(task_model.db_id))
        .all(db)
        .await?;

    let mut existing_map: HashMap<i32, history::Model> = HashMap::new();
    let mut existing_ids = Vec::new();
    for row in existing_rows {
        existing_ids.push(row.id);
        existing_map.insert(row.id, row);
    }

    let desired_ids: HashSet<i32> = desired_history.iter().filter_map(|evt| evt.id).collect();

    let to_delete: Vec<i32> = existing_ids
        .into_iter()
        .filter(|id| !desired_ids.contains(id))
        .collect();
    if !to_delete.is_empty() {
        history::Entity::delete_many()
            .filter(
                Condition::all()
                    .add(history::Column::TaskId.eq(task_model.db_id))
                    .add(history::Column::Id.is_in(to_delete)),
            )
            .exec(db)
            .await?;
    }

    for evt in desired_history {
        let datetime = evt.datetime.to_rfc3339();
        if let Some(id) = evt.id
            && let Some(existing_model) = existing_map.get(&id)
        {
            let mut active = existing_model.clone().into_active_model();
            let mut changed = false;

            if existing_model.value != evt.value {
                active.value = Set(evt.value.clone());
                changed = true;
            } else {
                active.value = ActiveValue::Unchanged(existing_model.value.clone());
            }

            if existing_model.datetime != datetime {
                active.datetime = Set(datetime.clone());
                changed = true;
            } else {
                active.datetime = ActiveValue::Unchanged(existing_model.datetime.clone());
            }

            if existing_model.task_id != task_model.db_id {
                active.task_id = Set(task_model.db_id);
                changed = true;
            } else {
                active.task_id = ActiveValue::Unchanged(existing_model.task_id);
            }

            if changed {
                active.save(db).await?;
            }
            continue;
        }

        history::ActiveModel {
            id: ActiveValue::NotSet,
            value: Set(evt.value.clone()),
            datetime: Set(datetime.clone()),
            task_id: Set(task_model.db_id),
        }
        .save(db)
        .await?;
    }
    Ok(())
}

pub(super) async fn sync_links(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_links: &[Link],
) -> Result<(), DbErr> {
    // === PART A: Handle outgoing DependsOn links (links FROM this task) ===
    // Only persist DependsOn links; Blocking links are virtual (reconstructed at load time)

    let desired_depends_on: Vec<&Link> = desired_links
        .iter()
        .filter(|link| link.link_type == LinkType::DependsOn)
        .collect();

    // Only consider existing DependsOn links from this task
    let existing_rows: Vec<links::Model> = links::Entity::find()
        .filter(links::Column::FromTaskId.eq(task_model.db_id))
        .filter(links::Column::Type.eq(LinkType::DependsOn.to_string()))
        .all(db)
        .await?;

    let mut existing_map: HashMap<i32, links::Model> = HashMap::new();
    let mut existing_ids = Vec::new();
    debug!("Existing outgoing DependsOn rows:");
    for row in existing_rows {
        debug!("row: {:?}", row);
        existing_ids.push(row.id);
        existing_map.insert(row.id, row);
    }

    let desired_ids: HashSet<i32> = desired_depends_on
        .iter()
        .filter_map(|link| link.id)
        .collect();

    let to_delete: Vec<i32> = existing_ids
        .into_iter()
        .filter(|id| !desired_ids.contains(id))
        .collect();
    if !to_delete.is_empty() {
        debug!(
            "Deleting outgoing DependsOn links with ids: {:?}",
            to_delete
        );
        links::Entity::delete_many()
            .filter(links::Column::Id.is_in(to_delete))
            .exec(db)
            .await?;
    }

    // Build target cache for DependsOn links only
    let mut target_cache: HashMap<Uuid, Option<i32>> = HashMap::new();
    for link in &desired_depends_on {
        target_cache
            .entry(link.to)
            .or_insert(resolve_uuid_to_db_id(db, link.to).await?);
    }

    // Insert or update DependsOn links
    for link in &desired_depends_on {
        let to_db_id = target_cache
            .get(&link.to)
            .and_then(|id| *id)
            .ok_or_else(|| DbErr::RecordNotFound(format!("Unknown target {}", link.to)))?;

        if let Some(id) = link.id
            && let Some(existing_model) = existing_map.get(&id)
        {
            let mut active = existing_model.clone().into_active_model();
            let mut changed = false;

            if existing_model.from_task_id != task_model.db_id {
                active.from_task_id = Set(task_model.db_id);
                changed = true;
            } else {
                active.from_task_id = ActiveValue::Unchanged(existing_model.from_task_id);
            }

            if existing_model.to_task_id != to_db_id {
                active.to_task_id = Set(to_db_id);
                changed = true;
            } else {
                active.to_task_id = ActiveValue::Unchanged(existing_model.to_task_id);
            }

            // Link type is always DependsOn in this branch, but check for consistency
            let link_type_string = LinkType::DependsOn.to_string();
            if existing_model.r#type != link_type_string {
                active.r#type = Set(link_type_string);
                changed = true;
            } else {
                active.r#type = ActiveValue::Unchanged(existing_model.r#type.clone());
            }

            if changed {
                active.save(db).await?;
            }
            continue;
        }

        links::ActiveModel {
            id: ActiveValue::NotSet,
            from_task_id: Set(task_model.db_id),
            to_task_id: Set(to_db_id),
            r#type: Set(LinkType::DependsOn.to_string()),
        }
        .save(db)
        .await?;
    }

    // === PART B: Handle Blocking link removal (delete incoming DependsOn links) ===
    // When user removes a Blocking link from this task, we need to delete the corresponding
    // DependsOn link that was stored from the other task's perspective.

    // Get UUIDs of tasks we want to KEEP blocking (from Blocking links in desired_links)
    let desired_blocking_targets: HashSet<Uuid> = desired_links
        .iter()
        .filter(|l| l.link_type == LinkType::Blocking)
        .map(|l| l.to) // The task that depends on us
        .collect();

    // Load existing incoming DependsOn links (other tasks that depend on this one)
    let existing_incoming: Vec<links::Model> = links::Entity::find()
        .filter(links::Column::ToTaskId.eq(task_model.db_id))
        .filter(links::Column::Type.eq(LinkType::DependsOn.to_string()))
        .all(db)
        .await?;

    // For each incoming DependsOn, if user removed the Blocking link, delete it
    for incoming in existing_incoming {
        let source_uuid = resolve_db_id_to_uuid(db, incoming.from_task_id).await?;
        if let Some(uuid) = source_uuid
            && !desired_blocking_targets.contains(&uuid)
        {
            // User removed this blocking relationship
            debug!(
                "Deleting incoming DependsOn link id {} (from task {} depends on this task)",
                incoming.id, incoming.from_task_id
            );
            links::Entity::delete_by_id(incoming.id).exec(db).await?;
        }
    }

    Ok(())
}

pub(super) async fn sync_tags(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_tags: &[String],
) -> Result<(), DbErr> {
    let existing_task_tags: Vec<tasks_tags::Model> = tasks_tags::Entity::find()
        .filter(tasks_tags::Column::TaskId.eq(task_model.db_id))
        .all(db)
        .await?;

    let existing_tag_ids: HashSet<i32> = existing_task_tags.iter().map(|row| row.tag_id).collect();

    let mut desired_tag_ids = HashSet::new();
    for tag_name in desired_tags {
        let tag_model = match tags::Entity::find()
            .filter(tags::Column::Name.eq(tag_name.clone()))
            .one(db)
            .await?
        {
            Some(model) => model,
            None => {
                tags::ActiveModel {
                    id: ActiveValue::NotSet,
                    name: Set(tag_name.clone()),
                }
                .insert(db)
                .await?
            }
        };

        desired_tag_ids.insert(tag_model.id);

        if !existing_tag_ids.contains(&tag_model.id) {
            tasks_tags::ActiveModel {
                task_id: Set(task_model.db_id),
                tag_id: Set(tag_model.id),
            }
            .insert(db)
            .await?;
        }
    }

    let stale_tag_ids: Vec<i32> = existing_tag_ids
        .difference(&desired_tag_ids)
        .copied()
        .collect();
    if !stale_tag_ids.is_empty() {
        tasks_tags::Entity::delete_many()
            .filter(
                Condition::all()
                    .add(tasks_tags::Column::TaskId.eq(task_model.db_id))
                    .add(tasks_tags::Column::TagId.is_in(stale_tag_ids)),
            )
            .exec(db)
            .await?;
    }

    Ok(())
}
