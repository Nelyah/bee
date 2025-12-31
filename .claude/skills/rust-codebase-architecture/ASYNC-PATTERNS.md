# Async Patterns

**Read this when:** Working with Tokio, async storage, or concurrency.

## Runtime

The codebase uses **Tokio** as the async runtime:

```rust
// CLI entry point
#[tokio::main]
async fn main() -> Result<(), CliError> {
    // ...
}

// API entry point
#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/tasks", get(list_tasks))
        // ...

    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}
```

## AsyncStore Trait

```rust
// crates/bee-core/src/storage/mod.rs

pub trait AsyncStore {
    async fn load_tasks(
        &self,
        filter: &RootFilter,
        props: &TaskProperties
    ) -> Result<TaskData, CoreError>;

    async fn write_tasks(&self, tasks: &[Task]) -> Result<(), CoreError>;

    async fn log_undo(&self, undos: &[ActionUndo]) -> Result<(), CoreError>;

    async fn pop_undo(&self) -> Result<Option<ActionUndo>, CoreError>;

    async fn get_user_reports(&self) -> Result<Vec<UserReport>, CoreError>;

    // ... more methods
}
```

## Database Operations

### Connection Pool

```rust
// crates/bee-core/src/storage/db/connection.rs

use sea_orm::{Database, DatabaseConnection};

pub async fn create_connection(url: &str) -> Result<DatabaseConnection, CoreError> {
    let db = Database::connect(url)
        .await
        .map_err(|e| CoreError::Storage {
            message: format!("Failed to connect: {}", e)
        })?;

    // Set pragmas
    db.execute_unprepared("PRAGMA foreign_keys = ON").await?;
    db.execute_unprepared("PRAGMA journal_mode = WAL").await?;
    db.execute_unprepared("PRAGMA busy_timeout = 5000").await?;

    Ok(db)
}
```

### Transaction Pattern

```rust
impl DbStore {
    pub async fn write_tasks(&self, tasks: &[Task]) -> Result<(), CoreError> {
        // Start transaction
        let txn = self.db.begin().await?;

        for task in tasks {
            self.upsert_task(&txn, task).await?;
            self.sync_relations(&txn, task).await?;
        }

        // Commit (or rollback on error via Drop)
        txn.commit().await?;
        Ok(())
    }
}
```

### Async Queries

```rust
use sea_orm::{EntityTrait, QueryFilter, ColumnTrait};

// Find one
let task = Tasks::find()
    .filter(tasks::Column::Uuid.eq(uuid))
    .one(&self.db)
    .await?;

// Find many
let tasks = Tasks::find()
    .filter(tasks::Column::Status.eq("pending"))
    .all(&self.db)
    .await?;

// Insert
let model = tasks::ActiveModel {
    uuid: Set(task.uuid.to_string()),
    title: Set(task.title.clone()),
    // ...
};
Tasks::insert(model).exec(&self.db).await?;

// Update
let model = tasks::ActiveModel {
    uuid: Set(task.uuid.to_string()),
    title: Set(new_title),
    ..Default::default()
};
Tasks::update(model).exec(&self.db).await?;
```

## Avoiding Blocking

### Don't Block the Runtime

```rust
// BAD: Blocks the async runtime
async fn bad_example() {
    let content = std::fs::read_to_string("file.txt").unwrap();  // Blocking!
}

// GOOD: Use async I/O
async fn good_example() {
    let content = tokio::fs::read_to_string("file.txt").await.unwrap();
}

// GOOD: Use spawn_blocking for CPU-intensive work
async fn cpu_intensive() {
    let result = tokio::task::spawn_blocking(|| {
        // Heavy computation
        expensive_calculation()
    }).await.unwrap();
}
```

### Async in Tests

```rust
#[tokio::test]
async fn test_async_operation() {
    let store = DbStore::new(":memory:").await.unwrap();

    let task = Task::new("Test");
    store.write_tasks(&[task]).await.unwrap();

    let data = store.load_tasks(&filter, &props).await.unwrap();
    assert_eq!(data.tasks_vec().len(), 1);
}
```

## Concurrent Operations

### Parallel Execution

```rust
use futures::future::join_all;

async fn process_multiple(items: Vec<Item>) -> Vec<Result<Output, Error>> {
    let futures: Vec<_> = items
        .into_iter()
        .map(|item| process_item(item))
        .collect();

    join_all(futures).await
}
```

### Controlled Concurrency

```rust
use futures::stream::{self, StreamExt};

async fn process_with_limit(items: Vec<Item>) {
    stream::iter(items)
        .map(|item| async move {
            process_item(item).await
        })
        .buffer_unordered(10)  // Max 10 concurrent
        .collect::<Vec<_>>()
        .await;
}
```

## HTTP Client (bee-api)

```rust
use reqwest::Client;

pub struct AppState {
    pub http_client: Client,
    pub config: Config,
}

impl AppState {
    pub fn new(config: Config) -> Self {
        Self {
            http_client: Client::new(),
            config,
        }
    }
}

// Usage in handler
async fn fetch_external(
    State(state): State<Arc<AppState>>
) -> Result<Json<Response>, ApiError> {
    let response = state.http_client
        .get("https://api.example.com/data")
        .send()
        .await
        .map_err(|e| ApiError::Internal {
            message: e.to_string()
        })?;

    let data = response.json().await?;
    Ok(Json(data))
}
```

## Common Patterns

### Async Method with Result

```rust
pub async fn do_something(&self) -> Result<Output, CoreError> {
    let intermediate = self.step_one().await?;
    let result = self.step_two(intermediate).await?;
    Ok(result)
}
```

### Timeout

```rust
use tokio::time::{timeout, Duration};

async fn with_timeout() -> Result<Data, CoreError> {
    timeout(Duration::from_secs(30), fetch_data())
        .await
        .map_err(|_| CoreError::Internal {
            message: "Operation timed out".into()
        })?
}
```

### Retry Logic

```rust
async fn with_retry<T, E, F, Fut>(
    max_attempts: u32,
    operation: F,
) -> Result<T, E>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = Result<T, E>>,
{
    let mut attempts = 0;
    loop {
        attempts += 1;
        match operation().await {
            Ok(result) => return Ok(result),
            Err(e) if attempts >= max_attempts => return Err(e),
            Err(_) => {
                tokio::time::sleep(Duration::from_millis(100 * attempts as u64)).await;
            }
        }
    }
}
```

## Error Handling in Async

```rust
// Using ? with async
async fn example() -> Result<(), CoreError> {
    let data = fetch_data().await?;
    process_data(data).await?;
    Ok(())
}

// Converting errors
async fn with_conversion() -> Result<(), CoreError> {
    let response = client.get(url)
        .send()
        .await
        .map_err(|e| CoreError::ExternalLink {
            message: e.to_string()
        })?;

    Ok(())
}
```

## Testing Async Code

```rust
#[tokio::test]
async fn test_concurrent_operations() {
    let store = create_test_store().await;

    // Run multiple operations concurrently
    let (result1, result2) = tokio::join!(
        store.load_tasks(&filter1, &props),
        store.load_tasks(&filter2, &props),
    );

    assert!(result1.is_ok());
    assert!(result2.is_ok());
}

#[tokio::test]
async fn test_timeout() {
    let result = timeout(
        Duration::from_millis(100),
        slow_operation()
    ).await;

    assert!(result.is_err());  // Should timeout
}
```
