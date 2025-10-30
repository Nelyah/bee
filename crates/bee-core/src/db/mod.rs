mod tables;

use crate::{
    filters::Filter,
    task::{Link, LinkType, Project, Task, TaskAnnotation, TaskHistory},
};
use migration::{sea_orm::Database, Migrator, MigratorTrait};
use tables::{annotations, history, links, projects, tags, tasks, tasks_tags};

use log::debug;
use uuid::Uuid;

use sea_orm::{
    ActiveModelTrait,
    ActiveValue::{self, Set},
    ColumnTrait, Condition, ConnectionTrait, DatabaseConnection, DatabaseTransaction, DbErr,
    EntityTrait, IntoActiveModel, QueryFilter, TransactionTrait,
};
use std::collections::{HashMap, HashSet};

async fn get_database(
    db_address: Option<&str>,
) -> Result<DatabaseConnection, Box<dyn std::error::Error>> {
    let db = Database::connect(db_address.unwrap_or("sqlite://db.sqlite?mode=rwc"))
        .await
        .unwrap();

    Migrator::up(&db, None).await?;

    Ok(db)
}

// TODO: 'Load' function to get tasks from DB
// This will require being able to construct the query using filters implementation
// I will probably need to make the filters pub(crate) to access their fields here
//  AndFilter,
//  OrFilter,
//  RootFilter,
//  ProjectFilter,
//  StatusFilter,
//  DateEndFilter,
//  DateCreatedFilter,
//  DateDueFilter,
//  StringFilter,
//  TagFilter,
//  TaskIdFilter,
//  DependsOnFilter,
//  UuidFilter,
//  XorFilter

// TODO: Once the Load function is done, I can make tests and checks that things in the DB
// are correctly being added

pub async fn load_tasks(_filter: &Box<dyn Filter>) -> Result<(), Box<dyn std::error::Error>> {
    Ok(())
}

pub async fn insert_tasks(tasks: &[Task]) -> Result<(), Box<dyn std::error::Error>> {
    let db = get_database(None).await.unwrap();
    for task in tasks.iter() {
        insert_task_impl(&db, task).await?;
    }
    Ok(())
}

pub async fn insert_task(task: &Task) -> Result<(), Box<dyn std::error::Error>> {
    let db = get_database(None).await.unwrap();
    insert_task_impl(&db, task).await
}

async fn insert_task_impl(
    db: &DatabaseConnection,
    task: &Task,
) -> Result<(), Box<dyn std::error::Error>> {
    debug!("Enter in insert_task_impl");
    let txn = db.begin().await?;
    let project_id = persist_project(&txn, task.project.as_ref()).await?;
    let model_task_active = task_to_active_model(&txn, task, project_id).await?;
    let model_task = insert_or_update_task(&txn, &model_task_active).await?;

    sync_annotations(&txn, &model_task, &task.annotations).await?;
    sync_history(&txn, &model_task, &task.history).await?;
    sync_links(&txn, &model_task, &task.links).await?;
    sync_tags(&txn, &model_task, &task.tags).await?;

    txn.commit().await?;
    Ok(())
}

async fn insert_or_update_task(
    db: &DatabaseTransaction,
    task_model_active: &tasks::ActiveModel,
) -> Result<tasks::Model, DbErr> {
    debug!("Enter insert_or_update_task");
    let db_id_option: Option<i32> = match &task_model_active.db_id {
        sea_orm::ActiveValue::Set(val) | sea_orm::ActiveValue::Unchanged(val) => Some(*val),
        ActiveValue::NotSet => None,
    };

    if let Some(db_id) = db_id_option {
        if let Ok(Some(_)) = tables::tasks::Entity::find_by_id(db_id).one(db).await {
            debug!("We are updating the task entry with db_id={}", db_id);
            return task_model_active.clone().update(db).await;
        }
    }
    task_model_active.clone().insert(db).await
}

