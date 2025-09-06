mod tables;

use crate::{
    filters::Filter,
    task::{Link, LinkType, Project, Task, TaskAnnotation, TaskHistory, TaskStatus},
};
use migration::{Migrator, MigratorTrait, sea_orm::Database};
use tables::{annotations, history, links, projects, tags, tasks, tasks_tags};

use log::debug;
use uuid::Uuid;

use sea_orm::{
    ActiveModelTrait,
    ActiveValue::{self, Set},
    ColumnTrait, Condition, DatabaseConnection, DbErr, EntityTrait, IntoActiveModel, LoaderTrait,
    QueryFilter, QuerySelect, QueryTrait, Related,
};

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

pub async fn load_tasks(filter: &Box<dyn Filter>) -> Result<(), Box<dyn std::error::Error>> {
    Ok(())
}

pub async fn insert_tasks(tasks: &Vec<Task>) -> Result<(), Box<dyn std::error::Error>> {
    let db = get_database(None).await.unwrap();
    for task in tasks {
        insert_task_impl(&db, task).await?;
    }
    Ok(())
}

pub async fn insert_task(task: &Task) -> Result<(), Box<dyn std::error::Error>> {
    let db = get_database(None).await.unwrap();
    let mut t = task.clone();
    t.project = Some(Project {
        name: "foo-projj".to_string(),
        ..Default::default()
    });
    t.db_id = Some(12);
    insert_task_impl(&db, &t).await
}

async fn insert_task_impl(
    db: &DatabaseConnection,
    task: &Task,
) -> Result<(), Box<dyn std::error::Error>> {
    debug!("Enter in insert_task_impl");
    upkeep_projects(db).await;
    upkeep_annotations(db, task).await;
    upkeep_history_events(db, task).await;
    upkeep_links(db, task).await;
    upkeep_tasks_tags(db, task).await;
    upkeep_tags(db).await;

    let project_id = if let Some(task_proj) = &task.project {
        let project_active = project_to_active_model(db, &task_proj)
            .await?
            .save(db)
            .await?;
        Some(project_active.id.unwrap())
    } else {
        None
    };

    let model_task_active = task_to_active_model(db, task, project_id).await;
    let model_task = insert_or_update_task(db, &model_task_active).await;

    let vec_annotations =
        annotations_to_active_model(db, &task.annotations, &ActiveValue::Set(model_task.db_id))
            .await?;
    for ann in vec_annotations {
        ann.save(db).await?;
    }

    let vec_links =
        links_to_active_model(db, &task.links, &ActiveValue::Set(model_task.db_id)).await?;
    for link in vec_links {
        link.save(db).await?;
    }

    let vec_history =
        history_to_active_model(db, &task.history, &ActiveValue::Set(model_task.db_id)).await?;
    for history in vec_history {
        history.save(db).await?;
    }

    let tasks: Vec<tasks::Model> = tasks::Entity::find().all(db).await?;
    let annotations: Vec<Vec<annotations::Model>> =
        tasks.load_many(annotations::Entity, db).await?;
    let tags = tasks
        .load_many_to_many(tags::Entity, tasks_tags::Entity, db)
        .await?;
    let p = tasks.load_one(projects::Entity, db).await?;
    save_tags(db, &task.tags).await;
    insert_or_update_tasks_tags(db, &model_task.db_id, &task.tags).await;

    Ok(())
}

