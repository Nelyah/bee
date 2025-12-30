use chrono::prelude::DateTime;
use serde::{Deserialize, Serialize};

use super::task_prop_parser::TaskPropertyParser;
use super::{DependsOnIdentifier, Project, TaskAnnotation, TaskStatus};
use crate::CoreResult;
use crate::lexer::Lexer;

/// This structure contains information regarding setting fields for a Task
/// that can be parsed from a user query, i.e. from the command line
/// It only contains the fields that can be set by a User
///
/// Tags are always FIRST removed, THEN applied
#[derive(Clone, Default, PartialEq, Debug, Serialize, Deserialize)]
pub struct TaskProperties {
    pub(crate) summary: Option<String>,
    pub(crate) tags_remove: Option<Vec<String>>,
    pub(crate) tags_add: Option<Vec<String>>,
    pub(crate) status: Option<TaskStatus>,
    /// Single annotation to ADD to a task
    pub(crate) annotation: Option<String>,
    /// Replace all of this task's annotations with the given vector
    pub(crate) annotations: Option<Vec<TaskAnnotation>>,
    pub(crate) active_status: Option<bool>,
    /// If presents, sets the task's project to the given
    /// Option<Project>
    pub(crate) project: Option<Option<Project>>,
    #[serde(default)]
    pub(crate) date_due: Option<DateTime<chrono::Local>>,
    pub(crate) depends_on: Option<Vec<DependsOnIdentifier>>,
    pub(crate) blocks: Option<Vec<DependsOnIdentifier>>,
}

// We implement a specific function for annotate because we cannot know how to differenciate
// it from a description
impl TaskProperties {
    pub fn set_annotate(&mut self, value: String) {
        self.annotation = Some(value);
    }

    pub fn set_annotations(&mut self, annotations: &Vec<TaskAnnotation>) {
        self.annotations = Some(annotations.to_owned());
    }

    pub fn set_summary(&mut self, summary: &str) {
        self.summary = Some(summary.to_string());
    }

    pub fn set_project(&mut self, project: &Option<Project>) {
        self.project = Some(project.clone());
    }

    pub fn add_depends_on(&mut self, identifier: &DependsOnIdentifier) {
        if self.depends_on.is_none() {
            self.depends_on = Some(Vec::new());
        }
        if let Some(depends) = &mut self.depends_on {
            depends.push(identifier.clone());
        }
    }

    /// Sets the vector of tags that should be removed
    pub fn set_tag_remove(&mut self, tags: &Vec<String>) {
        self.tags_remove = Some(tags.to_owned());
    }

    /// Sets the vector of tags that should be added
    pub fn set_tag_add(&mut self, tags: &Vec<String>) {
        self.tags_add = Some(tags.to_owned());
    }

    /// When applied, task status will be set to active
    ///
    /// This will ONLY impact tasks that are PENDING
    pub fn set_active_status(&mut self, status: bool) {
        self.active_status = Some(status);
    }

    pub fn from(values: &[String]) -> CoreResult<TaskProperties> {
        let lexer = Lexer::new(values.join(" "));
        let mut parser = TaskPropertyParser::new(lexer);
        parser.parse_task_properties()
    }

    pub fn get_referenced_tasks(&self) -> Vec<DependsOnIdentifier> {
        match &self.depends_on {
            Some(deps) => deps.to_owned(),
            None => Vec::default(),
        }
    }
}
