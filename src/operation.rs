use std::collections::HashMap;
use std::any::Any;
use uuid::Uuid;
use serde::{Serialize,Deserialize};

#[derive(Clone,Serialize,Deserialize)]
pub struct Operation {
    pub id: Uuid,
	pub input: HashMap<String, Vec<u8>>,
	pub output: HashMap<String, Vec<u8>>,
}

pub trait GenerateOperation {
    // This generates the operation required to changing self into other
    fn generate_operation<T: Any>(&self, other: &dyn Any) -> Operation;

    // TODO: Conflict in case of Err?
	fn apply_operation(&mut self, operation: &Operation) -> Result<(), String>;
}

impl Default for Operation {
    fn default() -> Self {
        return Operation {
            id: Uuid::new_v4(),
            input: HashMap::default(),
            output: HashMap::default(),
        }
    }
}
