use crate::task::{Task, TaskStatus};
use log::error;
use std::{
    any::Any,
    fmt::{self, Debug, Display},
};
use uuid::Uuid;

#[derive(PartialEq, Debug)]
pub enum FilterKind {
    And,
    Or,
    Root,
    Status,
    String,
    Tag,
    TaskId,
    Uuid,
    Xor,
}

impl fmt::Display for FilterKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            FilterKind::And => write!(f, "And"),
            FilterKind::Or => write!(f, "Or"),
            FilterKind::Root => write!(f, "Root"),
            FilterKind::Status => write!(f, "Status"),
            FilterKind::String => write!(f, "String"),
            FilterKind::Tag => write!(f, "Tag"),
            FilterKind::TaskId => write!(f, "TaskId"),
            FilterKind::Uuid => write!(f, "Uuid"),
            FilterKind::Xor => write!(f, "Xor"),
        }
    }
}

#[allow(private_bounds)]
pub trait Filter: CloneFilter + Any + Debug + Display {
    fn validate_task(&self, task: &Task) -> bool;
    fn add_children(&mut self, child: Box<dyn Filter>);
    fn get_kind(&self) -> FilterKind;
    fn as_any(&self) -> &dyn Any;
    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_>;
}

// This trait is needed to enable cloning of `dyn Filter`.
// We cannot directly tell the trait to implement Clone because it
// cannot be 'Sized'
pub trait CloneFilter {
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
        }
    }
}

macro_rules! impl_display_and_debug {
    ($($t:ty),*) => {
        $(
            impl Display for $t {
                fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                    self.format_helper(f)
                }
            }
            impl Debug for $t {
                fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                    self.format_helper(f)
                }
            }
        )*
    }
}

impl_display_and_debug!(
    AndFilter,
    OrFilter,
    RootFilter,
    StatusFilter,
    StringFilter,
    TagFilter,
    TaskIdFilter,
    UuidFilter,
    XorFilter
);

fn indent_string(input: &str, indent: usize) -> String {
    let indent_str = "|".to_owned() + &" ".repeat(indent - 1);
    input
        .lines()
        .map(|line| format!("{}{}", indent_str, line))
        .collect::<Vec<String>>()
        .join("\n")
}

#[derive(PartialEq)]
pub struct RootFilter {
    pub child: Option<Box<dyn Filter>>,
}

impl CloneFilter for RootFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(RootFilter {
            child: self.child.to_owned(),
        })
    }
}

impl Filter for RootFilter {
    fn validate_task(&self, task: &Task) -> bool {
        if let Some(child) = &self.child {
            return child.validate_task(task);
        }
        true
    }

    fn add_children(&mut self, child: Box<dyn Filter>) {
        if !self.child.is_none() {
            panic!("Trying to add a child to a RootFilter that already has a value");
        }
        self.child = Some(child);
    }

    fn get_kind(&self) -> FilterKind {
        FilterKind::Root
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        if let Some(c) = &self.child {
            Box::new(std::iter::once(self as &dyn Filter).chain(c.iter()))
        } else {
            Box::new(std::iter::once(self as &dyn Filter))
        }
    }
}

impl RootFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let child_string = if let Some(c) = &self.child {
            c.to_string()
        } else {
            "None".to_string()
        };
        write!(
            f,
            "{}:\n{}",
            self.get_kind(),
            indent_string(&child_string, 4)
        )
    }
}

#[derive(PartialEq)]
pub struct AndFilter {
    pub children: Vec<Box<dyn Filter>>,
}

impl Filter for AndFilter {
    fn validate_task(&self, task: &Task) -> bool {
        for child in &self.children {
            if !child.validate_task(task) {
                return false;
            }
        }
        true
    }

    fn add_children(&mut self, child: Box<dyn Filter>) {
        self.children.push(child);
    }

    fn get_kind(&self) -> FilterKind {
        FilterKind::And
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(
            std::iter::once(self as &dyn Filter)
                .chain(self.children.iter().flat_map(|child| child.iter())),
        )
    }
}

impl AndFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut children_string = String::default();
        for c in &self.children {
            children_string += &format!("\n{}", &c.to_string());
        }
        write!(
            f,
            "{}:{}",
            self.get_kind(),
            indent_string(&children_string, 4)
        )
    }
}

impl CloneFilter for AndFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(AndFilter {
            children: self.children.to_owned(),
        })
    }
}

#[derive(PartialEq)]
pub struct XorFilter {
    pub children: Vec<Box<dyn Filter>>,
}

impl Filter for XorFilter {
    fn validate_task(&self, task: &Task) -> bool {
        let mut valid_count = 0;
        for child in &self.children {
            if child.validate_task(task) {
                valid_count += 1;
            }
            if valid_count > 1 {
                return false;
            }
        }
        valid_count == 1
    }

