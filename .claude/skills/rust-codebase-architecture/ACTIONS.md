# Actions System

**Read this when:** Creating or modifying actions in bee-actions.

## Architecture

```
ActionRegistry
    │
    ├── ActionType enum (Add, Done, Edit, List, ...)
    │
    └── get_action() → Box<dyn TaskAction>
            │
            ├── AddTaskAction
            ├── DoneTaskAction
            ├── EditTaskAction
            ├── ListTaskAction
            └── ... (15 total)
```

## TaskAction Trait

```rust
// crates/bee-actions/src/lib.rs

pub trait TaskAction: Send + Sync {
    fn action_type(&self) -> ActionType;

    fn set_tasks(&mut self, tasks: TaskData);
    fn set_arguments(&mut self, args: Vec<String>);
    fn set_properties(&mut self, props: TaskProperties);

    fn do_action(&self, printer: &dyn Printer) -> ActionResult;

    fn get_modified_tasks(&self) -> Vec<Task>;
    fn get_undos(&self) -> Vec<ActionUndo>;
}
```

## Action Types (15)

| Action | Purpose | Creates Undo |
|--------|---------|--------------|
| `Add` | Create new task | Yes |
| `Annotate` | Add annotation to task | Yes |
| `Delete` | Mark task deleted | Yes |
| `Done` | Mark task completed | Yes |
| `Edit` | Interactive edit | Yes |
| `Export` | Export tasks to JSON | No |
| `Help` | Show help | No |
| `Import` | Import from JSON | Yes |
| `Info` | Show task details | No |
| `List` | List tasks | No |
| `Modify` | Modify task properties | Yes |
| `Start` | Mark task active | Yes |
| `Stop` | Mark task pending | Yes |
| `Undo` | Undo last action | No |
| `Command` | Custom command | Varies |

## BaseTaskAction Pattern

Most actions use `BaseTaskAction` to reduce boilerplate:

```rust
// crates/bee-actions/src/lib.rs

pub trait BaseTaskAction {
    fn action_type(&self) -> ActionType;
    fn do_base_action(&self, printer: &dyn Printer) -> ActionResult;

    // Default implementations provided
    fn get_modified_tasks(&self) -> Vec<Task> { vec![] }
    fn get_undos(&self) -> Vec<ActionUndo> { vec![] }
}

// Macro generates TaskAction impl from BaseTaskAction
impl_taskaction_from_base!(MyAction);
```

## Creating a New Action

### Step 1: Define Action Struct

```rust
// crates/bee-actions/src/action_my.rs

use crate::{ActionResult, ActionType, BaseTaskAction, impl_taskaction_from_base};
use bee_core::{Printer, Task, TaskData, TaskProperties, ActionUndo};

pub struct MyAction {
    tasks: TaskData,
    arguments: Vec<String>,
    properties: TaskProperties,
    modified_tasks: Vec<Task>,
    undos: Vec<ActionUndo>,
}

impl MyAction {
    pub fn new() -> Self {
        Self {
            tasks: TaskData::default(),
            arguments: vec![],
            properties: TaskProperties::default(),
            modified_tasks: vec![],
            undos: vec![],
        }
    }
}
```

### Step 2: Implement BaseTaskAction

```rust
impl_taskaction_from_base!(MyAction);

impl BaseTaskAction for MyAction {
    fn action_type(&self) -> ActionType {
        ActionType::My
    }

    fn do_base_action(&self, printer: &dyn Printer) -> ActionResult {
        // 1. Get tasks to operate on
        let tasks = self.tasks.tasks_vec();

        // 2. Perform operation
        for task in &tasks {
            // Store original for undo
            self.undos.push(ActionUndo {
                action_type: ActionUndoType::Modify,
                tasks: vec![task.clone()],
            });

            // Modify task
            let mut modified = task.clone();
            modified.do_something();
            self.modified_tasks.push(modified);

            // Print feedback
            printer.print_task_modified(&task);
        }

        Ok(())
    }

    fn get_modified_tasks(&self) -> Vec<Task> {
        self.modified_tasks.clone()
    }

    fn get_undos(&self) -> Vec<ActionUndo> {
        self.undos.clone()
    }
}
```

