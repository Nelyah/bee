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
pub trait Filter: CloneFilter + Any + Debug + Display{
    fn validate_task(&self, task: &Task) -> bool;
    fn add_children(&mut self, child: Box<dyn Filter>);
    fn get_kind(&self) -> FilterKind;
    fn as_any(&self) -> &dyn Any;
}

// This trait is needed to enable cloning of `dyn Filter`.
trait CloneFilter {
    fn clone_box(&self) -> Box<dyn Filter>;
}

// Implement `CloneFilter` for any type that implements `Filter` and `Clone`.
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
            FilterKind::Root => {
                if let (Some(self_concrete), Some(other_concrete)) = (
                    self.as_any().downcast_ref::<RootFilter>(),
                    other.as_any().downcast_ref::<RootFilter>(),
                ) {
                    if self_concrete.child.is_none() && other_concrete.child.is_none() {
                        return true;
                    }
                    self_concrete.child == other_concrete.child
                } else {
                    error!("Unabled to downcast Filter to RootFilter");
                    panic!("An error occured");
                }
            }
            FilterKind::And => {
                if let (Some(self_concrete), Some(other_concrete)) = (
                    self.as_any().downcast_ref::<AndFilter>(),
                    other.as_any().downcast_ref::<AndFilter>(),
                ) {
                    self_concrete.children == other_concrete.children
                } else {
                    error!("Unabled to downcast Filter to AndFilter");
                    panic!("An error occured");
                }
            }
            FilterKind::Or => {
                if let (Some(self_concrete), Some(other_concrete)) = (
                    self.as_any().downcast_ref::<OrFilter>(),
                    other.as_any().downcast_ref::<OrFilter>(),
                ) {
                    self_concrete.children == other_concrete.children
                } else {
                    error!("Unabled to downcast Filter to OrFilter");
                    panic!("An error occured");
                }
            }
            FilterKind::Xor => {
                if let (Some(self_concrete), Some(other_concrete)) = (
                    self.as_any().downcast_ref::<XorFilter>(),
                    other.as_any().downcast_ref::<XorFilter>(),
                ) {
                    self_concrete.children == other_concrete.children
                } else {
                    error!("Unabled to downcast Filter to XorFilter");
                    panic!("An error occured");
                }
            }
            FilterKind::String => {
                if let (Some(self_concrete), Some(other_concrete)) = (
                    self.as_any().downcast_ref::<StringFilter>(),
                    other.as_any().downcast_ref::<StringFilter>(),
                ) {
                    self_concrete == other_concrete
                } else {
                    error!("Unabled to downcast Filter to StringFilter");
                    panic!("An error occured");
                }
            }
            FilterKind::Status => {
                if let (Some(self_concrete), Some(other_concrete)) = (
                    self.as_any().downcast_ref::<StatusFilter>(),
                    other.as_any().downcast_ref::<StatusFilter>(),
                ) {
                    self_concrete == other_concrete
                } else {
                    error!("Unabled to downcast Filter to StatusFilter");
                    panic!("An error occured");
                }
            }
            FilterKind::Tag => {
                if let (Some(self_concrete), Some(other_concrete)) = (
                    self.as_any().downcast_ref::<TagFilter>(),
                    other.as_any().downcast_ref::<TagFilter>(),
                ) {
                    self_concrete == other_concrete
                } else {
                    error!("Unabled to downcast Filter to TagFilter");
                    panic!("An error occured");
                }
            }
            FilterKind::Uuid => {
                if let (Some(self_concrete), Some(other_concrete)) = (
                    self.as_any().downcast_ref::<UuidFilter>(),
                    other.as_any().downcast_ref::<UuidFilter>(),
                ) {
                    self_concrete == other_concrete
                } else {
                    error!("Unabled to downcast Filter to UuidFilter");
                    panic!("An error occured");
                }
            }
            FilterKind::TaskId => {
                if let (Some(self_concrete), Some(other_concrete)) = (
                    self.as_any().downcast_ref::<TaskIdFilter>(),
                    other.as_any().downcast_ref::<TaskIdFilter>(),
                ) {
                    self_concrete == other_concrete
                } else {
                    error!("Unabled to downcast Filter to TaskIdFilter");
                    panic!("An error occured");
                }
            }
        }
    }
}

fn indent_string(input: &str, indent: usize) -> String {
    let indent_str = " ".repeat(indent);
    input
        .lines()
        .map(|line| format!("{}{}", indent_str, line))
        .collect::<Vec<String>>()
        .join("\n")
}

// impl fmt::Debug for dyn Filter {
//     fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
//         write!(f, "{}", self.get_kind())
//     }
// }

// impl std::fmt::Debug for Box<dyn Filter> {
//     fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
//         write!(f, "{}", self.get_kind())
//     }
// }

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

impl Display for RootFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}
impl Debug for RootFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}

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

impl Display for AndFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}
impl Debug for AndFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}

impl CloneFilter for AndFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(AndFilter {
            children: self.children.to_owned(),
        })
    }
}

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

impl Display for XorFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}
impl Debug for XorFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}

impl CloneFilter for XorFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(XorFilter {
            children: self.children.to_owned(),
        })
    }
}

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

impl Display for OrFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}
impl Debug for OrFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
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
}


impl StringFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}: {}",
            self.get_kind(),
            &self.value
        )
    }
}

impl Display for StringFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}
impl Debug for StringFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
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
}

impl StatusFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}: {}",
            self.get_kind(),
            &self.status
        )
    }
}

impl Display for StatusFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}
impl Debug for StatusFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
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

impl Display for TagFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}
impl Debug for TagFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
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
}

impl UuidFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}: {}",
            self.get_kind(),
            &self.uuid,
        )
    }
}

impl Display for UuidFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}
impl Debug for UuidFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
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
}

impl TaskIdFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}: {}",
            self.get_kind(),
            &self.id,
        )
    }
}

impl Display for TaskIdFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
    }
}
impl Debug for TaskIdFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.format_helper(f)
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

// fn to_string_impl(&self, indent: &str) -> String {
//     let str_op = match self.operator {
//         FilterCombinationType::And => "AND",
//         FilterCombinationType::Or => "OR",
//         FilterCombinationType::Xor => "XOR",
//         FilterCombinationType::None => "NONE",
//     };
//     let mut out_str = String::default();

//     if self.has_value {
//         out_str = out_str
//             + "\n"
//             + &format!(
//                 "{}Operator is {} (has_value: {}, value: \"{}\")",
//                 indent, str_op, self.has_value, self.value
//             );
//     } else {
//         out_str = out_str + "\n" + &format!("{}Operator is {}", indent, str_op);
//     }

//     for c in &self.children {
//         out_str = out_str + &c.to_string_impl(&(indent.to_owned() + "    "));
//     }
//     out_str
// }
// impl fmt::Display for OldFilter {
//     fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
//         write!(f, "{}", self.to_string_impl(""))
//     }
// }

// impl std::fmt::Debug for OldFilter {
//     fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
//         write!(f, "{}", self.to_string_impl(""))
//     }
// }

#[cfg(test)]
#[path = "filters_test.rs"]
mod filters_test;
