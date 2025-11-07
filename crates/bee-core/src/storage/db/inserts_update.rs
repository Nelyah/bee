use super::tables;
use crate::{
    filters::{
        Filter,
        filters_impl::{
            AndFilter, DateCreatedFilter, DateDueFilter, DateDueFilterType, DateEndFilter,
            DependsOnFilter, FilterKind, OrFilter, ProjectFilter, StatusFilter, StringFilter,
            TagFilter, TaskIdFilter, UuidFilter, XorFilter,
        },
    },
    task::{
        ActionUndo, ActionUndoType, DependsOnIdentifier, Link, LinkType, Project, Task,
        TaskAnnotation, TaskData, TaskHistory, TaskProperties, TaskStatus,
    },
};
use chrono::{DateTime, Local};
use migration::{Migrator, MigratorTrait, sea_orm::Database};
use serde_json;
use tables::{annotations, history, links, projects, tags, tasks, tasks_tags, undo_actions};

use log::debug;
use uuid::Uuid;

use sea_orm::{
    ActiveModelTrait,
    ActiveValue::{self, Set},
    ColumnTrait, Condition, ConnectionTrait, DatabaseConnection, DatabaseTransaction, DbErr,
    EntityTrait, IntoActiveModel, QueryFilter, QueryOrder, QuerySelect, TransactionTrait,
    prelude::Expr,
    sea_query::{Alias, ConditionExpression, Func, Query, SelectStatement},
};
use std::{
    collections::{HashMap, HashSet},
    default,
    str::FromStr,
};

pub(super) async fn get_database(
    db_address: Option<&str>,
) -> Result<DatabaseConnection, Box<dyn std::error::Error>> {
    let db = Database::connect(db_address.unwrap_or("sqlite://db.sqlite?mode=rwc"))
        .await
        .unwrap();

    Migrator::up(&db, None).await?;

    Ok(db)
}

