//! Task filtering system using a composite pattern.
//!
//! Filters form trees that match tasks based on various criteria. The system
//! supports boolean composition (AND, OR, XOR) and 14 filter types covering
//! status, project, tags, dates, and task relationships.
//!
//! # Building Filters
//!
//! Use the helper functions to construct filter trees:
//! ```ignore
//! // Parse from user input (CLI-style)
//! let filter = filters::from(&["status:pending".into(), "project:backend".into()])?;
//!
//! // Combine programmatically
//! let combined = filters::and(status_filter, project_filter);
//!
//! // Start with a pass-through filter
//! let root = filters::new_empty();
//! ```
//!
//! # Filter Types
//!
//! - **Composite**: `RootFilter` (pass-through), `AndFilter`, `OrFilter`, `XorFilter`
//! - **String**: `StringFilter` (matches task description)
//! - **Property**: `StatusFilter`, `ProjectFilter`, `TagFilter`
//! - **ID**: `UuidFilter`, `TaskIdFilter`, `DependsOnFilter`
//! - **Date**: `DateCreatedFilter`, `DateDueFilter`, `DateEndFilter`
//!
//! # Serialization
//!
//! Filters use `typetag` for automatic serialization. The `#[typetag::serde]`
//! attribute on the trait enables polymorphic serialization of `Box<dyn Filter>`.

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

/// Composable filter for matching tasks.
///
/// Implementors must support cloning, debugging, display, typetag serialization,
/// and thread-safety (`Send + Sync`). The trait uses a composite pattern where
/// filters can contain child filters.
///
/// # Implementing a Custom Filter
///
/// 1. Create a struct implementing `Filter` with `#[typetag::serde]`
/// 2. Implement `validate_task()` with your matching logic
/// 3. For leaf filters, `add_children()` should panic or no-op
/// 4. Add your filter to `FilterKind` enum in `filters_impl.rs`
#[allow(private_bounds)]
#[typetag::serde(tag = "type", content = "value")]
pub trait Filter: CloneFilter + Any + Debug + Display + FilterKindGetter + Send + Sync {
    /// Test whether a task matches this filter's criteria.
    ///
    /// For composite filters (And/Or/Xor), this recursively evaluates children.
    /// For leaf filters, this checks the specific condition (status, project, etc.).
    fn validate_task(&self, task: &Task) -> bool;

    /// Add a child filter to this composite filter.
    ///
    /// Used when building filter trees programmatically. Leaf filters (Status,
    /// Project, etc.) should panic or ignore this call since they cannot have children.
    fn add_children(&mut self, child: Box<dyn Filter>);

    /// Return self as `&dyn Any` for downcasting.
    ///
    /// Used by the `PartialEq` implementation to compare filters of the same type.
    fn as_any(&self) -> &dyn Any;

    /// Iterate over this filter and all descendant filters.
    ///
    /// For leaf filters, returns an iterator containing only self.
    /// For composite filters, recursively yields self and all children.
    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_>;

    /// Convert numeric task IDs to UUIDs within this filter tree.
    ///
    /// When users type `depends:5`, the parser creates a filter with the numeric ID.
    /// Before the filter can be used or serialized, this method converts those IDs
    /// to UUIDs using the provided mapping from the current TaskData.
    fn convert_id_to_uuid(&mut self, id_to_uuid: &HashMap<i32, Uuid>);
}

/// Combine two filters with AND logic.
///
/// Returns a filter that matches only if both inputs match. Optimizations:
/// - If either input is `RootFilter`, returns the other (Root matches everything)
/// - If either input is already `AndFilter`, appends to it instead of nesting
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

/// Combine two filters with OR logic.
///
/// Returns a filter that matches if either input matches. Same optimizations as [`and()`].
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

/// Parse a filter from string arguments (CLI-style input).
///
/// Tokenizes the input strings, parses filter expressions, and builds the filter tree.
/// Supports syntax like `status:pending`, `project:backend`, `+tag`, `due:today`.
///
/// # Errors
///
/// Returns `CoreError::Parse` if the input contains invalid filter syntax.
pub fn from(values: &[String]) -> CoreResult<Box<dyn Filter>> {
    let lexer = Lexer::new(values.join(" "));
    let mut parser = FilterParser::new(lexer);
    let f = parser.parse_filter()?;
    debug!("Parsed filter:\n{}", f);
    Ok(f)
}

/// Create an empty filter that matches all tasks.
///
/// Returns a `RootFilter` which is a pass-through—`validate_task()` always returns true.
/// Useful as a starting point when building filters programmatically.
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
        // Downcast failure means the types don't match, so they're not equal.
        // This shouldn't happen if get_kind() is correctly implemented, but
        // we handle it gracefully rather than panicking in production.
        error!("Unable to downcast Filter - returning false instead of panicking");
        false
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
