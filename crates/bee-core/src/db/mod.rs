use log::debug;
use migration::{Migrator, MigratorTrait, sea_orm::Database}; // This is the module created by sea-orm-cli
mod tables;

use sea_orm::*;

pub async fn run_migration() -> Result<(), Box<dyn std::error::Error>> {
    let db = Database::connect("sqlite://db.sqlite?mode=rwc")
        .await
        .unwrap();

    // Run all unapplied migrations automatically
    let _ = Migrator::up(&db, None).await;

    let t = Task {
        db_id: Some(1),
        id: None,
        status: TaskStatus::Completed, // Use an appropriate variant
        uuid: Uuid::new_v4(),
        summary: "Initial summary".to_string(),
        tags: vec!["initial_tag1".to_string(), "initial_tag2".to_string()],
        date_created: chrono::Local::now(),
        project: None,
        ..Task::default()
    };

    delete_projects(&db).await;
    delete_annotations(&db, &t).await;
    delete_history_events(&db, &t).await;
    delete_links(&db, &t).await;
    delete_tasks_tags(&db, &t).await;
    delete_tags(&db).await;

    let model_project = if let Some(task_proj) = &t.project {
        Some(insert_or_update_project(&db, project_to_active_model(&db, &task_proj).await).await)
    } else {
        debug!("Proj model is None");
        None
    };

    let model_task_active = task_to_active_model(
        &db,
        &t,
        match model_project {
            Some(model) => Some(model.id),
            None => None,
        },
    )
    .await;
    let model_task = insert_or_update_task(&db, &model_task_active).await;

    insert_or_update_annotations(
        &db,
        annotations_to_active_model(&db, &t.annotations, &ActiveValue::Set(model_task.db_id)).await,
    )
    .await;

    insert_or_update_links(
        &db,
        links_to_active_model(&db, &t.links, &ActiveValue::Set(model_task.db_id)).await,
    )
    .await;

    insert_or_update_history(
        &db,
        history_to_active_model(&db, &t.history, &ActiveValue::Set(model_task.db_id)).await,
    )
    .await;

    insert_or_update_tags(&db, &t.tags).await;
    insert_or_update_tasks_tags(&db, &model_task.db_id, &t.tags).await;
    debug!("hey {:?}", model_task);

    Ok(())
}

async fn delete_annotations(db: &DatabaseConnection, task_obj: &Task) {
    if task_obj.db_id.is_none() {
        return;
    }
    let task_id = task_obj.db_id.unwrap();
    let known_ann_id: Vec<i32> = task_obj
        .annotations
        .iter()
        .filter(|&ann| ann.id.is_some())
        .map(|ann| ann.id.unwrap())
        .collect();

    let _ = tables::annotations::Entity::delete_many()
        .filter(
            Condition::all()
                .add(tables::annotations::Column::TaskId.eq(task_id))
                .add(tables::annotations::Column::Id.is_not_in(known_ann_id)),
        )
        .exec(db)
        .await;
}

async fn delete_links(db: &DatabaseConnection, task_obj: &Task) {
    if task_obj.db_id.is_none() {
        return;
    }
    let task_id = task_obj.db_id.unwrap();
    let known_link_ids: Vec<i32> = task_obj
        .links
        .iter()
        .filter(|&event| event.id.is_some())
        .map(|event| event.id.unwrap())
        .collect();

    let _ = tables::links::Entity::delete_many()
        .filter(
            Condition::all()
                .add(
                    Condition::any()
                        .add(tables::links::Column::FromTaskId.eq(task_id))
                        .add(tables::links::Column::ToTaskId.eq(task_id)),
                )
                .add(tables::links::Column::Id.is_not_in(known_link_ids)),
        )
        .exec(db)
        .await;
}

async fn delete_tags(db: &DatabaseConnection) {
    let tags_used_query = tables::tasks_tags::Entity::find()
        .select_only()
        .column(tables::tasks_tags::Column::TagId)
        .distinct()
        .into_query();

    let _ = tags::Entity::delete_many()
        .filter(tables::tags::Column::Id.not_in_subquery(tags_used_query))
        .exec(db)
        .await;
}

