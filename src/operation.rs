use std::collections::HashMap;
use std::any::Any;
use serde::{Serialize,Deserialize};

#[derive(Default,Serialize,Deserialize)]
pub struct Operation {
	// client_id: String,
	pub input: HashMap<String, Vec<u8>>,
	pub output: HashMap<String, Vec<u8>>,
}

pub trait GenerateOperation {
    // This generates the operation required to changing self into other
    fn generate_operation<T: Any>(&self, other: &dyn Any) -> Operation;

    // TODO: Conflict in case of Err?
	fn apply_operation(&mut self, operation: Operation) -> Result<(), String>;
}

