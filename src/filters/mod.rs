use crate::task::{Task, TaskStatus};
use std::fmt;
use uuid::Uuid;

pub trait Filter: CloneFilter {
    fn validate_task(&self, task: &Task) -> bool;
    fn add_children(&mut self, child: Box<dyn Filter>);
}

// This trait is needed to enable cloning of `dyn Filter`.
pub trait CloneFilter {
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
        self == other
    }
}

impl fmt::Display for dyn Filter {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "foo")
    }
}

impl std::fmt::Debug for Box<dyn Filter> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "foo")
    }
}

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
}

#[derive(Debug)]
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
}

impl CloneFilter for AndFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(AndFilter {
            children: self.children.to_owned(),
        })
    }
}

#[derive(Debug)]
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
}

impl CloneFilter for XorFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(XorFilter {
            children: self.children.to_owned(),
        })
    }
}

#[derive(Debug)]
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
}

impl CloneFilter for OrFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(OrFilter {
            children: self.children.to_owned(),
        })
    }
}

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
}

impl CloneFilter for StringFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(StringFilter {
            value: self.value.to_owned(),
        })
    }
}

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
}

impl CloneFilter for StatusFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(StatusFilter {
            status: self.status.to_owned(),
        })
    }
}


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
}

impl CloneFilter for TagFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(TagFilter {
            include: self.include.to_owned(),
            tag_name: self.tag_name.to_owned(),
        })
    }
}

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
}

impl CloneFilter for UuidFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(UuidFilter {
            uuid: self.uuid.to_owned(),
        })
    }
}

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
