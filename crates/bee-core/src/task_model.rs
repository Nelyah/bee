use chrono::Local;
use chrono::prelude::DateTime;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use strum::{Display, EnumString};
use uuid::Uuid;

use std::collections::HashSet;
use std::{cmp::Ordering, fmt};

use super::task_properties::TaskProperties;
use crate::email_link::EmailLink;
use crate::important_link::ImportantLink;
use crate::{CoreError, CoreResult};

#[derive(
    Clone,
    Debug,
    PartialEq,
    serde::Serialize,
    serde::Deserialize,
    Default,
    Eq,
    PartialOrd,
    Ord,
    Hash,
)]
pub enum TaskStatus {
    #[default]
    Pending,
    Active,
    Completed,
    Deleted,
    Blocked,
}

impl TaskStatus {
    pub fn from_string(input: &str) -> CoreResult<TaskStatus> {
        match input.to_lowercase().as_str() {
            "active" => Ok(TaskStatus::Active),
            "pending" => Ok(TaskStatus::Pending),
            "completed" => Ok(TaskStatus::Completed),
            "deleted" => Ok(TaskStatus::Deleted),
            "blocked" => Ok(TaskStatus::Blocked),
            _ => Err(CoreError::task("Invalid task status name")),
        }
    }

    /// Returns the uppercase string representation used in the database
    pub fn to_db_string(&self) -> String {
        match self {
            TaskStatus::Active => "ACTIVE".to_string(),
            TaskStatus::Pending => "PENDING".to_string(),
            TaskStatus::Completed => "COMPLETED".to_string(),
            TaskStatus::Deleted => "DELETED".to_string(),
            TaskStatus::Blocked => "BLOCKED".to_string(),
        }
    }
}

impl fmt::Display for TaskStatus {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            TaskStatus::Active => write!(f, "active"),
            TaskStatus::Pending => write!(f, "pending"),
            TaskStatus::Completed => write!(f, "completed"),
            TaskStatus::Deleted => write!(f, "deleted"),
            TaskStatus::Blocked => write!(f, "blocked"),
        }
    }
}

#[derive(Display, EnumString, Default, Debug, PartialEq, Eq, Serialize, Deserialize, Clone)]
pub enum ActionUndoType {
    Add,
    #[default]
    Modify,
}

#[derive(Default, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ActionUndo {
    pub action_type: ActionUndoType,
    pub tasks: Vec<Task>,
}

#[derive(Clone, PartialEq, Debug, serde::Serialize, serde::Deserialize)]
pub enum DependsOnIdentifier {
    Id(i32),
    Uuid(Uuid),
}

#[derive(
    Clone,
    Debug,
    serde::Serialize,
    serde::Deserialize,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
    Hash,
    Default,
)]
pub struct TaskAnnotation {
    /// ID to serve as primary key in the DB
    pub(crate) id: Option<i32>,
    pub(crate) value: String,
    pub(crate) time: DateTime<chrono::Local>,
}

impl TaskAnnotation {
    pub fn get_value(&self) -> &String {
        &self.value
    }

    pub fn get_time(&self) -> &DateTime<chrono::Local> {
        &self.time
    }
}

#[derive(
    Display,
    EnumString,
    Clone,
    Debug,
    serde::Serialize,
    serde::Deserialize,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
    Hash,
)]
pub enum LinkType {
    /// Task A depends on Task B (A cannot proceed until B is done)
    /// Stored in DB. Inverse: Blocking
    DependsOn,
    /// Task A blocks Task B (B cannot proceed until A is done)
    /// Inferred at load time from DependsOn links pointing TO this task
    Blocking,
    /// Task A is the parent of Task B (hierarchical relationship)
    /// Stored in DB. Inverse: ChildOf
    ParentOf,
    /// Task A is a child of Task B (hierarchical relationship)
    /// Inferred at load time from ParentOf links pointing TO this task
    ChildOf,
    /// Task A is related to Task B (general association)
    /// Symmetric: stored once with canonical ordering (lower UUID = from)
    RelatedTo,
    /// Task A duplicates Task B (same work)
    /// Symmetric: stored once with canonical ordering (lower UUID = from)
    Duplicates,
}

