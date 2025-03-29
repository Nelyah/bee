use chrono::{DateTime, Local};
use log::{debug, trace, warn};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::{any::Any, fmt};
use uuid::Uuid;

use super::{CloneFilter, Filter};
use crate::task::{Project, Task, TaskStatus};

#[derive(PartialEq, Debug)]
pub enum FilterKind {
    And,
    Or,
    Root,
    Status,
    Project,
    DateEnd,
    DateCreated,
    DateDue,
    String,
    Tag,
    TaskId,
    DependsOn,
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
            FilterKind::Project => write!(f, "Project"),
            FilterKind::DateEnd => write!(f, "DateEnd"),
            FilterKind::DateCreated => write!(f, "DateCreated"),
            FilterKind::DateDue => write!(f, "DateDue"),
            FilterKind::String => write!(f, "String"),
            FilterKind::Tag => write!(f, "Tag"),
            FilterKind::TaskId => write!(f, "TaskId"),
            FilterKind::DependsOn => write!(f, "DependsOn"),
            FilterKind::Uuid => write!(f, "Uuid"),
            FilterKind::Xor => write!(f, "Xor"),
        }
    }
}

pub trait FilterKindGetter {
    fn get_kind(&self) -> FilterKind;
}

macro_rules! impl_display_and_debug {
    ($($t:ty),*) => {
        $(
            impl fmt::Display for $t {
                fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                    self.format_helper(f)
                }
            }
            impl fmt::Debug for $t {
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
    ProjectFilter,
    StatusFilter,
    DateEndFilter,
    DateCreatedFilter,
    DateDueFilter,
    StringFilter,
    TagFilter,
    TaskIdFilter,
    DependsOnFilter,
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

#[derive(PartialEq, Deserialize, Serialize)]
pub struct RootFilter {}

impl CloneFilter for RootFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(RootFilter {})
    }
}

#[typetag::serde]
impl Filter for RootFilter {
    fn validate_task(&self, _task: &Task) -> bool {
        true
    }

    fn add_children(&mut self, _child: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a RootFilter");
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for RootFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::Root
    }
}

impl RootFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.get_kind())
    }
}

#[derive(PartialEq, Deserialize, Serialize)]
pub struct AndFilter {
    pub children: Vec<Box<dyn Filter>>,
}

#[typetag::serde(name = "AndFilter")]
impl Filter for AndFilter {
    fn validate_task(&self, task: &Task) -> bool {
        for child in &self.children {
            if child.get_kind() == FilterKind::Root {
                continue;
            }
            if !child.validate_task(task) {
                return false;
            }
        }
        true
    }

    fn add_children(&mut self, child: Box<dyn Filter>) {
        self.children.push(child);
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, id_to_uuid: &HashMap<usize, Uuid>) {
        for child in &mut self.children {
            child.convert_id_to_uuid(id_to_uuid);
        }
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(
            std::iter::once(self as &dyn Filter)
                .chain(self.children.iter().flat_map(|child| child.iter())),
        )
    }
}

impl FilterKindGetter for AndFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::And
    }
}

impl AndFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut children_string = String::default();
        let mut first = true;
        for c in &self.children {
            if !first {
                children_string += "\n";
            }
            children_string += &c.to_string();
            first = false;
        }
        write!(
            f,
            "{}:\n{}",
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

#[derive(PartialEq, Deserialize, Serialize)]
pub struct XorFilter {
    pub children: Vec<Box<dyn Filter>>,
}

#[typetag::serde]
impl Filter for XorFilter {
    fn validate_task(&self, task: &Task) -> bool {
        let mut valid_count = 0;
        for child in &self.children {
            if child.get_kind() == FilterKind::Root {
                continue;
            }
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

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, id_to_uuid: &HashMap<usize, Uuid>) {
        for child in &mut self.children {
            child.convert_id_to_uuid(id_to_uuid);
        }
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(
            std::iter::once(self as &dyn Filter)
                .chain(self.children.iter().flat_map(|child| child.iter())),
        )
    }
}

impl FilterKindGetter for XorFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::Xor
    }
}

