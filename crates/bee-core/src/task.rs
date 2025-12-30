#[path = "task_data.rs"]
mod task_data;
#[path = "task_model.rs"]
mod task_model;
#[path = "task/task_prop_parser.rs"]
mod task_prop_parser;
#[path = "task_properties.rs"]
mod task_properties;

pub use task_data::TaskData;
pub use task_model::{
    ActionUndo, ActionUndoType, DependsOnIdentifier, Link, LinkType, Project, Task, TaskAnnotation,
    TaskHistory, TaskStatus,
};
pub use task_properties::TaskProperties;

#[path = "task_test.rs"]
#[cfg(test)]
mod task_test;

#[cfg(test)]
#[path = "manager_test.rs"]
mod manager_test;

#[cfg(test)]
#[path = "task/task_prop_parser_test.rs"]
mod task_prop_parser_test;