    fn add_children(&mut self, child: Box<dyn Filter>) {
        self.children.push(child);
    }

    fn get_kind(&self) -> FilterKind {
        FilterKind::Xor
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(
            std::iter::once(self as &dyn Filter)
                .chain(self.children.iter().flat_map(|child| child.iter())),
        )
    }
}

impl XorFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut children_string = String::default();
        for c in &self.children {
            children_string += &format!("\n{}", c);
        }
        write!(
            f,
            "{}:{}",
            self.get_kind(),
            indent_string(&children_string, 4)
        )
    }
}

impl CloneFilter for XorFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(XorFilter {
            children: self.children.to_owned(),
        })
    }
}

#[derive(PartialEq)]
pub struct OrFilter {
    pub children: Vec<Box<dyn Filter>>,
}

impl Filter for OrFilter {
    fn validate_task(&self, task: &Task) -> bool {
        for child in &self.children {
            if child.validate_task(task) {
                return true;
            }
        }
        false
    }

    fn add_children(&mut self, child: Box<dyn Filter>) {
        self.children.push(child);
    }

    fn get_kind(&self) -> FilterKind {
        FilterKind::Or
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(
            std::iter::once(self as &dyn Filter)
                .chain(self.children.iter().flat_map(|child| child.iter())),
        )
    }
}

impl OrFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut children_string = String::default();
        for c in &self.children {
            children_string += &format!("\n{}", c);
        }
        write!(
            f,
            "{}:{}",
            self.get_kind(),
            indent_string(&children_string, 4)
        )
    }
}

impl CloneFilter for OrFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(OrFilter {
            children: self.children.to_owned(),
        })
    }
}

#[derive(PartialEq)]
pub struct StringFilter {
    pub value: String,
}

impl Filter for StringFilter {
    fn validate_task(&self, task: &Task) -> bool {
        task.description
            .to_lowercase()
            .contains(&self.value.to_lowercase())
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a StringFilter");
    }

    fn get_kind(&self) -> FilterKind {
        FilterKind::String
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl StringFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.get_kind(), &self.value)
    }
}

impl CloneFilter for StringFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(StringFilter {
            value: self.value.to_owned(),
        })
    }
}

#[derive(PartialEq)]
pub struct StatusFilter {
    pub status: TaskStatus,
}

impl Filter for StatusFilter {
    fn validate_task(&self, task: &Task) -> bool {
        &self.status == task.get_status()
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a StatusFilter");
    }

    fn get_kind(&self) -> FilterKind {
        FilterKind::Status
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl StatusFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.get_kind(), &self.status)
    }
}

impl CloneFilter for StatusFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(StatusFilter {
            status: self.status.to_owned(),
        })
    }
}

#[derive(PartialEq)]
pub struct TagFilter {
    pub include: bool,
    pub tag_name: String,
}

impl Filter for TagFilter {
    fn validate_task(&self, task: &Task) -> bool {
        if self.include {
            return task.get_tags().iter().any(|t| t == &self.tag_name);
        }
        task.get_tags().iter().all(|t| t != &self.tag_name)
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a TagFilter");
    }

    fn get_kind(&self) -> FilterKind {
        FilterKind::Tag
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl TagFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}: {}: {}",
            self.get_kind(),
            &self.tag_name,
            &self.include,
        )
    }
}

impl CloneFilter for TagFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(TagFilter {
            include: self.include.to_owned(),
            tag_name: self.tag_name.to_owned(),
        })
    }
}

#[derive(PartialEq)]
pub struct UuidFilter {
    pub uuid: Uuid,
}

impl Filter for UuidFilter {
    fn validate_task(&self, task: &Task) -> bool {
        &self.uuid == task.get_uuid()
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a UuidFilter");
    }

    fn get_kind(&self) -> FilterKind {
        FilterKind::Uuid
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl UuidFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.get_kind(), &self.uuid,)
    }
}

impl CloneFilter for UuidFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(UuidFilter {
            uuid: self.uuid.to_owned(),
        })
    }
}

#[derive(PartialEq)]
pub struct TaskIdFilter {
    pub id: usize,
}

impl Filter for TaskIdFilter {
    fn validate_task(&self, task: &Task) -> bool {
        if let Some(task_id) = task.get_id() {
            return self.id == task_id;
        }
        false
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a TaskIdFilter");
    }

    fn get_kind(&self) -> FilterKind {
        FilterKind::TaskId
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl TaskIdFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.get_kind(), &self.id,)
    }
}

impl CloneFilter for TaskIdFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(TaskIdFilter {
            id: self.id.to_owned(),
        })
    }
}

pub fn new_empty() -> Box<dyn Filter> {
    Default::default()
}

#[cfg(test)]
#[path = "filters_test.rs"]
mod filters_test;
