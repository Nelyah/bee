mod filters_impl;
mod parser;

use crate::lexer::Lexer;
use crate::task::Task;
use parser::ParserN;

use log::{debug, error};
use std::{
    any::Any,
    fmt::{Debug, Display},
};

use filters_impl::{
    AndFilter, DateEndFilter, FilterKind, FilterKindGetter, OrFilter, RootFilter, StatusFilter,
    StringFilter, TagFilter, TaskIdFilter, UuidFilter, XorFilter,
};

#[allow(private_bounds)]
pub trait Filter: CloneFilter + Any + Debug + Display + FilterKindGetter {
    fn validate_task(&self, task: &Task) -> bool;
    fn add_children(&mut self, child: Box<dyn Filter>);
    fn as_any(&self) -> &dyn Any;
    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_>;
}

// Consume @lhs and @rhs to return a new Box<dyn Filter>
// The two filters given in argument are linked by an AND
// operator
pub fn and(lhs: Box<dyn Filter>, rhs: Box<dyn Filter>) -> Box<dyn Filter> {
    Box::new(AndFilter {
        children: vec![lhs, rhs],
    })
}

pub fn from(values: &[String]) -> Box<dyn Filter> {
    let lexer = Lexer::new(values.join(" "));
    let mut parser = ParserN::new(lexer);
    let f = parser.parse_filter();
    debug!("Parsed filter:\n{}", f);
    f
}

pub fn new_empty() -> Box<dyn Filter> {
    Default::default()
}

#[allow(clippy::borrowed_box)]
fn downcast_and_compare<T: Filter + PartialEq>(
    self_filter: &Box<dyn Filter>,
    other_filter: &Box<dyn Filter>,
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
        Box::new(RootFilter { child: None })
    }
}

impl PartialEq for Box<dyn Filter> {
    fn eq(&self, other: &Self) -> bool {
        if self.get_kind() != other.get_kind() {
            return false;
        }

        match self.get_kind() {
            FilterKind::Root => downcast_and_compare::<RootFilter>(self, other),
            FilterKind::And => downcast_and_compare::<AndFilter>(self, other),
            FilterKind::Or => downcast_and_compare::<OrFilter>(self, other),
            FilterKind::Xor => downcast_and_compare::<XorFilter>(self, other),
            FilterKind::String => downcast_and_compare::<StringFilter>(self, other),
            FilterKind::Status => downcast_and_compare::<StatusFilter>(self, other),
            FilterKind::Tag => downcast_and_compare::<TagFilter>(self, other),
            FilterKind::Uuid => downcast_and_compare::<UuidFilter>(self, other),
            FilterKind::TaskId => downcast_and_compare::<TaskIdFilter>(self, other),
            FilterKind::DateEnd => downcast_and_compare::<DateEndFilter>(self, other),
        }
    }
}

#[cfg(test)]
#[path = "filters_test.rs"]
mod filters_test;