impl XorFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut children_string = String::default();
        let mut first = true;
        for c in &self.children {
            if !first {
                children_string += "\n";
            }
            children_string += &format!("{}", c);
            first = false;
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

#[derive(PartialEq, Deserialize, Serialize)]
pub struct OrFilter {
    pub children: Vec<Box<dyn Filter>>,
}

#[typetag::serde]
impl Filter for OrFilter {
    fn validate_task(&self, task: &Task) -> bool {
        for child in &self.children {
            if child.get_kind() == FilterKind::Root {
                continue;
            }
            if child.validate_task(task) {
                return true;
            }
        }
        false
    }

    fn add_children(&mut self, child: Box<dyn Filter>) {
        self.children.push(child);
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, id_to_uuid: &HashMap<usize, Uuid>) {
        for child in &mut self.children {
            child.convert_id_to_uuid(id_to_uuid);
        }
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(
            std::iter::once(self as &dyn Filter)
                .chain(self.children.iter().flat_map(|child| child.iter())),
        )
    }
}

impl FilterKindGetter for OrFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::Or
    }
}

impl OrFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut children_string = String::default();
        let mut first = true;
        for c in &self.children {
            if !first {
                children_string += "\n";
            }
            children_string += &format!("{}", c);
            first = false;
        }
        write!(
            f,
            "{}:\n{}",
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

#[derive(PartialEq, Deserialize, Serialize)]
pub struct StringFilter {
    pub value: String,
}

#[typetag::serde]
impl Filter for StringFilter {
    fn validate_task(&self, task: &Task) -> bool {
        task.get_summary()
            .to_lowercase()
            .contains(&self.value.to_lowercase())
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a StringFilter");
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for StringFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::String
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

#[derive(PartialEq, Eq, Deserialize, Serialize)]
pub struct DateCreatedFilter {
    pub time: DateTime<Local>,
    pub before: bool,
}

#[typetag::serde]
impl Filter for DateCreatedFilter {
    fn validate_task(&self, task: &Task) -> bool {
        if self.before {
            return task.get_date_created() < &self.time;
        }
        task.get_date_created() >= &self.time
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a DateCreatedFilter");
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for DateCreatedFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::DateCreated
    }
}

impl DateCreatedFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let before = if self.before { "before" } else { "after" };
        write!(f, "{}: {}: {}", self.get_kind(), before, &self.time)
    }
}

impl CloneFilter for DateCreatedFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(DateCreatedFilter {
            time: self.time.to_owned(),
            before: self.before.to_owned(),
        })
    }
}

#[derive(PartialEq, Eq, Deserialize, Serialize)]
pub struct DateDueFilter {
    pub time: DateTime<Local>,
    pub type_when: DateDueFilterType,
}

#[derive(PartialEq, Eq, Clone, Deserialize, Serialize)]
pub enum DateDueFilterType {
    /// Check if the task is due any time during the day
    Day,
    Before,
    After,
}

#[typetag::serde]
impl Filter for DateDueFilter {
    fn validate_task(&self, task: &Task) -> bool {
        trace!("Validating task: {:?}", task);
        if task.get_date_due().is_none() {
            return false;
        }

        match self.type_when {
            DateDueFilterType::Day => {
                let task_date = task.get_date_due().unwrap().date_naive();
                let filter_date = self.time.date_naive();
                task_date == filter_date
            }
            DateDueFilterType::Before => task.get_date_due().unwrap() < self.time,
            DateDueFilterType::After => task.get_date_due().unwrap() >= self.time,
        }
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a DateDueFilter");
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for DateDueFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::DateDue
    }
}

impl DateDueFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let due_type = match self.type_when {
            DateDueFilterType::Day => "day",
            DateDueFilterType::Before => "before",
            DateDueFilterType::After => "after",
        };
        write!(f, "{}: {}: {}", self.get_kind(), due_type, &self.time)
    }
}

impl CloneFilter for DateDueFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(DateDueFilter {
            time: self.time.to_owned(),
            type_when: self.type_when.to_owned(),
        })
    }
}

#[derive(PartialEq, Eq, Deserialize, Serialize)]
pub struct DateEndFilter {
    pub time: DateTime<Local>,
    pub before: bool,
}

#[typetag::serde]
impl Filter for DateEndFilter {
    fn validate_task(&self, task: &Task) -> bool {
        if let Some(d) = task.get_date_completed() {
            if self.before {
                debug!("Checking task has end before");
                return d < &self.time;
            }
            return d >= &self.time;
        }
        false
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a DateEndFilter");
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for DateEndFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::DateEnd
    }
}

