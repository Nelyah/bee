# Storage Layer

**Read this when:** Working with database operations, migrations, or SeaORM.

## Architecture

```
┌─────────────────────────────────────────────┐
│              AsyncStore Trait               │
│  load_tasks, write_tasks, log_undo, etc.    │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│                  DbStore                     │
│            SQLite + SeaORM                   │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│           SeaORM Entities                    │
│  tasks, tags, annotations, links, etc.       │
└─────────────────────────────────────────────┘
```

## Storage Traits

```rust
// crates/bee-core/src/storage/mod.rs

pub trait Store {
    fn load_tasks(&self, filter: &RootFilter, props: &TaskProperties) -> Result<TaskData>;
    fn write_tasks(&self, tasks: &[Task]) -> Result<()>;
    fn log_undo(&self, undos: &[ActionUndo]) -> Result<()>;
    // ... more methods
}

pub trait AsyncStore {
    async fn load_tasks(&self, filter: &RootFilter, props: &TaskProperties) -> Result<TaskData>;
    async fn write_tasks(&self, tasks: &[Task]) -> Result<()>;
    async fn log_undo(&self, undos: &[ActionUndo]) -> Result<()>;
    // ... more methods
}
```

## DbStore Usage

```rust
use bee_core::storage::DbStore;

// Create connection
let store = DbStore::new(&database_url).await?;

// Load tasks with filter
let filter = filters::from(&["status:pending"]);
let props = TaskProperties::default();
let task_data = store.load_tasks(&filter, &props).await?;

// Modify and write back
let mut tasks = task_data.tasks_vec();
for task in &mut tasks {
    task.status = TaskStatus::Active;
}
store.write_tasks(&tasks).await?;
```

## Database Schema

### Core Tables

```sql
-- tasks
CREATE TABLE tasks (
    uuid TEXT PRIMARY KEY,
    id INTEGER UNIQUE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL,
    project_id INTEGER REFERENCES projects(id),
    created TEXT NOT NULL,
    due TEXT,
    ended TEXT
);

-- tags (many-to-many with tasks)
CREATE TABLE tags (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE tasks_tags (
    task_uuid TEXT REFERENCES tasks(uuid),
    tag_id INTEGER REFERENCES tags(id),
    PRIMARY KEY (task_uuid, tag_id)
);

-- annotations
CREATE TABLE annotations (
    id INTEGER PRIMARY KEY,
    task_uuid TEXT REFERENCES tasks(uuid),
    value TEXT NOT NULL,
    time TEXT NOT NULL
);

-- links (dependencies)
CREATE TABLE links (
    id INTEGER PRIMARY KEY,
    from_uuid TEXT REFERENCES tasks(uuid),
    to_uuid TEXT REFERENCES tasks(uuid),
    link_type TEXT NOT NULL  -- 'DependsOn' or 'Blocking'
);
```

### Support Tables

```sql
-- projects
CREATE TABLE projects (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

-- user_reports (saved filters)
CREATE TABLE user_reports (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    filter TEXT NOT NULL,  -- JSON
    columns TEXT           -- JSON
);

-- undo_actions
CREATE TABLE undo_actions (
    id INTEGER PRIMARY KEY,
    action_type TEXT NOT NULL,
    tasks TEXT NOT NULL,  -- JSON array of task snapshots
    created_at TEXT NOT NULL
);

-- external_links
CREATE TABLE external_links (
    id INTEGER PRIMARY KEY,
    task_uuid TEXT REFERENCES tasks(uuid),
    provider TEXT NOT NULL,
    url TEXT NOT NULL,
    external_key TEXT,
    cache TEXT,
    sync_error TEXT,
    last_synced_at TEXT
);
```

## SeaORM Entities

Located in `crates/bee-core/src/storage/db/tables/`:

```rust
// Example: tasks entity
#[derive(Clone, Debug, DeriveEntityModel)]
#[sea_orm(table_name = "tasks")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub uuid: String,
    pub id: Option<i32>,
    pub title: String,
    pub description: Option<String>,
    pub status: String,
    pub project_id: Option<i32>,
    pub created: String,
    pub due: Option<String>,
    pub ended: Option<String>,
}
```