async fn delete_tasks_tags(db: &DatabaseConnection, task_obj: &Task) {
    if task_obj.db_id.is_none() {
        return;
    }
    let task_id = task_obj.db_id.unwrap();
    let subquery = tables::tags::Entity::find()
        .select_only()
        .column(tables::tags::Column::Id)
        .filter(tables::tags::Column::Name.is_not_in(&task_obj.tags))
        .into_query();

    let _ = tasks_tags::Entity::delete_many()
        .filter(
            Condition::all()
                .add(tables::tasks_tags::Column::TaskId.eq(task_id))
                .add(tables::tasks_tags::Column::TagId.in_subquery(subquery)),
        )
        .exec(db)
        .await;
}

async fn delete_history_events(db: &DatabaseConnection, task_obj: &Task) {
    if task_obj.db_id.is_none() {
        return;
    }
    let task_id = task_obj.db_id.unwrap();
    let known_history_id: Vec<i32> = task_obj
        .history
        .iter()
        .filter(|&event| event.id.is_some())
        .map(|event| event.id.unwrap())
        .collect();

    let _ = tables::history::Entity::delete_many()
        .filter(
            Condition::all()
                .add(tables::history::Column::TaskId.eq(task_id))
                .add(tables::history::Column::Id.is_not_in(known_history_id)),
        )
        .exec(db)
        .await;
}

async fn delete_projects(db: &DatabaseConnection) {
    let used_project_ids_query = tables::tasks::Entity::find()
        .select_only()
        .column(tables::tasks::Column::ProjectId)
        .filter(tables::tasks::Column::ProjectId.is_not_null())
        .distinct()
        .into_query();

    let _ = tables::projects::Entity::delete_many()
        .filter(tables::projects::Column::Id.not_in_subquery(used_project_ids_query))
        .exec(db)
        .await;
}

async fn insert_or_update_task(
    db: &DatabaseConnection,
    task_model_active: &tasks::ActiveModel,
) -> tables::tasks::Model {
    let db_id_option: Option<i32> = match &task_model_active.db_id {
        sea_orm::ActiveValue::Set(val) | sea_orm::ActiveValue::Unchanged(val) => Some(*val),
        ActiveValue::NotSet => None,
    };

    if let Some(db_id) = db_id_option {
        if let Ok(Some(_)) = tables::tasks::Entity::find_by_id(db_id).one(db).await {
            debug!("We are updating the task entry with {}", db_id);
            return task_model_active.clone().update(db).await.unwrap();
        }
    }
    return task_model_active.clone().insert(db).await.unwrap();
}

async fn insert_or_update_project(
    db: &DatabaseConnection,
    mut proj_model_active: projects::ActiveModel,
) -> tables::projects::Model {
    let proj_id_option: Option<i32> = match proj_model_active.id {
        sea_orm::ActiveValue::Set(val) | sea_orm::ActiveValue::Unchanged(val) => Some(val),
        ActiveValue::NotSet => None,
    };
    let proj_name = proj_model_active.name.try_as_ref().unwrap().to_string();

    if let Some(proj_id) = proj_id_option {
        if let Ok(Some(_)) = tables::projects::Entity::find_by_id(proj_id).one(db).await {
            return proj_model_active.clone().update(db).await.unwrap();
        }
        panic!("Error: Project with ID not found in database!");
    } else if let Ok(Some(model)) = tables::projects::Entity::find()
        .filter(tables::projects::Column::Name.eq(proj_name))
        .one(db)
        .await
    {
        proj_model_active.id = ActiveValue::Set(model.id.clone());
        return proj_model_active.clone().update(db).await.unwrap();
    }
    return proj_model_active.clone().insert(db).await.unwrap();
}

async fn insert_or_update_history(
    db: &DatabaseConnection,
    history_events: Vec<history::ActiveModel>,
) {
    for event in history_events {
        let event_id_option: Option<i32> = match event.id {
            sea_orm::ActiveValue::Set(val) | sea_orm::ActiveValue::Unchanged(val) => Some(val),
            ActiveValue::NotSet => None,
        };

        if let Some(event_id) = event_id_option {
            if let Ok(Some(_)) = tables::history::Entity::find_by_id(event_id).one(db).await {
                event.clone().update(db).await.unwrap();
            }
            panic!("Error: History event with ID not found in database!");
        }
        event.clone().insert(db).await.unwrap();
    }
}

