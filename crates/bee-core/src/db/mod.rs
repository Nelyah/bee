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
        db_id: Some(10),
        id: None,
        status: TaskStatus::Completed, // Use an appropriate variant
        uuid: Uuid::new_v4(),
        summary: "Initial summary".to_string(),
        tags: vec!["initial_tag1".to_string(), "initial_tag2".to_string()],
        date_created: chrono::Local::now(),
        project: Some(Project {
            name: "a.a.b".to_string(),
            id: None,
        }),
        ..Task::default()
    };

    let model_project = if let Some(task_proj) = &t.project {
        Some(insert_or_update_project(&db, project_to_active_model(&db, &task_proj).await).await)
    } else {
        None
    };

    let model_task = task_to_active_model(
        &db,
        &t,
        match model_project {
            Some(model) => Some(model.id),
            None => None,
        },
    )
    .await;
    let _model_task = insert_or_update_task(&db, model_task).await;

    debug!("hey {:?}", _model_task);

    Ok(())
}

async fn insert_or_update_task(
    db: &DatabaseConnection,
    mut task_model_active: tasks::ActiveModel,
) -> tables::tasks::Model {
    let db_id_option: Option<i32> = match &task_model_active.db_id {
        sea_orm::ActiveValue::Set(val) | sea_orm::ActiveValue::Unchanged(val) => Some(*val),
        ActiveValue::NotSet => None,
    };
    let task_uuid = task_model_active.uuid.try_as_ref().unwrap().to_string();

    if let Some(db_id) = db_id_option {
        if let Ok(Some(_)) = tables::tasks::Entity::find_by_id(db_id).one(db).await {
            return task_model_active.clone().update(db).await.unwrap();
        }
    } else if let Ok(Some(model)) = tables::tasks::Entity::find()
        .filter(tables::tasks::Column::Uuid.eq(task_uuid))
        .one(db)
        .await
    {
        task_model_active.db_id = ActiveValue::Set(model.db_id);
        return task_model_active.clone().update(db).await.unwrap();
    }
    return task_model_active.insert(db).await.unwrap();
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

use sea_orm::ActiveValue::Set;
use sea_query::OnConflict;
use uuid::Uuid;

// Assume these are the seaORM entity modules.
use tables::{annotations, history, links, projects, tags, tasks};

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
            None => ActiveValue::NotSet,
        },
        date_due: match task_obj.date_due {
            Some(dt) => ActiveValue::Set(Some(dt.to_rfc3339())),
            None => ActiveValue::NotSet,
        },
        urgency: match task_obj.urgency {
            Some(u) => ActiveValue::Set(Some(u as f64)),
            None => ActiveValue::NotSet,
        },
        project_id: match project_dbid_option {
            Some(pid) => ActiveValue::Set(Some(pid)),
            None => ActiveValue::NotSet,
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
