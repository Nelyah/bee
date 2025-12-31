use chrono::prelude::DateTime;
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use serde_json::Value;

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
    /// `Option<Project>`
    #[serde(
        default,
        skip_serializing_if = "is_project_absent",
        serialize_with = "serialize_project",
        deserialize_with = "deserialize_project"
    )]
    pub(crate) project: Option<Option<Project>>,
    #[serde(default)]
    pub(crate) date_due: Option<DateTime<chrono::Local>>,
    pub(crate) depends_on: Option<Vec<DependsOnIdentifier>>,
    pub(crate) blocks: Option<Vec<DependsOnIdentifier>>,
}

fn is_project_absent(project: &Option<Option<Project>>) -> bool {
    project.is_none()
}

fn serialize_project<S>(project: &Option<Option<Project>>, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    match project {
        None => serializer.serialize_none(),
        Some(None) => serializer.serialize_str("none"),
        Some(Some(project)) => project.serialize(serializer),
    }
}

fn deserialize_project<'de, D>(deserializer: D) -> Result<Option<Option<Project>>, D::Error>
where
    D: Deserializer<'de>,
{
    let value = Option::<Value>::deserialize(deserializer)?;
    match value {
        None => Ok(None),
        Some(Value::Null) => Ok(Some(None)),
        Some(Value::String(text)) => {
            if text.eq_ignore_ascii_case("none") {
                Ok(Some(None))
            } else {
                Ok(Some(Some(Project::from(text))))
            }
        }
        Some(Value::Object(map)) => {
            let project: Project =
                serde_json::from_value(Value::Object(map)).map_err(serde::de::Error::custom)?;
            Ok(Some(Some(project)))
        }
        Some(other) => Err(serde::de::Error::custom(format!(
            "invalid project value: {other}"
        ))),
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn project_serialization_omits_absent_and_encodes_none() {
        let mut props = TaskProperties::default();
        let value = serde_json::to_value(&props).expect("serialize properties");
        let obj = value.as_object().expect("properties should be object");
        assert!(!obj.contains_key("project"));

        props.project = Some(None);
        let value = serde_json::to_value(&props).expect("serialize properties");
        assert_eq!(
            value.get("project"),
            Some(&Value::String("none".to_string()))
        );
    }

    #[test]
    fn project_deserialization_accepts_none_string() {
        let value = serde_json::json!({ "project": "none" });
        let props: TaskProperties = serde_json::from_value(value).expect("deserialize");
        assert_eq!(props.project, Some(None));
    }
}