async fn insert_or_update_links(db: &DatabaseConnection, links: Vec<links::ActiveModel>) {
    for link in links {
        let event_id_option: Option<i32> = match link.id {
            sea_orm::ActiveValue::Set(val) | sea_orm::ActiveValue::Unchanged(val) => Some(val),
            ActiveValue::NotSet => None,
        };

        if let Some(event_id) = event_id_option {
            if let Ok(Some(_)) = tables::links::Entity::find_by_id(event_id).one(db).await {
                link.clone().update(db).await.unwrap();
            }
            panic!("Error: Link event with ID not found in database!");
        }
        link.clone().insert(db).await.unwrap();
    }
}

async fn insert_or_update_annotations(
    db: &DatabaseConnection,
    annotations: Vec<annotations::ActiveModel>,
) {
    for annotation in annotations {
        let annotation_id_option: Option<i32> = match annotation.id {
            sea_orm::ActiveValue::Set(val) | sea_orm::ActiveValue::Unchanged(val) => Some(val),
            ActiveValue::NotSet => None,
        };

        if let Some(ann_id) = annotation_id_option {
            if let Ok(Some(_)) = tables::annotations::Entity::find_by_id(ann_id)
                .one(db)
                .await
            {
                annotation.clone().update(db).await.unwrap();
            }
            panic!("Error: Annotation with ID not found in database!");
        }
        annotation.clone().insert(db).await.unwrap();
    }
}

async fn insert_or_update_tags(db: &DatabaseConnection, tags: &Vec<String>) {
    for tag in tags {
        // let mut tag_model_active = tags::ActiveModel {
        if let Ok(Some(_)) = tags::Entity::find()
            .filter(tags::Column::Name.eq(tag))
            .one(db)
            .await
        {
        } else {
            let tag_model_active = tags::ActiveModel {
                name: ActiveValue::Set(tag.to_string()),
                ..Default::default()
            };
            tag_model_active.insert(db).await.unwrap();
        }
    }
}

async fn insert_or_update_tasks_tags(db: &DatabaseConnection, task_id: &i32, tags: &Vec<String>) {
    for tag in tags {
        // let mut tag_model_active = tags::ActiveModel {
        if let Ok(Some(tag_model)) = tags::Entity::find()
            .filter(tags::Column::Name.eq(tag))
            .one(db)
            .await
        {
            if let Ok(Some(_)) = tasks_tags::Entity::find()
                .filter(
                    Condition::all()
                        .add(tasks_tags::Column::TaskId.eq(*task_id))
                        .add(tasks_tags::Column::TagId.eq(tag_model.id)),
                )
                .one(db)
                .await
            {
            } else {
                let task_tag_active = tasks_tags::ActiveModel {
                    task_id: ActiveValue::Set(*task_id),
                    tag_id: ActiveValue::Set(tag_model.id),
                };
                task_tag_active.insert(db).await.unwrap();
            }
        } else {
            panic!("Unable to find tag with name in the DB. name={}", tag);
        }
    }
}

use sea_orm::ActiveValue::Set;
use uuid::Uuid;

// Assume these are the seaORM entity modules.
use tables::{annotations, history, links, projects, tags, tasks, tasks_tags};

use crate::task::{Link, LinkType, Project, Task, TaskAnnotation, TaskHistory, TaskStatus};

/// A structure to group all ActiveModels corresponding to a Task.
pub struct TaskActiveModels {
    pub task: tables::tasks::ActiveModel,
    pub project: Option<projects::ActiveModel>,
    pub annotations: Vec<annotations::ActiveModel>,
    pub history: Vec<history::ActiveModel>,
    pub links: Vec<links::ActiveModel>,
    pub tags: Vec<tags::ActiveModel>,
}

/// Converts a Task into all its corresponding seaORM ActiveModels.

async fn project_to_active_model(
    db: &DatabaseConnection,
    project_obj: &Project,
) -> projects::ActiveModel {
    // Build the ActiveModel for the project.
    let mut project_active = projects::ActiveModel {
        // Set the name from the project.
        name: ActiveValue::Set(project_obj.name.clone()),
        ..Default::default()
    };

    // If an id is present, fetch the existing record from the DB to compare fields.
    if let Some(id) = project_obj.id {
        if let Ok(Some(existing)) = projects::Entity::find_by_id(id).one(db).await {
            // If the name hasn't changed, mark it as Unchanged.
            if existing.name == project_obj.name {
                project_active.name = ActiveValue::Unchanged(existing.name);
            }
        }
    }

    project_active
}