impl LinkType {
    /// Returns the inverse link type (what the target task sees)
    pub fn inverse(&self) -> LinkType {
        match self {
            LinkType::DependsOn => LinkType::Blocking,
            LinkType::Blocking => LinkType::DependsOn,
            LinkType::ParentOf => LinkType::ChildOf,
            LinkType::ChildOf => LinkType::ParentOf,
            // Symmetric types are their own inverse
            LinkType::RelatedTo => LinkType::RelatedTo,
            LinkType::Duplicates => LinkType::Duplicates,
        }
    }

    /// Returns true if this link type is stored in the database
    /// (as opposed to being inferred at load time)
    pub fn is_canonical(&self) -> bool {
        matches!(
            self,
            LinkType::DependsOn | LinkType::ParentOf | LinkType::RelatedTo | LinkType::Duplicates
        )
    }

    /// Returns true if this link type is symmetric (same in both directions)
    pub fn is_symmetric(&self) -> bool {
        matches!(self, LinkType::RelatedTo | LinkType::Duplicates)
    }

    /// Returns the database string representation for storage
    pub fn to_db_string(&self) -> &'static str {
        match self {
            LinkType::DependsOn => "DependsOn",
            LinkType::Blocking => "DependsOn", // Stored as DependsOn with swapped from/to
            LinkType::ParentOf => "ParentOf",
            LinkType::ChildOf => "ParentOf", // Stored as ParentOf with swapped from/to
            LinkType::RelatedTo => "RelatedTo",
            LinkType::Duplicates => "Duplicates",
        }
    }
}

#[derive(
    Clone, Debug, serde::Serialize, serde::Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash,
)]
pub struct Link {
    /// ID to serve as primary key in the DB
    pub(crate) id: Option<i32>,
    pub(crate) from: Uuid,
    pub(crate) to: Uuid,
    pub(crate) link_type: LinkType,
}

impl Link {
    /// Creates a new link with the given parameters
    pub fn new(from: Uuid, to: Uuid, link_type: LinkType) -> Self {
        Link {
            id: None,
            from,
            to,
            link_type,
        }
    }

    /// Creates a link in canonical form for storage.
    /// For symmetric types (RelatedTo, Duplicates), ensures lower UUID is always 'from'.
    /// For asymmetric types, returns the link as-is if canonical, or swaps and inverts if not.
    pub fn to_canonical(self) -> Self {
        if self.link_type.is_symmetric() {
            // For symmetric types, canonical form has lower UUID as 'from'
            if self.from > self.to {
                Link {
                    id: self.id,
                    from: self.to,
                    to: self.from,
                    link_type: self.link_type, // Same for symmetric
                }
            } else {
                self
            }
        } else if self.link_type.is_canonical() {
            // Already canonical
            self
        } else {
            // Convert inferred type to canonical by swapping direction
            // e.g., Blocking(A->B) becomes DependsOn(B->A)
            Link {
                id: self.id,
                from: self.to,
                to: self.from,
                link_type: self.link_type.inverse(),
            }
        }
    }

    /// Returns the link type
    pub fn get_link_type(&self) -> &LinkType {
        &self.link_type
    }

    /// Returns the target UUID (the task this link points to)
    pub fn get_target(&self) -> &Uuid {
        &self.to
    }

    /// Returns the source UUID (the task this link originates from)
    pub fn get_source(&self) -> &Uuid {
        &self.from
    }
}

#[derive(
    Clone,
    Debug,
    serde::Serialize,
    serde::Deserialize,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
    Hash,
    Default,
)]
pub struct TaskHistory {
    /// ID to serve as primary key in the DB
    pub(crate) id: Option<i32>,
    pub(crate) value: String,
    /// Accepts both "datetime" (current) and "time" (pre-database migration exports)
    #[serde(alias = "time")]
    pub(crate) datetime: DateTime<chrono::Local>,
}

impl TaskHistory {
    pub fn get_value(&self) -> &String {
        &self.value
    }

    pub fn get_datetime(&self) -> &DateTime<chrono::Local> {
        &self.datetime
    }
}

