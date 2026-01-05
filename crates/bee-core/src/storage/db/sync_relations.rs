use super::tables;
use crate::email_link::EmailLink;
use crate::task::{Link, LinkType, TaskAnnotation, TaskHistory};
use tables::{annotations, email_links, history, links, tags, tasks, tasks_tags};

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

/// Sync links for a task to the database.
///
/// Link storage strategy:
/// - **Asymmetric canonical types** (DependsOn, ParentOf): Stored as-is from this task
/// - **Asymmetric inferred types** (Blocking, ChildOf): Not stored; we delete the inverse canonical link
/// - **Symmetric types** (RelatedTo, Duplicates): Stored with canonical ordering (lower UUID = from)
pub(super) async fn sync_links(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_links: &[Link],
) -> Result<(), DbErr> {
    let this_uuid = Uuid::parse_str(&task_model.uuid)
        .map_err(|e| DbErr::Custom(format!("Invalid UUID: {}", e)))?;

    // === PART A: Handle outgoing canonical links (DependsOn, ParentOf) ===
    // These are stored as links FROM this task TO the target

    let canonical_asymmetric_types = [LinkType::DependsOn, LinkType::ParentOf];

    for link_type in &canonical_asymmetric_types {
        let desired_of_type: Vec<&Link> = desired_links
            .iter()
            .filter(|link| &link.link_type == link_type)
            .collect();

        let existing_rows: Vec<links::Model> = links::Entity::find()
            .filter(links::Column::FromTaskId.eq(task_model.db_id))
            .filter(links::Column::Type.eq(link_type.to_string()))
            .all(db)
            .await?;

        let mut existing_map: HashMap<i32, links::Model> = HashMap::new();
        let mut existing_ids = Vec::new();
        debug!("Existing outgoing {:?} rows:", link_type);
        for row in existing_rows {
            debug!("row: {:?}", row);
            existing_ids.push(row.id);
            existing_map.insert(row.id, row);
        }

        let desired_ids: HashSet<i32> = desired_of_type.iter().filter_map(|link| link.id).collect();

        let to_delete: Vec<i32> = existing_ids
            .into_iter()
            .filter(|id| !desired_ids.contains(id))
            .collect();
        if !to_delete.is_empty() {
            debug!(
                "Deleting outgoing {:?} links with ids: {:?}",
                link_type, to_delete
            );
            links::Entity::delete_many()
                .filter(links::Column::Id.is_in(to_delete))
                .exec(db)
                .await?;
        }

        // Build target cache
        let mut target_cache: HashMap<Uuid, Option<i32>> = HashMap::new();
        for link in &desired_of_type {
            target_cache
                .entry(link.to)
                .or_insert(resolve_uuid_to_db_id(db, link.to).await?);
        }

        // Insert or update links
        for link in &desired_of_type {
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

                let link_type_string = link_type.to_string();
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
                r#type: Set(link_type.to_string()),
            }
            .save(db)
            .await?;
        }
    }

    // === PART A2: Handle inferred asymmetric links (Blocking, ChildOf) ===
    // These are stored with canonical type and SWAPPED direction
    // e.g., Blocking(from=A, to=B) → DependsOn(from=B, to=A) in database
    // This means "B depends on A" which displays as "A blocks B"

    let inferred_to_canonical_for_storage = [
        (LinkType::Blocking, LinkType::DependsOn),
        (LinkType::ChildOf, LinkType::ParentOf),
    ];

    for (inferred_type, canonical_type) in &inferred_to_canonical_for_storage {
        let desired_of_type: Vec<&Link> = desired_links
            .iter()
            .filter(|link| &link.link_type == inferred_type)
            .collect();

        // For inferred types, we store as canonical with swapped from/to
        // So we query for links TO this task (since we store them swapped)
        let existing_rows: Vec<links::Model> = links::Entity::find()
            .filter(links::Column::ToTaskId.eq(task_model.db_id))
            .filter(links::Column::Type.eq(canonical_type.to_string()))
            .all(db)
            .await?;

        let mut existing_map: HashMap<i32, links::Model> = HashMap::new();
        for row in existing_rows {
            existing_map.insert(row.id, row);
        }

        // Build target cache (targets become "from" in the stored link)
        let mut target_cache: HashMap<Uuid, Option<i32>> = HashMap::new();
        for link in &desired_of_type {
            target_cache
                .entry(link.to)
                .or_insert(resolve_uuid_to_db_id(db, link.to).await?);
        }

        // Determine which existing links to keep
        let desired_targets: HashSet<Uuid> = desired_of_type.iter().map(|l| l.to).collect();

        // Delete links that are no longer desired
        for row in existing_map.values() {
            let source_uuid = resolve_db_id_to_uuid(db, row.from_task_id).await?;
            if let Some(uuid) = source_uuid
                && !desired_targets.contains(&uuid)
            {
                debug!(
                    "Deleting {:?} link id {} (stored as {:?} from {} to this task)",
                    inferred_type, row.id, canonical_type, row.from_task_id
                );
                links::Entity::delete_by_id(row.id).exec(db).await?;
            }
        }

        // Insert new links (stored with swapped direction and canonical type)
        for link in &desired_of_type {
            // Check if this link already exists
            let target_db_id = target_cache
                .get(&link.to)
                .and_then(|id| *id)
                .ok_or_else(|| DbErr::RecordNotFound(format!("Unknown target {}", link.to)))?;

            let already_exists = existing_map
                .values()
                .any(|row| row.from_task_id == target_db_id);

            if !already_exists {
                debug!(
                    "Inserting {:?} link as {:?}(from={}, to={})",
                    inferred_type, canonical_type, target_db_id, task_model.db_id
                );
                links::ActiveModel {
                    id: ActiveValue::NotSet,
                    from_task_id: Set(target_db_id), // Swapped: target becomes "from"
                    to_task_id: Set(task_model.db_id), // Swapped: this task becomes "to"
                    r#type: Set(canonical_type.to_string()),
                }
                .save(db)
                .await?;
            }
        }
    }

    // === PART B: Handle symmetric links (RelatedTo, Duplicates) ===
    // These are stored with canonical ordering: lower UUID is always 'from'
    // When this task has the lower UUID, store normally
    // When this task has the higher UUID, store with swapped from/to

    let symmetric_types = [LinkType::RelatedTo, LinkType::Duplicates];

    for link_type in &symmetric_types {
        // Get all desired links of this type
        let all_desired: Vec<&Link> = desired_links
            .iter()
            .filter(|link| &link.link_type == link_type)
            .collect();

        // Split into two groups: where we store from this task vs from target
        let desired_store_from_self: Vec<&Link> = all_desired
            .iter()
            .filter(|link| this_uuid < link.to)
            .copied()
            .collect();
        let desired_store_from_target: Vec<&Link> = all_desired
            .iter()
            .filter(|link| this_uuid > link.to)
            .copied()
            .collect();

        // === Handle links stored FROM this task (this_uuid < target) ===
        let existing_outgoing: Vec<links::Model> = links::Entity::find()
            .filter(links::Column::FromTaskId.eq(task_model.db_id))
            .filter(links::Column::Type.eq(link_type.to_string()))
            .all(db)
            .await?;

        let mut existing_outgoing_map: HashMap<i32, links::Model> = HashMap::new();
        let mut existing_outgoing_ids = Vec::new();
        for row in existing_outgoing {
            existing_outgoing_ids.push(row.id);
            existing_outgoing_map.insert(row.id, row);
        }

        let desired_outgoing_ids: HashSet<i32> = desired_store_from_self
            .iter()
            .filter_map(|link| link.id)
            .collect();

        let outgoing_to_delete: Vec<i32> = existing_outgoing_ids
            .into_iter()
            .filter(|id| !desired_outgoing_ids.contains(id))
            .collect();
        if !outgoing_to_delete.is_empty() {
            debug!(
                "Deleting outgoing {:?} links with ids: {:?}",
                link_type, outgoing_to_delete
            );
            links::Entity::delete_many()
                .filter(links::Column::Id.is_in(outgoing_to_delete))
                .exec(db)
                .await?;
        }

        // Build target cache for outgoing
        let mut target_cache: HashMap<Uuid, Option<i32>> = HashMap::new();
        for link in &desired_store_from_self {
            target_cache
                .entry(link.to)
                .or_insert(resolve_uuid_to_db_id(db, link.to).await?);
        }

        // Insert new outgoing links
        for link in &desired_store_from_self {
            if link.id.is_some() {
                continue;
            }

            let to_db_id = target_cache
                .get(&link.to)
                .and_then(|id| *id)
                .ok_or_else(|| DbErr::RecordNotFound(format!("Unknown target {}", link.to)))?;

            links::ActiveModel {
                id: ActiveValue::NotSet,
                from_task_id: Set(task_model.db_id),
                to_task_id: Set(to_db_id),
                r#type: Set(link_type.to_string()),
            }
            .save(db)
            .await?;
        }

        // === Handle links stored FROM target (this_uuid > target, need swapped storage) ===
        let existing_incoming: Vec<links::Model> = links::Entity::find()
            .filter(links::Column::ToTaskId.eq(task_model.db_id))
            .filter(links::Column::Type.eq(link_type.to_string()))
            .all(db)
            .await?;

        let mut existing_incoming_map: HashMap<i32, links::Model> = HashMap::new();
        for row in existing_incoming {
            existing_incoming_map.insert(row.id, row);
        }

        // Build target cache for incoming (targets have lower UUID)
        let mut incoming_target_cache: HashMap<Uuid, Option<i32>> = HashMap::new();
        for link in &desired_store_from_target {
            incoming_target_cache
                .entry(link.to)
                .or_insert(resolve_uuid_to_db_id(db, link.to).await?);
        }

        // Determine which targets we want to keep
        let desired_incoming_targets: HashSet<Uuid> =
            desired_store_from_target.iter().map(|l| l.to).collect();

        // Delete incoming links that are no longer desired
        for row in existing_incoming_map.values() {
            let source_uuid = resolve_db_id_to_uuid(db, row.from_task_id).await?;
            if let Some(uuid) = source_uuid
                && !desired_incoming_targets.contains(&uuid)
            {
                debug!(
                    "Deleting incoming {:?} link id {} (from task {})",
                    link_type, row.id, row.from_task_id
                );
                links::Entity::delete_by_id(row.id).exec(db).await?;
            }
        }

        // Insert new links with swapped direction (from=target, to=this_task)
        for link in &desired_store_from_target {
            let target_db_id = incoming_target_cache
                .get(&link.to)
                .and_then(|id| *id)
                .ok_or_else(|| DbErr::RecordNotFound(format!("Unknown target {}", link.to)))?;

            let already_exists = existing_incoming_map
                .values()
                .any(|row| row.from_task_id == target_db_id);

            if !already_exists {
                debug!(
                    "Inserting {:?} link with canonical ordering (from={}, to={})",
                    link_type, target_db_id, task_model.db_id
                );
                links::ActiveModel {
                    id: ActiveValue::NotSet,
                    from_task_id: Set(target_db_id), // Lower UUID is "from"
                    to_task_id: Set(task_model.db_id), // Higher UUID (this) is "to"
                    r#type: Set(link_type.to_string()),
                }
                .save(db)
                .await?;
            }
        }
    }

    // === PART C: Handle inferred link removal (Blocking, ChildOf) ===
    // This is now handled by PART A2 above - when desired_of_type is empty,
    // all existing incoming canonical links will be deleted.

    // Legacy cleanup: remove any orphaned incoming canonical links
    // that don't have corresponding inferred links in our desired set
    let inferred_to_canonical = [
        (LinkType::Blocking, LinkType::DependsOn),
        (LinkType::ChildOf, LinkType::ParentOf),
    ];

    for (inferred_type, canonical_type) in &inferred_to_canonical {
        // Get UUIDs of tasks we want to KEEP the relationship with
        let desired_targets: HashSet<Uuid> = desired_links
            .iter()
            .filter(|l| &l.link_type == inferred_type)
            .map(|l| l.to)
            .collect();

        // Load existing incoming canonical links (other tasks that have canonical link to us)
        let existing_incoming: Vec<links::Model> = links::Entity::find()
            .filter(links::Column::ToTaskId.eq(task_model.db_id))
            .filter(links::Column::Type.eq(canonical_type.to_string()))
            .all(db)
            .await?;

        // For each incoming canonical link, if user removed the inferred link, delete it
        for incoming in existing_incoming {
            let source_uuid = resolve_db_id_to_uuid(db, incoming.from_task_id).await?;
            if let Some(uuid) = source_uuid
                && !desired_targets.contains(&uuid)
            {
                debug!(
                    "Deleting incoming {:?} link id {} (from task {} to this task)",
                    canonical_type, incoming.id, incoming.from_task_id
                );
                links::Entity::delete_by_id(incoming.id).exec(db).await?;
            }
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

/// Sync email links for a task to the database.
///
/// Email links store references to emails in Apple Mail, identified by
/// RFC 5322 Message-ID. This allows tasks to be linked to specific emails.
pub(super) async fn sync_email_links(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_email_links: &[EmailLink],
) -> Result<(), DbErr> {
    let existing_rows: Vec<email_links::Model> = email_links::Entity::find()
        .filter(email_links::Column::TaskId.eq(task_model.db_id))
        .all(db)
        .await?;

    let mut existing_map: HashMap<i32, email_links::Model> = HashMap::new();
    let mut existing_ids = Vec::new();
    for row in existing_rows {
        existing_ids.push(row.id);
        existing_map.insert(row.id, row);
    }

    let desired_ids: HashSet<i32> = desired_email_links
        .iter()
        .filter_map(|link| link.id)
        .collect();

    let to_delete: Vec<i32> = existing_ids
        .into_iter()
        .filter(|id| !desired_ids.contains(id))
        .collect();
    if !to_delete.is_empty() {
        email_links::Entity::delete_many()
            .filter(
                Condition::all()
                    .add(email_links::Column::TaskId.eq(task_model.db_id))
                    .add(email_links::Column::Id.is_in(to_delete)),
            )
            .exec(db)
            .await?;
    }

    for link in desired_email_links {
        let created_at = link.created_at.to_rfc3339();
        let sent_date = link.sent_date.map(|dt| dt.to_rfc3339());

        if let Some(id) = link.id
            && let Some(existing_model) = existing_map.get(&id)
        {
            let mut active = existing_model.clone().into_active_model();
            let mut changed = false;

            if existing_model.message_id != link.message_id {
                active.message_id = Set(link.message_id.clone());
                changed = true;
            } else {
                active.message_id = ActiveValue::Unchanged(existing_model.message_id.clone());
            }

            if existing_model.subject != link.subject {
                active.subject = Set(link.subject.clone());
                changed = true;
            } else {
                active.subject = ActiveValue::Unchanged(existing_model.subject.clone());
            }

            if existing_model.sender != link.sender {
                active.sender = Set(link.sender.clone());
                changed = true;
            } else {
                active.sender = ActiveValue::Unchanged(existing_model.sender.clone());
            }

            if existing_model.sent_date != sent_date {
                active.sent_date = Set(sent_date.clone());
                changed = true;
            } else {
                active.sent_date = ActiveValue::Unchanged(existing_model.sent_date.clone());
            }

            if existing_model.created_at != created_at {
                active.created_at = Set(created_at.clone());
                changed = true;
            } else {
                active.created_at = ActiveValue::Unchanged(existing_model.created_at.clone());
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

        email_links::ActiveModel {
            id: ActiveValue::NotSet,
            task_id: Set(task_model.db_id),
            uuid: Set(link.uuid.to_string()),
            message_id: Set(link.message_id.clone()),
            subject: Set(link.subject.clone()),
            sender: Set(link.sender.clone()),
            sent_date: Set(sent_date),
            created_at: Set(created_at),
        }
        .save(db)
        .await?;
    }
    Ok(())
}