async fn task_to_active_model(
    db: &DatabaseConnection,
    task_obj: &Task,
    project_dbid_option: Option<i32>,
) -> tasks::ActiveModel {
    let status_str = task_obj.status.to_string().to_uppercase();

        debug!("Proj model now is {:?}", project_dbid_option);

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
        debug!("Proj model after is {:?}", task_active.project_id);
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

    task_active
}

async fn annotations_to_active_model(
    db: &DatabaseConnection,
    annotations: &Vec<TaskAnnotation>,
    task_id: &ActiveValue<i32>,
) -> Vec<annotations::ActiveModel> {
    let mut annotations_active: Vec<annotations::ActiveModel> = vec![];

    for ann in annotations {
        let mut ann_active = annotations::ActiveModel {
            id: Set(ann.id.unwrap_or_default()),
            value: Set(ann.value.clone()),
            datetime: Set(ann.time.to_rfc3339()),
            // The annotations table references the task’s db_id.
            task_id: task_id.to_owned(),
            ..Default::default()
        };
        if let Some(id) = ann.id {
            if let Ok(Some(existing)) = annotations::Entity::find_by_id(id).one(db).await {
                if existing.value == ann.value {
                    ann_active.value = ActiveValue::Unchanged(existing.datetime.clone());
                }
                if existing.datetime == ann.time.to_rfc3339() {
                    ann_active.value = ActiveValue::Unchanged(existing.datetime.clone());
                }
            }
        }
        annotations_active.push(ann_active);
    }
    annotations_active
}

async fn links_to_active_model(
    db: &DatabaseConnection,
    links: &Vec<Link>,
    task_id: &ActiveValue<i32>,
) -> Vec<links::ActiveModel> {
    let mut links_active: Vec<links::ActiveModel> = vec![];

    for link in links {
        links_active.push(links::ActiveModel {
            id: Set(link.id.unwrap_or_default()),
            // We assume the current task is the source of the link.
            from_task_id: task_id.to_owned(),
            // Since the migration requires an integer foreign key,
            // a helper function is used to map the target Uuid to its db_id.
            to_task_id: Set(resolve_uuid_to_db_id(db, link.to).await.unwrap()),
            // Convert the link type to its string representation.
            r#type: Set(match link.link_type {
                LinkType::DependsOn => "DependsOn".to_owned(),
                LinkType::Blocking => "Blocking".to_owned(),
            }),
        });
    }

    links_active
}

async fn history_to_active_model(
    db: &DatabaseConnection,
    history_events: &Vec<TaskHistory>,
    task_id: &ActiveValue<i32>,
) -> Vec<history::ActiveModel> {
    let mut history_events_active: Vec<history::ActiveModel> = vec![];

    for event in history_events {
        let mut event_active = history::ActiveModel {
            id: Set(event.id.unwrap_or_default()),
            value: Set(event.value.clone()),
            datetime: Set(event.datetime.to_rfc3339()),
            // The history table references the task’s db_id.
            task_id: task_id.to_owned(),
            ..Default::default()
        };
        if let Some(id) = event.id {
            if let Ok(Some(existing)) = history::Entity::find_by_id(id).one(db).await {
                if existing.value == event.value {
                    event_active.value = ActiveValue::Unchanged(existing.datetime.clone());
                }
                if existing.datetime == event.datetime.to_rfc3339() {
                    event_active.value = ActiveValue::Unchanged(existing.datetime.clone());
                }
            }
        }
        history_events_active.push(event_active);
    }
    history_events_active
}

/// Placeholder function for converting a Uuid to the corresponding database id.
/// You must implement this logic based on your application's context.
async fn resolve_uuid_to_db_id(db: &DatabaseConnection, _id: Uuid) -> Option<i32> {
    // For now, simply return None or an appropriate default.
    let t = tables::tasks::Entity::find()
        .filter(tables::tasks::Column::Uuid.eq(_id.to_string()))
        .one(db)
        .await
        .unwrap();

    return Some(t.unwrap().db_id);
}
