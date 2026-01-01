use super::tables;
use crate::filters::{
    Filter,
    filters_impl::{
        AndFilter, DateCreatedFilter, DateDueFilter, DateDueFilterType, DateEndFilter,
        DependsOnFilter, FilterKind, OrFilter, ProjectFilter, StatusFilter, StringFilter,
        TagFilter, TaskIdFilter, UuidFilter, XorFilter,
    },
};
use tables::{links, projects, tags, tasks, tasks_tags};

use sea_orm::{
    ColumnTrait, Condition,
    prelude::Expr,
    sea_query::{Alias, ConditionExpression, Func, Query, SelectStatement},
};

use crate::task::LinkType;

pub(super) fn filter_to_condition_expr(filter: &dyn Filter) -> ConditionExpression {
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
                    filter_to_condition_expr(child.as_ref()),
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
                    filter_to_condition_expr(child.as_ref()),
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
                let expr = filter_to_condition_expr(child.as_ref());
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
            let timestamp = f.time.to_rfc3339();
            let mut condition = Condition::all().add(tasks::Column::DateCompleted.is_not_null());
            if f.before {
                condition = condition.add(tasks::Column::DateCompleted.lt(timestamp));
            } else {
                condition = condition.add(tasks::Column::DateCompleted.gte(timestamp));
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
                tasks::Column::Status.eq(filter_value.to_db_string()),
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

pub(super) fn condition_expression_to_condition(expr: ConditionExpression) -> Condition {
    match expr {
        ConditionExpression::Condition(cond) => cond,
        ConditionExpression::SimpleExpr(simple) => Condition::all().add(simple),
    }
}
