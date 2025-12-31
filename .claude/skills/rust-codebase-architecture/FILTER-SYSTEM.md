# Filter System

**Read this when:** Working with filters, adding new filter types, or understanding the composite pattern.

## Architecture

The filter system uses the **Composite Pattern**:

```
RootFilter
    │
    ├── AndFilter
    │       ├── StatusFilter(pending)
    │       └── ProjectFilter(backend)
    │
    └── OrFilter
            ├── TagFilter(urgent)
            └── DueDateFilter(today)
```

## Filter Trait

```rust
// crates/bee-core/src/filters/mod.rs

#[typetag::serde(tag = "type")]
pub trait Filter: Send + Sync {
    /// Check if a task matches this filter
    fn matches(&self, task: &Task) -> bool;

    /// Human-readable description
    fn description(&self) -> String;

    /// Clone into boxed trait object
    fn clone_box(&self) -> Box<dyn Filter>;
}
```

## Available Filter Types (14)

| Filter | Syntax | Example |
|--------|--------|---------|
| `StatusFilter` | `status:<status>` | `status:pending` |
| `ProjectFilter` | `project:<name>` | `project:backend` |
| `TagFilter` | `+<tag>` or `tag:<tag>` | `+urgent`, `tag:bug` |
| `DueDateFilter` | `due:<date>` | `due:today`, `due:2024-01-15` |
| `CreatedDateFilter` | `created:<date>` | `created:today` |
| `EndedDateFilter` | `ended:<date>` | `ended:yesterday` |
| `UuidFilter` | `uuid:<uuid>` | `uuid:abc123...` |
| `TaskIdFilter` | `id:<id>` or `<id>` | `id:42`, `42` |
| `StringFilter` | `<text>` | `fix bug` |
| `DependsOnFilter` | `depends:<id>` | `depends:5` |
| `BlocksFilter` | `blocks:<id>` | `blocks:10` |
| `AndFilter` | Composite | Multiple conditions AND'd |
| `OrFilter` | Composite | Multiple conditions OR'd |
| `XorFilter` | Composite | Exactly one condition matches |

## Composition Helpers

```rust
use crate::filters::{and, or, from, RootFilter};

// Parse from strings
let filter = from(&["status:pending", "project:backend"]);

// Explicit AND
let filter = and(vec![
    Box::new(StatusFilter::new(TaskStatus::Pending)),
    Box::new(ProjectFilter::new("backend")),
]);

// Explicit OR
let filter = or(vec![
    Box::new(TagFilter::new("urgent")),
    Box::new(TagFilter::new("critical")),
]);

// RootFilter wrapper (for serialization)
let root = RootFilter::new(filter);
```

## Adding a New Filter Type

### Step 1: Create Filter Struct

```rust
// crates/bee-core/src/filters/my_filter.rs

use serde::{Deserialize, Serialize};
use crate::task::Task;
use super::Filter;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MyFilter {
    value: String,
}

impl MyFilter {
    pub fn new(value: impl Into<String>) -> Self {
        Self { value: value.into() }
    }
}

#[typetag::serde]
impl Filter for MyFilter {
    fn matches(&self, task: &Task) -> bool {
        // Your matching logic
        task.some_field.contains(&self.value)
    }

    fn description(&self) -> String {
        format!("myfilter:{}", self.value)
    }

    fn clone_box(&self) -> Box<dyn Filter> {
        Box::new(self.clone())
    }
}
```

### Step 2: Register in mod.rs

```rust
// crates/bee-core/src/filters/mod.rs

mod my_filter;
pub use my_filter::MyFilter;
```

### Step 3: Add Parsing Support

```rust
// crates/bee-core/src/filters/filter_parser.rs

fn parse_filter_string(s: &str) -> Option<Box<dyn Filter>> {
    if let Some(value) = s.strip_prefix("myfilter:") {
        return Some(Box::new(MyFilter::new(value)));
    }
    // ... other parsers
    None
}
```

### Step 4: Add Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_my_filter_matches() {
        let task = Task::new("test task with value");
        let filter = MyFilter::new("value");

        assert!(filter.matches(&task));
    }

    #[test]
    fn test_my_filter_no_match() {
        let task = Task::new("test task");
        let filter = MyFilter::new("missing");

        assert!(!filter.matches(&task));
    }
}
```

## Polymorphic Serialization

Filters use `typetag` for serialization of trait objects:

```rust
// Serialization (to JSON for storage)
let filter: Box<dyn Filter> = Box::new(StatusFilter::new(TaskStatus::Pending));
let json = serde_json::to_string(&filter)?;
// {"type":"StatusFilter","status":"pending"}

// Deserialization
let filter: Box<dyn Filter> = serde_json::from_str(&json)?;
```

The `#[typetag::serde]` attribute on the trait and implementations enables this.

## ID to UUID Resolution

Filters that reference task IDs (like `TaskIdFilter`) need to resolve to UUIDs:

```rust
impl Filter for TaskIdFilter {
    fn matches(&self, task: &Task) -> bool {
        // TaskData provides id_to_uuid mapping
        // This is handled during filter application
        task.id == Some(self.task_id)
    }
}
```

The `TaskData` struct holds the `id_to_uuid` mapping for resolution.

## Filter SQL Generation

For database queries, filters can be converted to SQL:

```rust
// crates/bee-core/src/storage/db/filter_sql.rs

pub fn filter_to_sql(filter: &dyn Filter) -> (String, Vec<Value>) {
    // Returns WHERE clause and parameters
}
```

This optimizes queries by pushing filtering to the database.

## Common Patterns

### Combining User Input with Defaults

```rust
// Start with user's filter
let mut filters: Vec<Box<dyn Filter>> = from(&user_args);

// Add default exclusions
filters.push(Box::new(StatusFilter::new(TaskStatus::Deleted).negate()));

// Combine
let combined = and(filters);
```

### Negation

```rust
impl<F: Filter> Filter for Not<F> {
    fn matches(&self, task: &Task) -> bool {
        !self.inner.matches(task)
    }
}
```

### Testing Filter Combinations

```rust
#[test]
fn test_complex_filter() {
    let filter = and(vec![
        or(vec![
            Box::new(StatusFilter::new(TaskStatus::Pending)),
            Box::new(StatusFilter::new(TaskStatus::Active)),
        ]),
        Box::new(ProjectFilter::new("backend")),
    ]);

    let matching_task = Task::new("test")
        .with_status(TaskStatus::Pending)
        .with_project("backend");

    let non_matching_task = Task::new("test")
        .with_status(TaskStatus::Completed)
        .with_project("backend");

    assert!(filter.matches(&matching_task));
    assert!(!filter.matches(&non_matching_task));
}
```