impl DateEndFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let before = if self.before { "before" } else { "after" };
        write!(f, "{}: {}: {}", self.get_kind(), before, &self.time)
    }
}

impl CloneFilter for DateEndFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(DateEndFilter {
            time: self.time.to_owned(),
            before: self.before.to_owned(),
        })
    }
}

#[derive(PartialEq, Deserialize, Serialize)]
pub struct ProjectFilter {
    pub name: Project,
}

#[typetag::serde]
impl Filter for ProjectFilter {
    fn validate_task(&self, task: &Task) -> bool {
        if let Some(p) = task.get_project() {
            return p.get_name().starts_with(self.name.get_name().as_str());
        }
        false
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a ProjectFilter");
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for ProjectFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::Project
    }
}

impl ProjectFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.get_kind(), &self.name)
    }
}

impl CloneFilter for ProjectFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(ProjectFilter {
            name: self.name.to_owned(),
        })
    }
}

#[derive(PartialEq, Deserialize, Serialize)]
pub struct StatusFilter {
    pub status: TaskStatus,
}

#[typetag::serde]
impl Filter for StatusFilter {
    fn validate_task(&self, task: &Task) -> bool {
        &self.status == task.get_status()
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a StatusFilter");
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for StatusFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::Status
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

#[derive(PartialEq, Deserialize, Serialize)]
pub struct TagFilter {
    pub include: bool,
    pub tag_name: String,
}

#[typetag::serde]
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

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for TagFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::Tag
    }
}

impl TagFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let include_str = if self.include { "include" } else { "exclude" };
        write!(f, "{}: {}={}", self.get_kind(), &self.tag_name, include_str,)
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

#[derive(PartialEq, Deserialize, Serialize)]
pub struct UuidFilter {
    pub uuid: Uuid,
}

#[typetag::serde]
impl Filter for UuidFilter {
    fn validate_task(&self, task: &Task) -> bool {
        &self.uuid == task.get_uuid()
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a UuidFilter");
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for UuidFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::Uuid
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

#[derive(PartialEq, Deserialize, Serialize)]
pub struct TaskIdFilter {
    pub id: usize,
}

#[typetag::serde]
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

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, _id_to_uuid: &HashMap<usize, Uuid>) {}

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for TaskIdFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::TaskId
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

#[derive(PartialEq, Deserialize, Serialize)]
pub struct DependsOnFilter {
    pub id: Option<usize>,
    pub uuid: Option<Uuid>,
}

#[typetag::serde]
impl Filter for DependsOnFilter {
    fn validate_task(&self, task: &Task) -> bool {
        if let Some(uuid) = &self.uuid {
            return task.depends_on(uuid);
        }

        unreachable!("Trying to validate a DependsOn filter without a UUID");
    }

    fn add_children(&mut self, _: Box<dyn Filter>) {
        unreachable!("Trying to add a child to a DependsOnFilter");
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn convert_id_to_uuid(&mut self, id_to_uuid: &HashMap<usize, Uuid>) {
        if self.uuid.is_some() {
            debug!("DependsOnFilter already has a UUID, no need to update it.");
            return;
        }

        if let Some(id) = &self.id {
            if let Some(uuid) = id_to_uuid.get(id) {
                self.uuid = Some(uuid.to_owned());
            } else {
                warn!(
                    "Trying to map id {} in DependsOnFilter but couldn't find a matching UUID",
                    id
                );
            }
        }
    }

    fn iter(&self) -> Box<dyn Iterator<Item = &dyn Filter> + '_> {
        Box::new(std::iter::once(self as &dyn Filter))
    }
}

impl FilterKindGetter for DependsOnFilter {
    fn get_kind(&self) -> FilterKind {
        FilterKind::DependsOn
    }
}

impl DependsOnFilter {
    fn format_helper(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let uuid_string = if let Some(uuid) = &self.uuid {
            uuid.to_string()
        } else {
            "None".to_string()
        };

        let id_string = if let Some(id) = &self.id {
            id.to_string()
        } else {
            "None".to_string()
        };
        write!(
            f,
            "{}: id({}), uuid({})",
            self.get_kind(),
            id_string,
            uuid_string
        )
    }
}

impl CloneFilter for DependsOnFilter {
    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(DependsOnFilter {
            id: self.id.to_owned(),
            uuid: self.uuid.to_owned(),
        })
    }
}
