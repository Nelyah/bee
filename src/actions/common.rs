use crate::task::Task;
use serde::{Deserialize, Serialize};

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize, Clone)]
pub enum ActionUndoType {
    Add,
    Modify,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct ActionUndo {
    action_type: ActionUndoType,
    tasks: Vec<Task>,
}