/// Delete annotations that were previously linked to a task but not anymore
async fn upkeep_annotations(db: &DatabaseConnection, task_obj: &Task) {
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

/// Delete links referring a task that no longer has that link
async fn upkeep_links(db: &DatabaseConnection, task_obj: &Task) {
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

/// Delete from the Tag table all those not referrenced by any task
async fn upkeep_tags(db: &DatabaseConnection) {
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

/// Delete from the TasksTag table the entries that are not used anymore by
/// the task_obj parameter
async fn upkeep_tasks_tags(db: &DatabaseConnection, task_obj: &Task) {
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

async fn upkeep_history_events(db: &DatabaseConnection, task_obj: &Task) {
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

async fn upkeep_projects(db: &DatabaseConnection) {
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
    debug!("Enter insert_or_update_task");
    let db_id_option: Option<i32> = match &task_model_active.db_id {
        sea_orm::ActiveValue::Set(val) | sea_orm::ActiveValue::Unchanged(val) => Some(*val),
        ActiveValue::NotSet => None,
    };

    if let Some(db_id) = db_id_option {
        if let Ok(Some(_)) = tables::tasks::Entity::find_by_id(db_id).one(db).await {
            debug!("We are updating the task entry with db_id={}", db_id);
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

async fn save_tags(db: &DatabaseConnection, tags: &Vec<String>) {
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

pub async fn project_to_active_model(
    db: &DatabaseConnection,
    project_obj: &Project,
) -> Result<projects::ActiveModel, DbErr> {
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

    task_active
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
                if m.value != ann.value {
                    model_active.value = Set(ann.value.clone());
                }
                if m.datetime != ann.time.to_rfc3339() {
                    model_active.datetime = Set(ann.time.to_rfc3339());
                }
                model_active.task_id = task_id.clone();
            }
            _ => {}
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
    let mut links_active: Vec<links::ActiveModel> = vec![];

    for link in links {
        let link_model = if let Some(id) = link.id {
            links::Entity::find_by_id(id).one(db).await?
        } else {
            None
        };

        let mut link_model_active = link_model
            .clone()
            .map(|m| m.into_active_model())
            .unwrap_or_default();

        // TODO: Do the diff between the model and the ModelActive
        match link.id {
            Some(id) => sea_orm::ActiveValue::Unchanged(id),
            None => sea_orm::ActiveValue::NotSet,
        };
        if link_
            // We assume the current task is the source of the link.
            from_task_id: task_id.to_owned(),

        links_active.push(links::ActiveModel {
            id: match link.id {
                Some(id) => sea_orm::ActiveValue::Unchanged(id),
                None => sea_orm::ActiveValue::NotSet,
            },
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

    Ok(links_active)
}

async fn history_to_active_model(
    db: &DatabaseConnection,
    history_events: &Vec<TaskHistory>,
    task_id: &ActiveValue<i32>,
) -> Result<Vec<history::ActiveModel>, DbErr> {
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
    Ok(history_events_active)
}

/// Placeholder function for converting a Uuid to the corresponding database id.
async fn resolve_uuid_to_db_id(db: &DatabaseConnection, _id: Uuid) -> Option<i32> {
    // For now, simply return None or an appropriate default.
    let t = tables::tasks::Entity::find()
        .filter(tables::tasks::Column::Uuid.eq(_id.to_string()))
        .one(db)
        .await
        .unwrap();

    return Some(t.unwrap().db_id);
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
            panic!("Expected value to be Set");
        }
        if let ActiveValue::Set(ref dt) = active.datetime {
            assert_eq!(dt, &ann.time.to_rfc3339());
        } else {
            panic!("Expected datetime to be Set");
        }
        // task_id should be set to 1.
        if let ActiveValue::Set(ref tid) = active.task_id {
            assert_eq!(*tid, 1);
        } else {
            panic!("Expected task_id to be Set");
        }

        // TODO: Test making annotation model when we update the model
    }

    // TODO: Add test to insert a task
    #[tokio::test]
    async fn test_insert_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        let mut t = Task::default();
        insert_task_impl(&db, &t).await.unwrap();
        let t_model_opt = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(t.uuid.to_string()))
            .one(&db)
            .await
            .unwrap();

        let t_model = t_model_opt.unwrap();
        assert_eq!(t.uuid, Uuid::parse_str(&t_model.uuid).unwrap());

        let annotation_model_opt = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(t_model.db_id))
            .all(&db)
            .await
            .unwrap();

        assert_true!(annotation_model_opt.is_empty());

        t.annotations.push(TaskAnnotation::default());
        insert_task_impl(&db, &t).await.unwrap();

        let annotation_model_opt = tables::tasks::Entity::find()
            .filter(tables::tasks::Column::Uuid.eq(t_model.db_id))
            .all(&db)
            .await
            .unwrap();

        assert_false!(annotation_model_opt.is_empty());
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