### Step 3: Add to ActionType Enum

```rust
// crates/bee-actions/src/action_type.rs

#[derive(Debug, Clone, PartialEq)]
pub enum ActionType {
    Add,
    Done,
    // ...
    My,  // Add new variant
}

impl ActionType {
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "add" => Some(Self::Add),
            // ...
            "my" => Some(Self::My),
            _ => None,
        }
    }
}
```

### Step 4: Register in ActionRegistry

```rust
// crates/bee-actions/src/action_type.rs

impl ActionRegistry {
    pub fn get_action(&self, action_type: ActionType) -> Box<dyn TaskAction> {
        match action_type {
            ActionType::Add => Box::new(AddTaskAction::new()),
            // ...
            ActionType::My => Box::new(MyAction::new()),
        }
    }
}
```

### Step 5: Add Tests

```rust
// crates/bee-actions/src/action_my.rs

#[cfg(test)]
mod tests {
    use super::*;
    use bee_core::test_helpers::*;

    #[test]
    fn test_my_action() {
        let task = make_test_task("Test");
        let task_data = TaskData::from_tasks(vec![task]);

        let mut action = MyAction::new();
        action.set_tasks(task_data);

        let printer = MockPrinter::new();
        action.do_action(&printer).unwrap();

        let modified = action.get_modified_tasks();
        assert_eq!(modified.len(), 1);
        // Assert modifications
    }
}
```

## Action Data Flow

```rust
// In bee-cli or bee-api

// 1. Parse command
let parsed = parser.parse(&args)?;

// 2. Load tasks from storage
let task_data = store.load_tasks(&parsed.filter, &parsed.properties).await?;

// 3. Get action
let mut action = registry.get_action(parsed.action_type);

// 4. Configure action
action.set_tasks(task_data);
action.set_arguments(parsed.arguments);
action.set_properties(parsed.properties);

// 5. Execute
action.do_action(&printer)?;

// 6. Persist changes
let modified = action.get_modified_tasks();
store.write_tasks(&modified).await?;

// 7. Log undo
let undos = action.get_undos();
store.log_undo(&undos).await?;
```

## Undo Support

Actions that modify tasks should record undo information:

```rust
fn do_base_action(&self, printer: &dyn Printer) -> ActionResult {
    for task in self.tasks.tasks_vec() {
        // Record pre-modification state
        self.undos.push(ActionUndo {
            action_type: ActionUndoType::Modify,
            tasks: vec![task.clone()],
        });

        // Modify...
    }
    Ok(())
}
```

Undo types:
- `ActionUndoType::Add` - For newly created tasks (undo = delete)
- `ActionUndoType::Modify` - For modified tasks (undo = restore previous state)

## Printer Interface

Actions use `Printer` trait for output:

```rust
pub trait Printer: Send + Sync {
    fn print_task(&self, task: &Task);
    fn print_task_list(&self, tasks: &[Task]);
    fn print_task_modified(&self, task: &Task);
    fn print_error(&self, error: &str);
    fn print_message(&self, message: &str);
}
```

Implementations:
- `SimpleTaskTextPrinter` (CLI)
- `JsonPrinter` (API)

## Common Patterns

### Filtering Tasks in Action

```rust
fn do_base_action(&self, printer: &dyn Printer) -> ActionResult {
    let tasks: Vec<_> = self.tasks.tasks_vec()
        .into_iter()
        .filter(|t| t.status == TaskStatus::Pending)
        .collect();

    // Operate on filtered tasks
}
```

### Applying Properties

```rust
fn do_base_action(&self, printer: &dyn Printer) -> ActionResult {
    for task in self.tasks.tasks_vec() {
        let mut modified = task.clone();

        // Apply user-provided properties
        modified.apply_properties(&self.properties);

        self.modified_tasks.push(modified);
    }
    Ok(())
}
```
