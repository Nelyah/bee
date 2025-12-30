pub(crate) mod filters_impl;

mod parser;

use crate::{CoreResult, lexer::Lexer, task::Task};
use parser::FilterParser;

use log::{debug, error};
use std::{
    any::Any,
    collections::HashMap,
    fmt::{Debug, Display},
};
use uuid::Uuid;

use filters_impl::{
    AndFilter, DateCreatedFilter, DateDueFilter, DateEndFilter, DependsOnFilter, FilterKind,
    FilterKindGetter, OrFilter, ProjectFilter, RootFilter, StatusFilter, StringFilter, TagFilter,
    TaskIdFilter, UuidFilter, XorFilter,
};

#[allow(private_bounds)]
#[typetag::serde(tag = "type", content = "value")]
pub trait Filter: CloneFilter + Any + Debug + Display + FilterKindGetter + Send + Sync {
    fn validate_task(&self, task: &Task) -> bool;
    fn add_children(&mut self, child: Box<dyn Filter>);
    fn as_any(&self) -> &dyn Any;
    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_>;
    fn convert_id_to_uuid(&mut self, id_to_uuid: &HashMap<i32, Uuid>);
}

// Consume @lhs and @rhs to return a new Box<dyn Filter>
// The two filters given in argument are linked by an AND
// operator
pub fn and(lhs: Box<dyn Filter>, rhs: Box<dyn Filter>) -> Box<dyn Filter> {
    if lhs.get_kind() == FilterKind::Root {
        return rhs;
    }
    if rhs.get_kind() == FilterKind::Root {
        return lhs;
    }
    if lhs.get_kind() == FilterKind::And {
        let mut lhs = lhs.clone();
        lhs.add_children(rhs);
        return lhs;
    }
    if rhs.get_kind() == FilterKind::And {
        let mut rhs = rhs.clone();
        rhs.add_children(lhs);
        return rhs;
    }
    Box::new(AndFilter {
        children: vec![lhs, rhs],
    })
}

// Consume @lhs and @rhs to return a new Box<dyn Filter>
// The two filters given in argument are linked by an OR
// operator
pub fn or(lhs: Box<dyn Filter>, rhs: Box<dyn Filter>) -> Box<dyn Filter> {
    if lhs.get_kind() == FilterKind::Root {
        return rhs;
    }
    if rhs.get_kind() == FilterKind::Root {
        return lhs;
    }
    if lhs.get_kind() == FilterKind::Or {
        let mut lhs = lhs.clone();
        lhs.add_children(rhs);
        return lhs;
    }
    if rhs.get_kind() == FilterKind::Or {
        let mut rhs = rhs.clone();
        rhs.add_children(lhs);
        return rhs;
    }
    Box::new(OrFilter {
        children: vec![lhs, rhs],
    })
}

pub fn from(values: &[String]) -> CoreResult<Box<dyn Filter>> {
    let lexer = Lexer::new(values.join(" "));
    let mut parser = FilterParser::new(lexer);
    let f = parser.parse_filter()?;
    debug!("Parsed filter:\n{}", f);
    Ok(f)
}

pub fn new_empty() -> Box<dyn Filter> {
    Default::default()
}

fn downcast_and_compare<T: Filter + PartialEq>(
    self_filter: &dyn Filter,
    other_filter: &dyn Filter,
) -> bool {
    if let (Some(self_concrete), Some(other_concrete)) = (
        self_filter.as_any().downcast_ref::<T>(),
        other_filter.as_any().downcast_ref::<T>(),
    ) {
        self_concrete == other_concrete
    } else {
        error!("Unable to downcast Filter");
        panic!("An error occurred");
    }
}

// This trait is needed to enable cloning of `dyn Filter`.
// We cannot directly tell the trait to implement Clone because it
// cannot be 'Sized'
trait CloneFilter {
    fn clone_box(&self) -> Box<dyn Filter>;
}

impl<T> CloneFilter for T
where
    T: 'static + Filter + Clone,
{
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(self.clone())
    }
}

impl Clone for Box<dyn Filter> {
    fn clone(&self) -> Box<dyn Filter> {
        self.clone_box()
    }
}

impl Default for Box<dyn Filter> {
    fn default() -> Self {
        Box::new(RootFilter {})
    }
}

impl PartialEq for Box<dyn Filter> {
    fn eq(&self, other: &Self) -> bool {
        if self.get_kind() != other.get_kind() {
            return false;
        }

        match self.get_kind() {
            FilterKind::Root => downcast_and_compare::<RootFilter>(self.as_ref(), other.as_ref()),
            FilterKind::And => downcast_and_compare::<AndFilter>(self.as_ref(), other.as_ref()),
            FilterKind::Or => downcast_and_compare::<OrFilter>(self.as_ref(), other.as_ref()),
            FilterKind::Xor => downcast_and_compare::<XorFilter>(self.as_ref(), other.as_ref()),
            FilterKind::String => {
                downcast_and_compare::<StringFilter>(self.as_ref(), other.as_ref())
            }
            FilterKind::Status => {
                downcast_and_compare::<StatusFilter>(self.as_ref(), other.as_ref())
            }
            FilterKind::Project => {
                downcast_and_compare::<ProjectFilter>(self.as_ref(), other.as_ref())
            }
            FilterKind::Tag => downcast_and_compare::<TagFilter>(self.as_ref(), other.as_ref()),
            FilterKind::Uuid => downcast_and_compare::<UuidFilter>(self.as_ref(), other.as_ref()),
            FilterKind::TaskId => {
                downcast_and_compare::<TaskIdFilter>(self.as_ref(), other.as_ref())
            }
            FilterKind::DependsOn => {
                downcast_and_compare::<DependsOnFilter>(self.as_ref(), other.as_ref())
            }
            FilterKind::DateEnd => {
                downcast_and_compare::<DateEndFilter>(self.as_ref(), other.as_ref())
            }
            FilterKind::DateCreated => {
                downcast_and_compare::<DateCreatedFilter>(self.as_ref(), other.as_ref())
            }
            FilterKind::DateDue => {
                downcast_and_compare::<DateDueFilter>(self.as_ref(), other.as_ref())
            }
        }
    }
}

#[cfg(test)]
mod filters_test;