## Migrations

Located in `crates/migration/src/`:

```rust
// m20250329_212639_create_task_schema.rs
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.create_table(
            Table::create()
                .table(Tasks::Table)
                .col(ColumnDef::new(Tasks::Uuid).string().primary_key())
                // ...
        ).await
    }
}
```

### Running Migrations

```bash
# Migrations run automatically on startup

# Manual migration (if needed)
sea-orm-cli migrate up

# Check status
sea-orm-cli migrate status
```

### Adding a New Migration

```bash
# Generate migration file
sea-orm-cli migrate generate add_new_column

# Edit the generated file in crates/migration/src/

# Run migration
sea-orm-cli migrate up
```

## Database URL Resolution

Priority order:
1. `BEE_DATABASE_URL` environment variable
2. `$BEE_DATA_HOME/bee.sqlite`
3. `$XDG_DATA_HOME/bee/bee.sqlite`
4. `~/.local/share/bee/bee.sqlite`
5. `./bee.sqlite` (fallback)

```rust
// crates/bee-core/src/storage/db/connection.rs
pub fn get_database_url() -> String {
    if let Ok(url) = std::env::var("BEE_DATABASE_URL") {
        return url;
    }
    // ... fallback logic
}
```

## SQLite Pragmas

```rust
// Set on connection
sqlx::query("PRAGMA foreign_keys = ON").execute(&pool).await?;
sqlx::query("PRAGMA journal_mode = WAL").execute(&pool).await?;
sqlx::query("PRAGMA busy_timeout = 5000").execute(&pool).await?;
```

## TaskData Container

```rust
// crates/bee-core/src/task_data.rs

pub struct TaskData {
    tasks: HashMap<Uuid, Task>,       // Loaded tasks matching filter
    undos: HashMap<Uuid, Task>,       // Previous task states (for undo)
    id_to_uuid: HashMap<i32, Uuid>,   // ID mapping for all tasks
    extra_tasks: HashMap<Uuid, Task>, // Dependencies not in main filter
}

impl TaskData {
    pub fn tasks_vec(&self) -> Vec<Task> { /* ... */ }
    pub fn get(&self, uuid: &Uuid) -> Option<&Task> { /* ... */ }
    pub fn resolve_id(&self, id: i32) -> Option<Uuid> { /* ... */ }
}
```

## Writing Tasks

```rust
// crates/bee-core/src/storage/db/task_write.rs

impl DbStore {
    pub async fn write_tasks(&self, tasks: &[Task]) -> Result<()> {
        // Transaction for atomicity
        let txn = self.db.begin().await?;

        for task in tasks {
            // Upsert task
            self.upsert_task(&txn, task).await?;

            // Sync relations (tags, annotations, links)
            self.sync_tags(&txn, task).await?;
            self.sync_annotations(&txn, task).await?;
            self.sync_links(&txn, task).await?;
        }

        txn.commit().await?;
        Ok(())
    }
}
```

## Undo Logging

```rust
// crates/bee-core/src/storage/db/undo.rs

impl DbStore {
    pub async fn log_undo(&self, undos: &[ActionUndo]) -> Result<()> {
        for undo in undos {
            let tasks_json = serde_json::to_string(&undo.tasks)?;
            // Insert into undo_actions table
        }
        Ok(())
    }

    pub async fn pop_undo(&self) -> Result<Option<ActionUndo>> {
        // Get most recent undo
        // Delete from table
        // Return for application
    }
}
```

## Testing Storage

```rust
#[tokio::test]
async fn test_write_and_load() {
    let store = DbStore::new(":memory:").await.unwrap();

    let task = Task::new("Test task");
    store.write_tasks(&[task.clone()]).await.unwrap();

    let filter = filters::from(&["status:pending"]);
    let data = store.load_tasks(&filter, &TaskProperties::default()).await.unwrap();

    assert_eq!(data.tasks_vec().len(), 1);
    assert_eq!(data.tasks_vec()[0].title, "Test task");
}
```