async fn persist_project(
    txn: &DatabaseTransaction,
    project: Option<&Project>,
) -> Result<Option<i32>, DbErr> {
    if let Some(project_obj) = project {
        let project_active = project_to_active_model(txn, project_obj).await?;
        let saved = project_active.save(txn).await?;
        Ok(Some(saved.id.unwrap()))
    } else {
        Ok(None)
    }
}

async fn sync_annotations(
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
        if let Some(id) = ann.id {
            if let Some(existing_model) = existing_map.get(&id) {
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

async fn sync_history(
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

    let desired_ids: HashSet<i32> = desired_history
        .iter()
        .filter_map(|evt| evt.id)
        .collect();

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
        if let Some(id) = evt.id {
            if let Some(existing_model) = existing_map.get(&id) {
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
        }

        history::ActiveModel {
            id: ActiveValue::NotSet,
            value: Set(evt.value.clone()),
            datetime: Set(datetime.clone()),
            task_id: Set(task_model.db_id),
            ..Default::default()
        }
        .save(db)
        .await?;
    }
    Ok(())
}

async fn sync_links(
    db: &DatabaseTransaction,
    task_model: &tasks::Model,
    desired_links: &[Link],
) -> Result<(), DbErr> {
    let existing_rows: Vec<links::Model> = links::Entity::find()
        .filter(
            Condition::any()
                .add(links::Column::FromTaskId.eq(task_model.db_id))
                .add(links::Column::ToTaskId.eq(task_model.db_id)),
        )
        .all(db)
        .await?;

    let mut existing_map: HashMap<i32, links::Model> = HashMap::new();
    let mut existing_ids = Vec::new();
    for row in existing_rows {
        existing_ids.push(row.id);
        existing_map.insert(row.id, row);
    }

    let desired_ids: HashSet<i32> = desired_links
        .iter()
        .filter_map(|link| link.id)
        .collect();

    let to_delete: Vec<i32> = existing_ids
        .into_iter()
        .filter(|id| !desired_ids.contains(id))
        .collect();
    if !to_delete.is_empty() {
        links::Entity::delete_many()
            .filter(links::Column::Id.is_in(to_delete))
            .exec(db)
            .await?;
    }

    let mut target_cache: HashMap<Uuid, Option<i32>> = HashMap::new();
    for link in desired_links {
        target_cache
            .entry(link.to)
            .or_insert(resolve_uuid_to_db_id(db, link.to).await?);
    }

    for link in desired_links {
        let to_db_id = target_cache
            .get(&link.to)
            .and_then(|id| *id)
            .ok_or_else(|| DbErr::RecordNotFound(format!("Unknown target {}", link.to)))?;

        if let Some(id) = link.id {
            if let Some(existing_model) = existing_map.get(&id) {
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

                let link_type_string = match link.link_type {
                    LinkType::DependsOn => "DependsOn".to_owned(),
                    LinkType::Blocking => "Blocking".to_owned(),
                };
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
        }

        links::ActiveModel {
            id: ActiveValue::NotSet,
            from_task_id: Set(task_model.db_id),
            to_task_id: Set(to_db_id),
            r#type: Set(match link.link_type {
                LinkType::DependsOn => "DependsOn".to_owned(),
                LinkType::Blocking => "Blocking".to_owned(),
            }),
        }
        .save(db)
        .await?;
    }
    Ok(())
}

async fn sync_tags(
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
            None => tags::ActiveModel {
                id: ActiveValue::NotSet,
                name: Set(tag_name.clone()),
            }
            .insert(db)
            .await?,
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

/// A structure to group all ActiveModels corresponding to a Task.
pub struct TaskActiveModels {
    pub task: tables::tasks::ActiveModel,
    pub project: Option<projects::ActiveModel>,
    pub annotations: Vec<annotations::ActiveModel>,
    pub history: Vec<history::ActiveModel>,
    pub links: Vec<links::ActiveModel>,
    pub tags: Vec<tags::ActiveModel>,
}

// Macro to diff fields into an ActiveModel
macro_rules! diff_active_model {
    ($am:ident, $old:ident, $new:ident, { $($field:ident),+ $(,)? }) => {
        $(
            if $old.$field != $new.$field {
                $am.$field = Set($new.$field.clone());
            }
        )+
    };
}

pub async fn project_to_active_model<C>(
    db: &C,
    project_obj: &Project,
) -> Result<projects::ActiveModel, DbErr>
where
    C: ConnectionTrait,
{
    // 1. Fetch existing Model if we have an ID
    let project_model: Option<projects::Model> = projects::Entity::find()
        .filter(projects::Column::Name.eq(&project_obj.name))
        .one(db)
        .await?;

    // 2. Start from existing.into_active_model() or default
    let mut project_active = project_model
        .clone()
        .map(|m| m.into_active_model())
        .unwrap_or_default();

    // 3. Ensure PK is set for update (leaving it NotSet for insert)
    if let Some(id) = project_obj.id {
        project_active.id = Set(id);
    }

    // 4. Diff the `name` field if updating, or set it on insert
    if let Some(old) = &project_model {
        diff_active_model!(project_active, old, project_obj, { name });
    } else {
        project_active.name = Set(project_obj.name.clone());
    }

    debug!("End of project_to_active_model {:?}", project_active);
    Ok(project_active)
}

async fn task_to_active_model<C>(
    db: &C,
    task_obj: &Task,
    project_dbid_option: Option<i32>,
) -> Result<tasks::ActiveModel, Box<dyn std::error::Error>>
where
    C: ConnectionTrait,
{
    let status_str = task_obj.status.to_string().to_uppercase();

    let existing_db_task = tasks::Entity::find()
        .filter(tasks::Column::Uuid.eq(task_obj.uuid.to_string()))
        .one(db)
        .await?;



    let mut task_active = tasks::ActiveModel {
        db_id: match task_obj.db_id {
            Some(id) => ActiveValue::Set(id),
            None => ActiveValue::NotSet,
        },
        id: ActiveValue::Set(task_obj.id),
        status: ActiveValue::Set(status_str.clone()),
        uuid: ActiveValue::Set(task_obj.uuid.to_string()),
        summary: ActiveValue::Set(task_obj.summary.clone()),
        date_created: ActiveValue::Set(task_obj.date_created.to_rfc3339()),
        date_completed: match task_obj.date_completed {
            Some(dt) => ActiveValue::Set(Some(dt.to_rfc3339())),
            None => ActiveValue::Set(None),
        },
        date_due: match task_obj.date_due {
            Some(dt) => ActiveValue::Set(Some(dt.to_rfc3339())),
            None => ActiveValue::Set(None),
        },
        urgency: match task_obj.urgency {
            Some(u) => ActiveValue::Set(Some(u as f64)),
            None => ActiveValue::Set(None),
        },
        project_id: match project_dbid_option {
            Some(pid) => ActiveValue::Set(Some(pid)),
            None => ActiveValue::Set(None),
        },
        ..Default::default()
    };

    if let Some(db_id) = &task_obj.db_id {
        if let Ok(Some(existing)) = tables::tasks::Entity::find_by_id(db_id.clone())
            .one(db)
            .await
        {
            if existing.id == task_obj.id {
                task_active.id = ActiveValue::Unchanged(existing.id);
            }
            if existing.status.to_uppercase() == status_str {
                task_active.status = ActiveValue::Unchanged(existing.status);
            }
            if existing.uuid == task_obj.uuid.to_string() {
                task_active.uuid = ActiveValue::Unchanged(existing.uuid);
            }
            if existing.summary == task_obj.summary {
                task_active.summary = ActiveValue::Unchanged(existing.summary);
            }
            if existing.date_created == task_obj.date_created.to_rfc3339() {
                task_active.date_created = ActiveValue::Unchanged(existing.date_created);
            }
            if existing.date_completed == task_obj.date_completed.map(|dt| dt.to_rfc3339()) {
                task_active.date_completed = ActiveValue::Unchanged(existing.date_completed);
            }
            if existing.date_due == task_obj.date_due.map(|dt| dt.to_rfc3339()) {
                task_active.date_due = ActiveValue::Unchanged(existing.date_due);
            }
            if existing.urgency == task_obj.urgency.map(|u| u as f64) {
                task_active.urgency = ActiveValue::Unchanged(existing.urgency);
            }
        }
    }

    if let Some(existing) = existing_db_task {
        task_active.db_id = ActiveValue::Set(existing.db_id);
        // Preserve existing user-visible id if task.id is None (so we don't null it unintentionally)
        if task_obj.id.is_none() && existing.id.is_some() {
            task_active.id = ActiveValue::Set(existing.id);
        }
    }

    Ok(task_active)
}

async fn annotations_to_active_model(
    db: &DatabaseConnection,
    annotations: &Vec<TaskAnnotation>,
    task_id: &ActiveValue<i32>,
) -> Result<Vec<annotations::ActiveModel>, DbErr> {
    let mut annotations_active: Vec<annotations::ActiveModel> = vec![];

    for ann in annotations {
        let model: Option<tables::annotations::Model> = if let Some(id) = ann.id {
            annotations::Entity::find_by_id(id).one(db).await?
        } else {
            None
        };

        let mut model_active = match model.clone() {
            Some(model) => model.into_active_model(),
            None => <annotations::ActiveModel as sea_orm::ActiveModelTrait>::default(),
        };

        match model {
            Some(m) => {
                // Existing annotation: diff fields
                if m.value == ann.value {
                    model_active.value = ActiveValue::Unchanged(m.value.clone());
                } else {
                    model_active.value = Set(ann.value.clone());
                }
                let ann_dt = ann.time.to_rfc3339();
                if m.datetime == ann_dt {
                    model_active.datetime = ActiveValue::Unchanged(m.datetime.clone());
                } else {
                    model_active.datetime = Set(ann_dt);
                }
                // Always ensure task_id (FK) is set (or unchanged if same)
                model_active.task_id = task_id.clone();
            }
            None => {
                // New annotation: set all required fields
                model_active.value = Set(ann.value.clone());
                model_active.datetime = Set(ann.time.to_rfc3339());
                model_active.task_id = task_id.clone();
            }
        }
        annotations_active.push(model_active);
    }
    Ok(annotations_active)
}

async fn links_to_active_model(
    db: &DatabaseConnection,
    links: &Vec<Link>,
    task_id: &ActiveValue<i32>,
) -> Result<Vec<links::ActiveModel>, DbErr> {
    let mut links_active: Vec<links::ActiveModel> = Vec::new();

    // Batch resolve target UUIDs (best effort – still sequential today, but cached).
    use std::collections::HashMap as StdHashMap;
    let mut target_uuid_map: StdHashMap<Uuid, Option<i32>> = StdHashMap::new();
    for l in links {
        target_uuid_map
            .entry(l.to)
            .or_insert(resolve_uuid_to_db_id(db, l.to).await?);
    }

    for link in links {
        let existing_model = if let Some(id) = link.id {
            links::Entity::find_by_id(id).one(db).await?
        } else {
            None
        };

        let to_db_id = target_uuid_map
            .get(&link.to)
            .and_then(|x| *x)
            .ok_or_else(|| {
                DbErr::RecordNotFound(format!("Link target uuid {} not found", link.to))
            })?;

        // Start from existing ActiveModel (diff) or default (insert)
        let mut am = existing_model
            .clone()
            .map(|m| m.into_active_model())
            .unwrap_or_default();

        // id: unchanged if existing, otherwise NotSet
        am.id = match existing_model {
            Some(ref m) => ActiveValue::Unchanged(m.id),
            None => ActiveValue::NotSet,
        };

        // from_task_id always points to the source task
        am.from_task_id = task_id.clone();

        // to_task_id diff
        if let Some(ref m) = existing_model {
            if m.to_task_id == to_db_id {
                am.to_task_id = ActiveValue::Unchanged(m.to_task_id);
            } else {
                am.to_task_id = Set(to_db_id);
            }
        } else {
            am.to_task_id = Set(to_db_id);
        }

        // type diff
        let link_type_string = match link.link_type {
            LinkType::DependsOn => "DependsOn".to_owned(),
            LinkType::Blocking => "Blocking".to_owned(),
        };
        if let Some(ref m) = existing_model {
            if m.r#type == link_type_string {
                am.r#type = ActiveValue::Unchanged(m.r#type.clone());
            } else {
                am.r#type = Set(link_type_string);
            }
        } else {
            am.r#type = Set(link_type_string);
        }

        links_active.push(am);
    }

    Ok(links_active)
}

async fn history_to_active_model(
    db: &DatabaseConnection,
    history_events: &Vec<TaskHistory>,
    task_id: &ActiveValue<i32>,
) -> Result<Vec<history::ActiveModel>, DbErr> {
    let mut history_events_active: Vec<history::ActiveModel> = vec![];

    for event in history_events {
        if let Some(id) = event.id {
            // Existing event: fetch and diff
            let existing_opt = history::Entity::find_by_id(id).one(db).await?;
            if let Some(existing_model) = existing_opt {
                // Clone so we can still access fields after into_active_model consumes the value
                let mut event_active = existing_model.clone().into_active_model();

                // Diff value
                if existing_model.value == event.value {
                    event_active.value = ActiveValue::Unchanged(existing_model.value.clone());
                } else {
                    event_active.value = Set(event.value.clone());
                }

                // Diff datetime
                let event_dt = event.datetime.to_rfc3339();
                if existing_model.datetime == event_dt {
                    event_active.datetime = ActiveValue::Unchanged(existing_model.datetime.clone());
                } else {
                    event_active.datetime = Set(event_dt);
                }

                // Ensure FK
                event_active.task_id = task_id.clone();
                history_events_active.push(event_active);
            } else {
                // ID provided but not found; treat as new insert (avoid panic)
                history_events_active.push(history::ActiveModel {
                    id: ActiveValue::NotSet,
                    value: Set(event.value.clone()),
                    datetime: Set(event.datetime.to_rfc3339()),
                    task_id: task_id.clone(),
                    ..Default::default()
                });
            }
        } else {
            // New event
            history_events_active.push(history::ActiveModel {
                id: ActiveValue::NotSet,
                value: Set(event.value.clone()),
                datetime: Set(event.datetime.to_rfc3339()),
                task_id: task_id.clone(),
                ..Default::default()
            });
        }
    }
    Ok(history_events_active)
}

/// Placeholder function for converting a Uuid to the corresponding database id.
async fn resolve_uuid_to_db_id<C>(
    db: &C,
    id: Uuid,
) -> Result<Option<i32>, DbErr>
where
    C: ConnectionTrait,
{
    let task = tasks::Entity::find()
        .filter(tasks::Column::Uuid.eq(id.to_string()))
        .one(db)
        .await?;

    Ok(task.map(|model| model.db_id))
}

#[cfg(test)]
mod tests {
    use super::*;
    use all_asserts::{assert_false, assert_true};
    // Import the function and domain types
    use chrono::Utc;
    use sea_orm::{ActiveValue, Database, DatabaseConnection};

    #[tokio::test]
    async fn test_annotations_to_active_model_new_annotation() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        // Create a TaskAnnotation with no id (new record).
        let ann = TaskAnnotation {
            id: None,
            value: "Test annotation".to_owned(),
            time: Utc::now().into(),
        };
        let task_id = ActiveValue::Set(1);
        let active_models = annotations_to_active_model(&db, &vec![ann.clone()], &task_id)
            .await
            .unwrap();
        assert_eq!(active_models.len(), 1);
        let active = &active_models[0];

        // Check that the active model fields are Set with the expected values.
        if let ActiveValue::Set(ref val) = active.value {
            assert_eq!(val, &ann.value);
        } else {
            assert!(false, "Expected value to be Set");
        }
        if let ActiveValue::Set(ref dt) = active.datetime {
            assert_eq!(dt, &ann.time.to_rfc3339());
        } else {
            assert!(false, "Expected datetime to be Set");
        }
        // task_id should be set to 1.
        if let ActiveValue::Set(ref tid) = active.task_id {
            assert_eq!(*tid, 1);
        } else {
            assert!(false, "Expected task_id to be Set");
        }

        // TODO: Test making annotation model when we update the model
    }

    // TODO: Add test to insert a task
    #[tokio::test]
    async fn test_insert_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        // 1. Create an in-memory task and save its UUID
        let mut t = Task::default();
        let saved_uuid = t.uuid; // UUID auto-generated in default impl

        // 2. First insert
        insert_task_impl(&db, &t).await.unwrap();

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
        assert!(annotations_before.is_empty(), "Expected no annotations after first insert");

        // 4. Add annotation to in-memory task (value + current time)
        t.annotations.push(TaskAnnotation {
            id: None,
            value: "Test annotation".to_string(),
            time: chrono::Local::now(),
        });

        // 5. Re-insert (should update existing row by UUID, not duplicate)
        insert_task_impl(&db, &t).await.unwrap();

        // Fetch task again to ensure we are still referencing same db_id
        let updated_db_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(saved_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should still exist after update");
        assert_eq!(initial_db_task.db_id, updated_db_task.db_id, "Task update should not create a new row");

        let annotations_after = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(updated_db_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(!annotations_after.is_empty(), "Expected at least one annotation row after update");
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

        insert_task_impl(&db, &task).await.unwrap();

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
        assert_eq!(annotations_before.len(), 1, "Expected one annotation after initial insert");

        task.annotations.clear();
        insert_task_impl(&db, &task).await.unwrap();

        let annotations_after = annotations::Entity::find()
            .filter(annotations::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(annotations_after.is_empty(), "Annotation should be removed after sync with empty annotations");
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

        insert_task_impl(&db, &task).await.unwrap();

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
        assert_eq!(history_before.len(), 1, "Expected one history event after initial insert");

        task.history.clear();
        insert_task_impl(&db, &task).await.unwrap();

        let history_after = history::Entity::find()
            .filter(history::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(history_after.is_empty(), "History should be removed after sync with empty events");
    }

    #[tokio::test]
    async fn test_links_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut target_task = Task::default();
        let target_uuid = target_task.uuid;
        insert_task_impl(&db, &target_task).await.unwrap();

        let mut source_task = Task::default();
        let source_uuid = source_task.uuid;
        source_task.links.push(Link {
            id: None,
            from: source_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });

        insert_task_impl(&db, &source_task).await.unwrap();

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
        assert_eq!(links_before.len(), 1, "Expected one link after initial insert");

        source_task.links.clear();
        insert_task_impl(&db, &source_task).await.unwrap();

        let links_after = links::Entity::find()
            .filter(links::Column::FromTaskId.eq(persisted_source.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(links_after.is_empty(), "Links should be removed after sync with empty collection");
    }

    #[tokio::test]
    async fn test_project_cleared_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        let project_name = "sync-project".to_string();
        task.project = Some(Project {
            id: None,
            name: project_name.clone(),
        });

        insert_task_impl(&db, &task).await.unwrap();

        let persisted_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should exist after insert");
        assert!(persisted_task.project_id.is_some(), "Project should be set after initial insert");

        task.project = None;
        insert_task_impl(&db, &task).await.unwrap();

        let updated_task = tasks::Entity::find()
            .filter(tasks::Column::Uuid.eq(task_uuid.to_string()))
            .one(&db)
            .await
            .unwrap()
            .expect("Task should still exist after project removal");
        assert!(updated_task.project_id.is_none(), "Project should be cleared after sync with None");
    }

    #[tokio::test]
    async fn test_tags_removed_after_sync() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut task = Task::default();
        let task_uuid = task.uuid;
        task.tags.push("alpha".to_string());

        insert_task_impl(&db, &task).await.unwrap();

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
        assert_eq!(tags_before.len(), 1, "Expected one task-tag link after initial insert");

        task.tags.clear();
        insert_task_impl(&db, &task).await.unwrap();

        let tags_after = tasks_tags::Entity::find()
            .filter(tasks_tags::Column::TaskId.eq(persisted_task.db_id))
            .all(&db)
            .await
            .unwrap();
        assert!(tags_after.is_empty(), "Task-tag links should be removed after sync with empty tags");
    }

    #[tokio::test]
    async fn test_annotations_to_active_model_update_diff_logic() {
        use chrono::Local;
        use sea_orm::{ActiveModelTrait, EntityTrait};

        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        // Insert a minimal task row
        let uuid = Uuid::new_v4();
        let task_model = tasks::ActiveModel {
            status: ActiveValue::Set("PENDING".to_string()),
            uuid: ActiveValue::Set(uuid.to_string()),
            summary: ActiveValue::Set("Summary".to_string()),
            date_created: ActiveValue::Set(Local::now().to_rfc3339()),
            ..Default::default()
        }
        .insert(&db)
        .await
        .unwrap();

        // Create a new annotation (no id)
        let ann_time = Local::now();
        let ann = TaskAnnotation {
            id: None,
            value: "Initial".to_string(),
            time: ann_time,
        };
        let active_vec = annotations_to_active_model(&db, &vec![ann.clone()], &ActiveValue::Set(task_model.db_id))
            .await
            .unwrap();
        assert_eq!(active_vec.len(), 1);
        // Persist it
        let saved_ann = active_vec[0].clone().insert(&db).await.unwrap();

        // Unchanged update
        let ann_unchanged = TaskAnnotation {
            id: Some(saved_ann.id),
            value: saved_ann.value.clone(),
            time: chrono::DateTime::parse_from_rfc3339(&saved_ann.datetime)
                .unwrap()
                .with_timezone(&Local),
        };
        let update_vec = annotations_to_active_model(&db, &vec![ann_unchanged], &ActiveValue::Set(task_model.db_id))
            .await
            .unwrap();
        if let ActiveValue::Unchanged(_) = update_vec[0].value {
        } else {
            assert!(false, "Value field should be Unchanged for identical annotation");
        }
        if let ActiveValue::Unchanged(_) = update_vec[0].datetime {
        } else {
            assert!(false, "Datetime field should be Unchanged for identical annotation");
        }

        // Changed value only
        let ann_changed = TaskAnnotation {
            id: Some(saved_ann.id),
            value: "Modified".to_string(),
            time: chrono::DateTime::parse_from_rfc3339(&saved_ann.datetime)
                .unwrap()
                .with_timezone(&Local),
        };
        let changed_vec = annotations_to_active_model(&db, &vec![ann_changed], &ActiveValue::Set(task_model.db_id))
            .await
            .unwrap();
        if let ActiveValue::Set(ref v) = changed_vec[0].value {
            assert_eq!(v, "Modified");
        } else {
            assert!(false, "Value field should be Set for modified annotation");
        }
        if let ActiveValue::Unchanged(_) = changed_vec[0].datetime {
        } else {
            assert!(false, "Datetime field should remain Unchanged when only value changes");
        }
    }

    #[tokio::test]
    async fn test_history_to_active_model_update_diff_logic() {
        use chrono::Local;
        use sea_orm::{ActiveModelTrait, EntityTrait};

        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        // Insert task
        let uuid = Uuid::new_v4();
        let task_model = tasks::ActiveModel {
            status: ActiveValue::Set("PENDING".to_string()),
            uuid: ActiveValue::Set(uuid.to_string()),
            summary: ActiveValue::Set("Summary".to_string()),
            date_created: ActiveValue::Set(Local::now().to_rfc3339()),
            ..Default::default()
        }
        .insert(&db)
        .await
        .unwrap();

        // New history event
        let evt_time = Local::now();
        let evt = TaskHistory {
            id: None,
            value: "Created".to_string(),
            datetime: evt_time,
        };
        let history_vec = history_to_active_model(&db, &vec![evt.clone()], &ActiveValue::Set(task_model.db_id))
            .await
            .unwrap();
        assert_eq!(history_vec.len(), 1);
        // New row should have NotSet id
        if let ActiveValue::NotSet = history_vec[0].id {
        } else {
            assert!(false, "New history event id should be NotSet");
        }
        // Persist
        let saved_evt = history_vec[0].clone().insert(&db).await.unwrap();

        // Unchanged event
        let evt_unchanged = TaskHistory {
            id: Some(saved_evt.id),
            value: saved_evt.value.clone(),
            datetime: chrono::DateTime::parse_from_rfc3339(&saved_evt.datetime)
                .unwrap()
                .with_timezone(&Local),
        };
        let unchanged_vec = history_to_active_model(&db, &vec![evt_unchanged], &ActiveValue::Set(task_model.db_id))
            .await
            .unwrap();
        if let ActiveValue::Unchanged(_) = unchanged_vec[0].value {
        } else {
            assert!(false, "History value should be Unchanged for identical update");
        }
        if let ActiveValue::Unchanged(_) = unchanged_vec[0].datetime {
        } else {
            assert!(false, "History datetime should be Unchanged for identical update");
        }
    }

    // #[tokio::test]
    // async fn test_annotations_to_active_model_existing_annotation() {
    //     let db = get_database(Some("sqlite::memory:")).await;
    //     let now = Utc::now();
    //     // First, insert an annotation into the DB.
    //     let insert_result = sqlx::query(
    //         r#"
    //         INSERT INTO annotations (value, datetime, task_id)
    //         VALUES (?, ?, ?)
    //         "#,
    //     )
    //     .bind("Existing annotation")
    //     .bind(now.to_rfc3339())
    //     .bind(1)
    //     .execute(db.as_ref())
    //     .await
    //     .unwrap();
    //     let inserted_id = insert_result.last_insert_rowid() as i32;

    //     // Create a TaskAnnotation with the same values as the inserted record.
    //     let ann = TaskAnnotation {
    //         id: Some(inserted_id),
    //         value: "Existing annotation".to_owned(),
    //         time: now,
    //     };
    //     let task_id = ActiveValue::Set(1);
    //     let active_models = annotations_to_active_model(&db, &vec![ann.clone()], &task_id).await;
    //     assert_eq!(active_models.len(), 1);
    //     let active = &active_models[0];

    //     // Because the values match the existing DB record, the function should mark them as Unchanged.
    //     match active.value {
    //         ActiveValue::Unchanged(ref existing_val) => {
    //             // Here we expect the value to remain as the same (should be "Existing annotation").
    //             assert_eq!(existing_val, "Existing annotation");
    //         }
    //         _ => panic!("Expected value to be Unchanged"),
    //     }
    //     match active.datetime {
    //         ActiveValue::Unchanged(ref existing_dt) => {
    //             assert_eq!(existing_dt, &now.to_rfc3339());
    //         }
    //         _ => panic!("Expected datetime to be Unchanged"),
    //     }
    // }
}