#[derive(
    Clone, Debug, serde::Serialize, serde::Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash,
)]
pub struct Task {
    pub(crate) id: Option<i32>,
    pub(crate) db_id: Option<i32>,
    pub(crate) status: TaskStatus,
    pub(crate) uuid: Uuid,
    pub(crate) summary: String,
    #[serde(default)]
    pub(crate) annotations: Vec<TaskAnnotation>,
    #[serde(default)]
    pub(crate) tags: Vec<String>,
    pub(crate) date_created: DateTime<chrono::Local>,
    pub(crate) date_completed: Option<DateTime<chrono::Local>>,
    pub(crate) date_due: Option<DateTime<chrono::Local>>,
    pub(crate) date_planned: Option<DateTime<chrono::Local>>,
    pub(crate) urgency: Option<i64>,
    pub(crate) project: Option<Project>,
    #[serde(default)]
    pub(crate) links: Vec<Link>,
    #[serde(default)]
    pub(crate) history: Vec<TaskHistory>,
    #[serde(default)]
    pub(crate) email_links: Vec<crate::email_link::EmailLink>,
    #[serde(default)]
    pub(crate) important_links: Vec<ImportantLink>,
}

impl Default for Task {
    fn default() -> Task {
        Task {
            id: None,
            db_id: None,
            status: TaskStatus::Pending,
            uuid: Uuid::new_v4(),
            summary: "".to_string(),
            annotations: Vec::default(),
            tags: Vec::default(),
            date_created: Local::now(),
            date_completed: None,
            date_due: None,
            date_planned: None,
            urgency: None,
            project: None,
            links: Vec::default(),
            history: Vec::default(),
            email_links: Vec::default(),
            important_links: Vec::default(),
        }
    }
}

impl Task {
    pub fn get_id(&self) -> Option<i32> {
        self.id
    }