fn filter_to_condition_expr(filter: &Box<dyn Filter>) -> ConditionExpression {
    match filter.get_kind() {
        FilterKind::Root => ConditionExpression::SimpleExpr(Expr::value(true)),
        FilterKind::And => {
            let composite = filter.as_any().downcast_ref::<AndFilter>().unwrap();

            let mut condition = Condition::all();
            for child in &composite.children {
                if child.get_kind() == FilterKind::Root {
                    continue;
                }
                condition = condition.add(condition_expression_to_condition(
                    filter_to_condition_expr(child),
                ));
            }

            ConditionExpression::Condition(condition)
        }
        FilterKind::Or => {
            let composite = filter.as_any().downcast_ref::<OrFilter>().unwrap();

            let mut condition = Condition::any();
            for child in &composite.children {
                if child.get_kind() == FilterKind::Root {
                    continue;
                }
                condition = condition.add(condition_expression_to_condition(
                    filter_to_condition_expr(child),
                ));
            }

            ConditionExpression::Condition(condition)
        }
        FilterKind::Xor => {
            let composite = filter.as_any().downcast_ref::<XorFilter>().unwrap();

            let mut at_least_one = Condition::any();
            let mut many_children = Vec::new();
            for child in &composite.children {
                if child.get_kind() == FilterKind::Root {
                    continue;
                }
                let expr = filter_to_condition_expr(child);
                at_least_one = at_least_one.add(expr.clone());
                many_children.push(expr);
            }

            let mut more_than_one = Condition::any();
            for i in 0..many_children.len() {
                for j in (i + 1)..many_children.len() {
                    more_than_one = more_than_one.add(ConditionExpression::Condition(
                        Condition::all()
                            .add(many_children[i].clone())
                            .add(many_children[j].clone()),
                    ));
                }
            }

            ConditionExpression::Condition(
                Condition::all()
                    .add(at_least_one)
                    .add(Condition::not(more_than_one)),
            )
        }
        FilterKind::DateDue => {
            let f = filter.as_any().downcast_ref::<DateDueFilter>().unwrap();
            let condition = match f.type_when {
                DateDueFilterType::Day => Condition::all()
                    .add(tasks::Column::DateDue.is_not_null())
                    .add(tasks::Column::DateDue.like(format!("{}%", f.time.date_naive()))),
                DateDueFilterType::Before => Condition::all()
                    .add(tasks::Column::DateDue.is_not_null())
                    .add(tasks::Column::DateDue.lt(f.time.to_rfc3339())),
                DateDueFilterType::After => Condition::all()
                    .add(tasks::Column::DateDue.is_not_null())
                    .add(tasks::Column::DateDue.gte(f.time.to_rfc3339())),
            };
            ConditionExpression::Condition(condition)
        }
        FilterKind::DateCreated => {
            let f = filter.as_any().downcast_ref::<DateCreatedFilter>().unwrap();

            let timestamp = f.time.to_rfc3339();
            let mut condition = Condition::all();

            if f.before {
                condition = condition.add(tasks::Column::DateCreated.lt(timestamp));
            } else {
                condition = condition.add(tasks::Column::DateCreated.gte(timestamp));
            }

            ConditionExpression::Condition(condition)
        }
        FilterKind::DateEnd => {
            let f = filter.as_any().downcast_ref::<DateEndFilter>().unwrap();
            let mut condition = Condition::all().add(tasks::Column::DateCompleted.is_not_null());
            if f.before {
                condition = condition.add(tasks::Column::DateCompleted.lt(f.time.to_rfc3339()));
            }
            ConditionExpression::Condition(condition)
        }
        FilterKind::DependsOn => {
            let f = filter.as_any().downcast_ref::<DependsOnFilter>().unwrap();

            let mut target_ids_query: SelectStatement = Query::select();
            target_ids_query
                .column(tasks::Column::DbId)
                .from(tasks::Entity);

            if let Some(uuid) = &f.uuid {
                target_ids_query.and_where(
                    Expr::col((tasks::Entity, tasks::Column::Uuid)).eq(uuid.to_string()),
                );
            }

            if let Some(id) = f.id {
                target_ids_query.and_where(Expr::col((tasks::Entity, tasks::Column::Id)).eq(id));
            }

            let mut exists_query: SelectStatement = Query::select();
            exists_query
                // EXISTS needs a scalar expression, this is just a placeholder but doesn't mean
                // much
                .expr(Expr::val(1))
                .from(links::Entity)
                .and_where(
                    Expr::col((links::Entity, links::Column::FromTaskId))
                        .eq(Expr::col((Alias::new("tasks"), tasks::Column::DbId))),
                )
                .and_where(
                    Expr::col((links::Entity, links::Column::Type))
                        .eq(LinkType::DependsOn.to_string()),
                )
                .and_where(
                    Expr::col((links::Entity, links::Column::ToTaskId))
                        .in_subquery(target_ids_query),
                );

            ConditionExpression::SimpleExpr(Expr::exists(exists_query))
        }
        FilterKind::TaskId => {
            let filter_value = filter.as_any().downcast_ref::<TaskIdFilter>().unwrap().id;
            ConditionExpression::Condition(Condition::all().add(tasks::Column::Id.eq(filter_value)))
        }
        FilterKind::Uuid => {
            let filter_value = filter
                .as_any()
                .downcast_ref::<UuidFilter>()
                .unwrap()
                .uuid
                .to_string();
            sea_orm::sea_query::ConditionExpression::SimpleExpr(
                tasks::Column::Uuid.eq(filter_value),
            )
        }
        FilterKind::Project => {
            let project_filter = filter.as_any().downcast_ref::<ProjectFilter>().unwrap();
            let project_name = project_filter.name.get_name().clone();

            let mut name_query: SelectStatement = Query::select();
            name_query
                .column(projects::Column::Id)
                .from(projects::Entity)
                .and_where(
                    Expr::col((projects::Entity, projects::Column::Name))
                        .like(format!("{}%", project_name)),
                );

            ConditionExpression::Condition(
                Condition::all()
                    .add(tasks::Column::ProjectId.is_not_null())
                    .add(tasks::Column::ProjectId.in_subquery(name_query)),
            )
        }
        FilterKind::Tag => {
            let tag_filter = filter.as_any().downcast_ref::<TagFilter>().unwrap();
            let tag_name = tag_filter.tag_name.clone();
            if tag_filter.include {
                let mut tag_id_query: SelectStatement = Query::select();
                tag_id_query
                    .column(tags::Column::Id)
                    .from(tags::Entity)
                    .and_where(Expr::col((tags::Entity, tags::Column::Name)).eq(tag_name));

                let mut link_exists_query: SelectStatement = Query::select();
                link_exists_query
                    .expr(Expr::val(1))
                    .from(tasks_tags::Entity)
                    .and_where(
                        Expr::col((tasks_tags::Entity, tasks_tags::Column::TaskId))
                            .eq(Expr::col((Alias::new("tasks"), tasks::Column::DbId))),
                    )
                    .and_where(
                        Expr::col((tasks_tags::Entity, tasks_tags::Column::TagId))
                            .in_subquery(tag_id_query),
                    );

                ConditionExpression::SimpleExpr(Expr::exists(link_exists_query))
            } else {
                let mut tag_id_query: SelectStatement = Query::select();
                tag_id_query
                    .column(tags::Column::Id)
                    .from(tags::Entity)
                    .and_where(Expr::col((tags::Entity, tags::Column::Name)).eq(tag_name));

                ConditionExpression::SimpleExpr(
                    Expr::exists({
                        let mut exclude_query: SelectStatement = Query::select();
                        exclude_query
                            .expr(Expr::val(1))
                            .from(tasks_tags::Entity)
                            .and_where(
                                Expr::col((tasks_tags::Entity, tasks_tags::Column::TaskId))
                                    .eq(Expr::col((Alias::new("tasks"), tasks::Column::DbId))),
                            )
                            .and_where(
                                Expr::col((tasks_tags::Entity, tasks_tags::Column::TagId))
                                    .in_subquery(tag_id_query),
                            );
                        exclude_query
                    })
                    .not(),
                )
            }
        }
        FilterKind::Status => {
            let filter_value = filter
                .as_any()
                .downcast_ref::<StatusFilter>()
                .unwrap()
                .status
                .to_owned();
            sea_orm::sea_query::ConditionExpression::SimpleExpr(
                tasks::Column::Status.eq(filter_value.to_string().to_uppercase()),
            )
        }
        FilterKind::String => {
            let filter_value = filter
                .as_any()
                .downcast_ref::<StringFilter>()
                .unwrap()
                .value
                .to_owned();

            sea_orm::sea_query::ConditionExpression::SimpleExpr(
                Expr::expr(Func::lower(Expr::col(tasks::Column::Summary)))
                    .like(format!("%{}%", filter_value.to_lowercase())),
            )
        }
    }
}