    pub fn get_depends_on(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|link| link.link_type == LinkType::DependsOn)
            .map(|link| &link.to)
            .collect()
    }

    pub fn depends_on(&self, uuid: &Uuid) -> bool {
        self.get_depends_on().contains(&uuid)
    }

    pub fn get_blocking(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|link| link.link_type == LinkType::Blocking)
            .map(|link| &link.to)
            .collect()
    }

    /// Get UUIDs of tasks that this task is a parent of
    pub fn get_parent_of(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|link| link.link_type == LinkType::ParentOf)
            .map(|link| &link.to)
            .collect()
    }

    /// Get UUIDs of tasks that this task is a child of
    pub fn get_child_of(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|link| link.link_type == LinkType::ChildOf)
            .map(|link| &link.to)
            .collect()
    }

    /// Get UUIDs of tasks that this task is related to
    pub fn get_related_to(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|link| link.link_type == LinkType::RelatedTo)
            .map(|link| &link.to)
            .collect()
    }

    /// Get UUIDs of tasks that this task duplicates
    pub fn get_duplicates(&self) -> Vec<&Uuid> {
        self.links
            .iter()
            .filter(|link| link.link_type == LinkType::Duplicates)
            .map(|link| &link.to)
            .collect()
    }

    /// Get all links for this task
    pub fn get_links(&self) -> &Vec<Link> {
        &self.links
    }

    pub fn has_property(&self, prop: &str) -> bool {
        let p = prop.to_lowercase();
        match p.as_str() {
            "active" => self.status == TaskStatus::Active,
            "pending" => self.status == TaskStatus::Pending,
            "completed" => self.status == TaskStatus::Completed,
            "deleted" => self.status == TaskStatus::Deleted,
            "blocked" => self.status == TaskStatus::Blocked,
            _ => false,
        }
    }

    pub fn compare_urgency(&self, other: &Task) -> Ordering {
        match self.urgency {
            Some(urgency) => match other.urgency {
                Some(other_urgency) => urgency.cmp(&other_urgency),
                None => Ordering::Greater,
            },
            None => match other.urgency {
                Some(_) => Ordering::Less,
                None => Ordering::Equal,
            },
        }
    }

    pub fn compute_urgency(&mut self) -> CoreResult<i64> {
        self.compute_urgency_with_config(&crate::urgency::UrgencyConfig::default(), &[])
    }

    /// Compute urgency with custom configuration and external links.
    ///
    /// This is the full implementation that considers all urgency factors:
    /// - Due date proximity (overdue = highest urgency)
    /// - Blocking relationships (unblock others first)
    /// - Activity momentum (recent work = keep going)
    /// - Age (old tasks need attention)
    /// - Staleness (abandoned tasks deprioritized)
    /// - Status (active boosted, blocked deprioritized)
    /// - Tags (user priority markers)
    /// - External links (GitLab/Jira activity)
    pub fn compute_urgency_with_config(
        &mut self,
        config: &crate::urgency::UrgencyConfig,
        external_links: &[crate::external_links::ExternalLink],
    ) -> CoreResult<i64> {
        use crate::urgency;
        use chrono::Local;

        // Non-actionable tasks have no urgency
        if self.status == TaskStatus::Deleted || self.status == TaskStatus::Completed {
            self.urgency = None;
            return Ok(0);
        }

        let now = Local::now();

        // === Calculate derived metrics ===

        // Age in days (time since creation)
        let age_days = now.signed_duration_since(self.date_created).num_seconds() as f64 / 86400.0;

        // Last activity time (from history, or fall back to creation date)
        let last_activity = self
            .history
            .iter()
            .map(|h| *h.get_datetime())
            .max()
            .unwrap_or(self.date_created);
        let days_since_last_activity =
            now.signed_duration_since(last_activity).num_seconds() as f64 / 86400.0;

        // Activity count in last 7 days
        let seven_days_ago = now - chrono::Duration::days(7);
        let updates_last_7d = self
            .history
            .iter()
            .filter(|h| *h.get_datetime() > seven_days_ago)
            .count();

        // Count of tasks this task is blocking
        let blocking_count = self.get_blocking().len();

        // Days until due (negative if overdue)
        let days_until_due: Option<f64> = self
            .date_due
            .map(|due| due.signed_duration_since(now).num_seconds() as f64 / 86400.0);

        // Tags as slice of strings
        let tags: Vec<String> = self.tags.to_vec();

        // === Compute components ===

        let due = match days_until_due {
            Some(days) => urgency::due_component(days, config),
            None => 0,
        };

        let blocking = urgency::blocking_component(blocking_count, config);

        let activity =
            urgency::activity_component(days_since_last_activity, updates_last_7d, config);

        let age = urgency::age_component(age_days, config);

        let staleness = urgency::staleness_penalty(days_since_last_activity, age_days, config);

        let status = urgency::status_modifier(self.status.clone(), config);

        let tag_score = urgency::tag_modifier(&tags, config);

        let external = urgency::external_link_component(external_links, config);

        // === Final calculation ===
        let total_urgency =
            due + blocking + activity + age + staleness + status + tag_score + external;

        self.urgency = Some(total_urgency);
        Ok(total_urgency)
    }

    pub fn get_history(&self) -> &Vec<TaskHistory> {
        &self.history
    }

    pub fn get_email_links(&self) -> &Vec<crate::email_link::EmailLink> {
        &self.email_links
    }

    pub fn get_important_links(&self) -> &Vec<ImportantLink> {
        &self.important_links
    }

    pub fn get_annotations(&self) -> &Vec<TaskAnnotation> {
        &self.annotations
    }

    pub fn get_summary(&self) -> &str {
        &self.summary
    }

    #[cfg(test)]
    pub fn set_summary(&mut self, value: &str) {
        self.summary = value.to_owned();
    }

    pub fn get_tags(&self) -> &Vec<String> {
        &self.tags
    }

    pub fn get_project(&self) -> &Option<Project> {
        &self.project
    }

    pub fn get_status(&self) -> &TaskStatus {
        &self.status
    }

    pub fn get_date_created(&self) -> &DateTime<Local> {
        &self.date_created
    }

    pub fn get_date_completed(&self) -> &Option<DateTime<Local>> {
        &self.date_completed
    }

    pub fn get_date_due(&self) -> &Option<DateTime<Local>> {
        &self.date_due
    }

    pub fn get_date_planned(&self) -> &Option<DateTime<Local>> {
        &self.date_planned
    }

    pub fn get_urgency(&self) -> &Option<i64> {
        &self.urgency
    }

    pub fn get_uuid(&self) -> &Uuid {
        &self.uuid
    }

    /// Send back a list of all UUIDs that this task references via links
    pub fn get_extra_uuid(&self) -> Vec<Uuid> {
        let mut uuids: Vec<Uuid> = self.links.iter().map(|link| link.to).collect();
        uuids.sort_unstable();
        uuids.dedup();
        uuids
    }

    pub(crate) fn apply(&mut self, props: &TaskProperties) -> CoreResult<()> {
        if let Some(summary) = &props.summary {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: format!("Summary changed from '{}' to '{}'.", self.summary, summary),
            });
            self.summary = summary.clone();
        }

        if let Some(date_due) = &props.date_due {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: format!("Due date set to {}", date_due),
            });
            self.date_due = Some(date_due.to_owned());
        }

        if let Some(date_planned) = &props.date_planned {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: format!("Planned date set to {}", date_planned),
            });
            self.date_planned = Some(date_planned.to_owned());
        }

        if let Some(active) = &props.active_status {
            if *active {
                if self.status != TaskStatus::Pending {
                    return Err(CoreError::task(format!(
                        "Task '{}' status cannot be set to 'ACTIVE' because its status is already 'ACTIVE'",
                        self.summary
                    )));
                }
                self.status = TaskStatus::Active;
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: "Status changed from 'PENDING' to 'ACTIVE'".to_string(),
                });
            } else {
                if self.status != TaskStatus::Active {
                    return Err(CoreError::task(format!(
                        "Task '{}' status cannot be 'stopped' because its status is not 'ACTIVE'",
                        self.summary
                    )));
                }
                self.status = TaskStatus::Pending;
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: "Status changed from 'ACTIVE' to 'PENDING'".to_string(),
                });
            }
        }

        if let Some(status) = &props.status {
            if &self.status != status {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!("Status changed from '{}' to '{}'", self.status, status),
                });
            }
            self.status = status.to_owned();
        }

        if let Some(proj_option) = &props.project {
            if let Some(proj) = proj_option {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!("Project set to '{}'", proj),
                });
                self.project = Some(proj.to_owned());
            } else {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: "Project has been unset".to_string(),
                });
                self.project = None;
            }
        }

        if let Some(tags) = &props.tags_remove {
            let s: HashSet<String> = tags.iter().cloned().collect();
            let mut removed_tags: Vec<String> = Vec::new();
            self.tags.retain(|item| {
                if s.contains(item) {
                    removed_tags.push(item.clone());
                    false
                } else {
                    true
                }
            });

            if !removed_tags.is_empty() {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!("Removed tag(s) '{}'", removed_tags.join(", ")),
                });
            }
        }

        if let Some(tags) = &props.tags_add {
            let existing_tags: HashSet<String> = self.tags.drain(..).collect();
            let new_tags: HashSet<String> = tags.iter().cloned().collect();
            self.tags = existing_tags.union(&new_tags).cloned().collect();

            let tags_added: HashSet<String> =
                new_tags.difference(&existing_tags).cloned().collect();
            if !tags_added.is_empty() {
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!(
                        "Added tag(s) '{}'",
                        tags_added
                            .iter()
                            .cloned()
                            .collect::<Vec<String>>()
                            .join(", ")
                    ),
                });
            }
        }

        if let Some(ann) = &props.annotation {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: format!("Added an annotation '{}'", ann),
            });
            self.annotations.push(TaskAnnotation {
                id: None,
                value: ann.to_string(),
                time: Local::now(),
            });
        }

        if let Some(annotations) = &props.annotations {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: "The list of annotations have been changed".to_string(),
            });
            self.annotations = annotations.to_owned();
        }

        if let Some(depends_on) = &props.depends_on {
            let mut deps_set = HashSet::<Uuid>::new();

            // If the vector is empty, it's because we want to cancel all dependencies
            // for the task. In which case just don't add any. This will update the
            // task to not have any dependencies
            if !depends_on.is_empty() {
                self.get_depends_on().iter().for_each(|&uuid| {
                    deps_set.insert(uuid.to_owned());
                });
            }
            for dep in depends_on {
                match dep {
                    DependsOnIdentifier::Id(_) => {
                        unreachable!(
                            "We should not have a usize here. \
                            We should have converted it to a UUID before applying \
                            the properties to the task."
                        );
                    }
                    DependsOnIdentifier::Uuid(uuid) => {
                        if deps_set.contains(uuid) {
                            continue;
                        }
                        self.history.push(TaskHistory {
                            id: None,
                            datetime: Local::now(),
                            value: format!("Added a UUID to depend on: '{}'", uuid),
                        });
                        self.links.push(Link {
                            id: None,
                            from: self.uuid,
                            to: uuid.to_owned(),
                            link_type: LinkType::DependsOn,
                        });
                        deps_set.insert(uuid.to_owned());
                    }
                }
            }
        }
        if let Some(blocks) = &props.blocks {
            let mut deps_set = HashSet::<Uuid>::new();

            // If the vector is empty, it's because we want to cancel all dependencies
            // for the task. In which case just don't add any. This will update the
            // task to not have any dependencies
            if !blocks.is_empty() {
                self.get_blocking().iter().for_each(|&uuid| {
                    deps_set.insert(uuid.to_owned());
                });
            }
            for dep in blocks {
                match dep {
                    DependsOnIdentifier::Id(_) => {
                        unreachable!(
                            "We should not have a usize here. \
                            We should have converted it to a UUID before applying \
                            the properties to the task."
                        );
                    }
                    DependsOnIdentifier::Uuid(uuid) => {
                        if deps_set.contains(uuid) {
                            continue;
                        }
                        self.history.push(TaskHistory {
                            id: None,
                            datetime: Local::now(),
                            value: format!("Added a UUID to block: '{}'", uuid),
                        });
                        self.links.push(Link {
                            id: None,
                            from: self.uuid,
                            to: uuid.to_owned(),
                            link_type: LinkType::Blocking,
                        });
                        deps_set.insert(uuid.to_owned());
                    }
                }
            }
        }

        // Handle parent_of links
        if let Some(parent_of) = &props.parent_of {
            let mut existing = HashSet::<Uuid>::new();
            if !parent_of.is_empty() {
                self.get_parent_of().iter().for_each(|&uuid| {
                    existing.insert(uuid.to_owned());
                });
            }
            for item in parent_of {
                if let DependsOnIdentifier::Uuid(uuid) = item {
                    if existing.contains(uuid) {
                        continue;
                    }
                    self.history.push(TaskHistory {
                        id: None,
                        datetime: Local::now(),
                        value: format!("Added as parent of: '{}'", uuid),
                    });
                    self.links
                        .push(Link::new(self.uuid, *uuid, LinkType::ParentOf));
                    existing.insert(*uuid);
                }
            }
        }

        // Handle child_of links (inverse: will be stored as ParentOf from target to self)
        if let Some(child_of) = &props.child_of {
            let mut existing = HashSet::<Uuid>::new();
            if !child_of.is_empty() {
                self.get_child_of().iter().for_each(|&uuid| {
                    existing.insert(uuid.to_owned());
                });
            }
            for item in child_of {
                if let DependsOnIdentifier::Uuid(uuid) = item {
                    if existing.contains(uuid) {
                        continue;
                    }
                    self.history.push(TaskHistory {
                        id: None,
                        datetime: Local::now(),
                        value: format!("Added as child of: '{}'", uuid),
                    });
                    self.links
                        .push(Link::new(self.uuid, *uuid, LinkType::ChildOf));
                    existing.insert(*uuid);
                }
            }
        }

        // Handle related_to links (symmetric)
        if let Some(related_to) = &props.related_to {
            let mut existing = HashSet::<Uuid>::new();
            if !related_to.is_empty() {
                self.get_related_to().iter().for_each(|&uuid| {
                    existing.insert(uuid.to_owned());
                });
            }
            for item in related_to {
                if let DependsOnIdentifier::Uuid(uuid) = item {
                    if existing.contains(uuid) {
                        continue;
                    }
                    self.history.push(TaskHistory {
                        id: None,
                        datetime: Local::now(),
                        value: format!("Added as related to: '{}'", uuid),
                    });
                    self.links
                        .push(Link::new(self.uuid, *uuid, LinkType::RelatedTo));
                    existing.insert(*uuid);
                }
            }
        }

        // Handle duplicates links (symmetric)
        if let Some(duplicates) = &props.duplicates {
            let mut existing = HashSet::<Uuid>::new();
            if !duplicates.is_empty() {
                self.get_duplicates().iter().for_each(|&uuid| {
                    existing.insert(uuid.to_owned());
                });
            }
            for item in duplicates {
                if let DependsOnIdentifier::Uuid(uuid) = item {
                    if existing.contains(uuid) {
                        continue;
                    }
                    self.history.push(TaskHistory {
                        id: None,
                        datetime: Local::now(),
                        value: format!("Added as duplicate of: '{}'", uuid),
                    });
                    self.links
                        .push(Link::new(self.uuid, *uuid, LinkType::Duplicates));
                    existing.insert(*uuid);
                }
            }
        }

        // Handle email link removal by message_id
        if let Some(message_ids) = &props.email_link_remove {
            for msg_id in message_ids {
                if let Some(pos) = self
                    .email_links
                    .iter()
                    .position(|e| &e.message_id == msg_id)
                {
                    let removed = self.email_links.remove(pos);
                    self.history.push(TaskHistory {
                        id: None,
                        datetime: Local::now(),
                        value: format!("Removed email link: '{}'", removed.subject),
                    });
                }
            }
        }

        // Handle email link addition
        if let Some(input) = &props.email_link_add {
            // Check for duplicate message_id (avoid re-adding same email)
            if !self
                .email_links
                .iter()
                .any(|e| e.message_id == input.message_id)
            {
                let link = EmailLink::new(
                    input.message_id.clone(),
                    input.subject.clone(),
                    input.sender.clone(),
                    input.sent_date,
                );
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!("Added email link: '{}'", link.get_subject()),
                });
                self.email_links.push(link);
            }
        }

        // Handle attachment addition (history entry only - file data stored separately)
        if let Some(input) = &props.attachment_add {
            self.history.push(TaskHistory {
                id: None,
                datetime: Local::now(),
                value: format!("Added attachment: {}", input.filename),
            });
        }

        // Handle important link removal by URL
        if let Some(urls) = &props.important_link_remove {
            for url in urls {
                if let Some(pos) = self.important_links.iter().position(|l| &l.url == url) {
                    let removed = self.important_links.remove(pos);
                    self.history.push(TaskHistory {
                        id: None,
                        datetime: Local::now(),
                        value: format!("Removed important link: '{}'", removed.title),
                    });
                }
            }
        }

        // Handle important link addition
        if let Some(input) = &props.important_link_add {
            // Check for duplicate URL (avoid re-adding same link)
            if !self.important_links.iter().any(|l| l.url == input.url) {
                let link = ImportantLink::new(input.url.clone(), input.title.clone());
                self.history.push(TaskHistory {
                    id: None,
                    datetime: Local::now(),
                    value: format!("Added important link: '{}'", link.get_title()),
                });
                self.important_links.push(link);
            }
        }

        self.compute_urgency()?;
        Ok(())
    }

    /// Get the field of this task by name
    ///
    /// This serialises the task into JSON to then get the field name
    /// and deserialise it back. The name that we are looking is therefore
    /// the serialisation name
    pub fn get_field(&self, field_name: &str) -> Value {
        let v = serde_json::to_value(self).unwrap();
        if let Some(value) = v.get(field_name) {
            value.clone()
        } else {
            panic!("Could not get the value of '{}'", field_name);
        }
    }

    pub fn delete(&mut self) {
        self.history.push(TaskHistory {
            id: None,
            datetime: Local::now(),
            value: "Deleted task.".to_string(),
        });
        self.status = TaskStatus::Deleted;
        self.id = None;
        self.urgency = None;
    }

    pub fn done(&mut self) {
        let current_time = Local::now();
        self.history.push(TaskHistory {
            id: None,
            datetime: current_time,
            value: "Marked task as done".to_string(),
        });
        self.status = TaskStatus::Completed;
        self.date_completed = Some(current_time);
        self.id = None;
        self.urgency = None;
    }
}

#[derive(Clone, Default, Serialize, Deserialize, PartialEq, Debug, Eq, PartialOrd, Ord, Hash)]
pub struct Project {
    /// Primary key in the database
    pub(crate) id: Option<i32>,
    /// Name of the project.
    /// Dots (.) separate a project into sub projects
    /// a.project --> 'a' is a project with subproject 'a.project'
    pub(crate) name: String,
    /// Optional emoji for visual identification (single emoji character)
    pub(crate) emoji: Option<String>,
    /// Optional hex color for project theming (e.g., "#FF5733")
    pub(crate) color: Option<String>,
}

impl Project {
    pub fn get_name(&self) -> &String {
        &self.name
    }

    pub fn get_emoji(&self) -> &Option<String> {
        &self.emoji
    }

    pub fn get_color(&self) -> &Option<String> {
        &self.color
    }

    pub fn from(value: String) -> Project {
        Project {
            name: value,
            id: None,
            emoji: None,
            color: None,
        }
    }

    /// Create a project with all fields
    pub fn new(name: String, emoji: Option<String>, color: Option<String>) -> Project {
        Project {
            name,
            id: None,
            emoji,
            color,
        }
    }
}

impl fmt::Display for Project {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.name)
    }
}