fn condition_expression_to_condition(expr: ConditionExpression) -> Condition {
    match expr {
        ConditionExpression::Condition(cond) => cond,
        ConditionExpression::SimpleExpr(simple) => Condition::all().add(simple),
    }
}

pub(super) async fn load_tasks_impl(
    db: &DatabaseConnection,
    filter: &Box<dyn Filter>,
    props: Option<TaskProperties>,
) -> Result<TaskData, Box<dyn std::error::Error>> {
    let tasks_obj = tasks_from_filter(db, filter).await?;

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
                        .push(Box::new(UuidFilter { uuid: uuid }));
                }
                DependsOnIdentifier::Id(id) => {
                    extra_task_filter
                        .children
                        .push(Box::new(TaskIdFilter { id: id }));
                }
            }
        }
        let f: Box<dyn Filter> = Box::new(extra_task_filter);
        let extra_tasks_obj = tasks_from_filter(db, &f).await?;
        for t in extra_tasks_obj {
            task_data.insert_extra_task(t);
        }
    }

    // TODO: Need to build a id to uuid index for the props so I can search for DependsOnIdentifier
    // and get the extra tasks.
    Ok(task_data)
}

async fn tasks_from_filter(
    db: &DatabaseConnection,
    filter: &Box<dyn Filter>,
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

pub(super) async fn append_undo_action_impl(
    db: &DatabaseConnection,
    undo: &ActionUndo,
) -> Result<(), Box<dyn std::error::Error>> {
    let payload = serde_json::to_string(undo)?;
    let active = undo_actions::ActiveModel {
        action_type: Set(match undo.action_type {
            ActionUndoType::Add => "ADD".to_string(),
            ActionUndoType::Modify => "MODIFY".to_string(),
        }),
        payload: Set(payload),
        ..Default::default()
    };
    active.insert(db).await?;
    Ok(())
}

pub(super) async fn load_undos_impl(
    db: &DatabaseConnection,
    limit: usize,
) -> Result<Vec<ActionUndo>, Box<dyn std::error::Error>> {
    if limit == 0 {
        return Ok(Vec::new());
    }

    let mut records = undo_actions::Entity::find()
        .order_by_desc(undo_actions::Column::CreatedAt)
        .order_by_desc(undo_actions::Column::Id)
        .limit(limit as u64)
        .all(db)
        .await?;

    records.reverse();

    let mut undos: Vec<ActionUndo> = Vec::with_capacity(records.len());
    for record in records {
        let mut undo: ActionUndo = serde_json::from_str(&record.payload)?;
        undo.action_type = match record.action_type.as_str() {
            "ADD" => ActionUndoType::Add,
            "MODIFY" => ActionUndoType::Modify,
            other => return Err(format!("Unknown undo action type '{}'", other).into()),
        };
        undos.push(undo);
    }
    Ok(undos)
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

pub(super) async fn write_tasks_impl(
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

async fn project_to_active_model<C>(
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

    let desired_ids: HashSet<i32> = desired_links.iter().filter_map(|link| link.id).collect();

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

                let link_type_string = link.link_type.to_string();
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
            r#type: Set(link.link_type.to_string()),
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

/// Build an in-memory [`Task`] from the persisted database model and its related tables.
async fn task_model_to_object<C>(
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

    let link_models = links::Entity::find()
        .filter(links::Column::FromTaskId.eq(task_model.db_id))
        .all(db)
        .await?;
    let mut links_vec = Vec::with_capacity(link_models.len());
    if !link_models.is_empty() {
        let to_ids: Vec<i32> = link_models.iter().map(|link| link.to_task_id).collect();
        let target_models = tasks::Entity::find()
            .filter(tasks::Column::DbId.is_in(to_ids))
            .all(db)
            .await?;

        let mut to_uuid_map: HashMap<i32, Uuid> = HashMap::new();
        for model in target_models {
            let target_uuid = Uuid::parse_str(&model.uuid)?;
            to_uuid_map.insert(model.db_id, target_uuid);
        }

        for link in link_models {
            let link_type = LinkType::from_str(link.r#type.as_str())?;
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
                link_type,
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

/// Placeholder function for converting a Uuid to the corresponding database id.
async fn resolve_uuid_to_db_id<C>(db: &C, id: Uuid) -> Result<Option<i32>, DbErr>
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
    use crate::task::TaskStatus;
    use chrono::{Duration, Local, TimeZone};

    async fn assert_single_match(
        db: &DatabaseConnection,
        filter: Box<dyn Filter>,
        expected_task: &Task,
    ) {
        let results_data = load_tasks_impl(db, &filter, None).await.unwrap();
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
        assert_eq!(result, &expected_task_mut);
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

        append_undo_action_impl(&db, &first_undo).await.unwrap();
        append_undo_action_impl(&db, &second_undo).await.unwrap();

        let recent = load_undos_impl(&db, 1).await.unwrap();
        assert_eq!(recent.len(), 1, "Expected a single undo action returned");
        let latest = &recent[0];

        assert_eq!(latest.action_type, expected_latest.action_type);
        assert_eq!(latest.tasks, expected_latest.tasks);
    }
    #[tokio::test]
    async fn test_insert_load_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();
        // 1. Create an in-memory task and save its UUID
        let mut t = Task::default();
        let saved_uuid = t.uuid; // UUID auto-generated in default impl
        t.summary = "foo bar café".to_string();

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
            value: "foo bar café".to_string(),
        });
        let loaded = load_tasks_impl(&db, &f, None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 1, "Should have one task retrieved");

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "FOO".to_string(),
        });
        let loaded = load_tasks_impl(&db, &f, None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 1, "Should be case insensitive");

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "café".to_string(),
        });
        let loaded = load_tasks_impl(&db, &f, None).await.unwrap();
        assert_eq!(loaded.to_vec().len(), 1, "Should be case insensitive");

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "CAFÉ".to_string(),
        });
        let loaded = load_tasks_impl(&db, &f, None).await.unwrap();
        assert_eq!(
            loaded.to_vec().len(),
            1,
            "Should be case insensitive with non-ascii char"
        );

        let f: Box<dyn Filter> = Box::new(StringFilter {
            value: "NO".to_string(),
        });
        let loaded = load_tasks_impl(&db, &f, None).await.unwrap();
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

        let target_task = Task::default();
        let target_uuid = target_task.uuid;
        write_tasks_impl(&db, &target_task).await.unwrap();

        let mut source_task = Task::default();
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

        let mut task = Task::default();
        let task_uuid = task.uuid;
        let project_name = "sync-project".to_string();
        task.project = Some(Project {
            id: None,
            name: project_name.clone(),
        });

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
        let _ = env_logger::builder().is_test(true).try_init();
    }

    #[tokio::test]
    async fn test_filter_status_matches_single_task() {
        init();
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut active_task = Task::default();
        active_task.summary = "active-task".to_string();
        active_task.status = TaskStatus::Active;
        active_task.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &active_task).await.unwrap();

        let mut pending_task = Task::default();
        pending_task.summary = "pending-task".to_string();
        pending_task.status = TaskStatus::Pending;
        pending_task.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &pending_task).await.unwrap();

        let all_tasks = tables::tasks::Entity::find().all(&db).await.unwrap();
        debug!("FOO {:?}", &all_tasks);
        assert_eq!(all_tasks.len(), 2);
        let statuses: Vec<_> = all_tasks.iter().map(|t| t.status.clone()).collect();
        assert!(statuses.contains(&TaskStatus::Active.to_string().to_uppercase()));
        assert!(statuses.contains(&TaskStatus::Pending.to_string().to_uppercase()));

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

        let mut alpha_task = Task::default();
        alpha_task.summary = "Alpha Project".to_string();
        alpha_task.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &alpha_task).await.unwrap();

        let mut beta_task = Task::default();
        beta_task.summary = "Beta Project".to_string();
        beta_task.uuid = Uuid::new_v4();
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

        let mut task_one = Task::default();
        task_one.summary = "Task-1".to_string();
        task_one.id = Some(101);
        task_one.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &task_one).await.unwrap();

        let mut task_two = Task::default();
        task_two.summary = "Task-2".to_string();
        task_two.id = Some(202);
        task_two.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &task_two).await.unwrap();

        assert_single_match(&db, Box::new(TaskIdFilter { id: 101 }), &task_one).await;
    }

    #[tokio::test]
    async fn test_filter_uuid_matches_single_task() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut matched = Task::default();
        matched.summary = "Uuid-Match".to_string();
        matched.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &matched).await.unwrap();

        let mut other = Task::default();
        other.summary = "Uuid-Other".to_string();
        other.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &other).await.unwrap();

        assert_single_match(&db, Box::new(UuidFilter { uuid: matched.uuid }), &matched).await;
    }

    #[tokio::test]
    async fn test_filter_project_matches_prefix() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut alpha_task = Task::default();
        alpha_task.summary = "Alpha Task".to_string();
        alpha_task.project = Some(Project {
            id: None,
            name: "alpha.core".to_string(),
        });
        alpha_task.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &alpha_task).await.unwrap();

        let mut beta_task = Task::default();
        beta_task.summary = "Beta Task".to_string();
        beta_task.project = Some(Project {
            id: None,
            name: "beta.core".to_string(),
        });
        beta_task.uuid = Uuid::new_v4();
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

        let mut tagged_task = Task::default();
        tagged_task.summary = "Tagged Task".to_string();
        tagged_task.tags.push("urgent".to_string());
        tagged_task.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &tagged_task).await.unwrap();

        let mut untagged_task = Task::default();
        untagged_task.summary = "Untagged Task".to_string();
        untagged_task.uuid = Uuid::new_v4();
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

        let mut tagged_task = Task::default();
        tagged_task.summary = "Tagged Task".to_string();
        tagged_task.tags.push("chore".to_string());
        tagged_task.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &tagged_task).await.unwrap();

        let mut clean_task = Task::default();
        clean_task.summary = "Clean Task".to_string();
        clean_task.uuid = Uuid::new_v4();
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

        let mut early_task = Task::default();
        early_task.summary = "Early Task".to_string();
        early_task.date_created = early;
        early_task.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &early_task).await.unwrap();

        let mut late_task = Task::default();
        late_task.summary = "Late Task".to_string();
        late_task.date_created = late;
        late_task.uuid = Uuid::new_v4();
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

        let mut early_task = Task::default();
        early_task.summary = "Early Task".to_string();
        early_task.date_created = early;
        early_task.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &early_task).await.unwrap();

        let mut late_task = Task::default();
        late_task.summary = "Late Task".to_string();
        late_task.date_created = late;
        late_task.uuid = Uuid::new_v4();
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

        let mut due_today = Task::default();
        due_today.summary = "Due Today".to_string();
        due_today.date_due = Some(reference);
        due_today.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &due_today).await.unwrap();

        let mut due_tomorrow = Task::default();
        due_tomorrow.summary = "Due Tomorrow".to_string();
        due_tomorrow.date_due = Some(reference + Duration::days(1));
        due_tomorrow.uuid = Uuid::new_v4();
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

        let mut due_early = Task::default();
        due_early.summary = "Due Early".to_string();
        due_early.date_due = Some(early_due);
        due_early.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &due_early).await.unwrap();

        let mut due_late = Task::default();
        due_late.summary = "Due Late".to_string();
        due_late.date_due = Some(late_due);
        due_late.uuid = Uuid::new_v4();
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

        let mut due_early = Task::default();
        due_early.summary = "Due Early".to_string();
        due_early.date_due = Some(early_due);
        due_early.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &due_early).await.unwrap();

        let mut due_later = Task::default();
        due_later.summary = "Due Later".to_string();
        due_later.date_due = Some(late_due);
        due_later.uuid = Uuid::new_v4();
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

        let mut completed_early = Task::default();
        completed_early.summary = "Completed Early".to_string();
        completed_early.date_completed = Some(early_complete);
        completed_early.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &completed_early).await.unwrap();

        let mut completed_late = Task::default();
        completed_late.summary = "Completed Late".to_string();
        completed_late.date_completed = Some(late_complete);
        completed_late.uuid = Uuid::new_v4();
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

        let mut target_task = Task::default();
        target_task.summary = "Target Task".to_string();
        target_task.uuid = Uuid::new_v4();
        let target_uuid = target_task.uuid;
        write_tasks_impl(&db, &target_task).await.unwrap();

        let mut dependent_task = Task::default();
        dependent_task.summary = "Dependent Task".to_string();
        dependent_task.uuid = Uuid::new_v4();
        let dependent_uuid = dependent_task.uuid;
        dependent_task.links.push(Link {
            id: None,
            from: dependent_uuid,
            to: target_uuid,
            link_type: LinkType::DependsOn,
        });
        write_tasks_impl(&db, &dependent_task).await.unwrap();

        let mut independent_task = Task::default();
        independent_task.summary = "Independent Task".to_string();
        independent_task.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &independent_task).await.unwrap();

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
    async fn test_filter_and_combination() {
        let db = get_database(Some("sqlite::memory:")).await.unwrap();

        let mut alpha_active = Task::default();
        alpha_active.summary = "Alpha Active".to_string();
        alpha_active.status = TaskStatus::Active;
        alpha_active.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &alpha_active).await.unwrap();

        let mut alpha_pending = Task::default();
        alpha_pending.summary = "Alpha Pending".to_string();
        alpha_pending.status = TaskStatus::Pending;
        alpha_pending.uuid = Uuid::new_v4();
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

        let mut alpha_pending = Task::default();
        alpha_pending.summary = "Alpha Pending".to_string();
        alpha_pending.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &alpha_pending).await.unwrap();

        let mut beta_pending = Task::default();
        beta_pending.summary = "Beta Pending".to_string();
        beta_pending.uuid = Uuid::new_v4();
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

        let mut alpha_pending = Task::default();
        alpha_pending.summary = "Alpha Pending".to_string();
        alpha_pending.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &alpha_pending).await.unwrap();

        let mut beta_pending = Task::default();
        beta_pending.summary = "Beta Pending".to_string();
        beta_pending.uuid = Uuid::new_v4();
        write_tasks_impl(&db, &beta_pending).await.unwrap();

        let mut alpha_active = Task::default();
        alpha_active.summary = "Alpha Active".to_string();
        alpha_active.status = TaskStatus::Active;
        alpha_active.uuid = Uuid::new_v4();
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
