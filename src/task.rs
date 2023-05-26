    use chrono::prelude::DateTime;
    use uuid::Uuid;

    // TODO: Task need to have:
    // - Status
    // - Due date
    // - Project
    // - Link to other tasks (RelatesTo, Blocks, Depend, etc.)

    #[derive(Clone, Debug, PartialEq, PartialOrd, serde::Serialize, serde::Deserialize)]
    pub enum TaskStatus {
        PENDING,
        COMPLETED,
        DELETED,
    }

    impl Default for TaskStatus {
        fn default() -> TaskStatus {
            TaskStatus::PENDING
        }
    }

    impl TaskStatus {
        pub fn from_str(input: &str) -> Result<TaskStatus, String> {
            match input.to_lowercase().as_str() {
                "pending" => Ok(TaskStatus::PENDING),
                "completed" => Ok(TaskStatus::COMPLETED),
                "deleted" => Ok(TaskStatus::DELETED),
                _ => Err("Invalid task status".to_string()),
            }
        }
    }

    #[derive(Default, serde::Serialize, serde::Deserialize)]
    pub struct Task {
        pub id: Option<usize>,
        pub status: TaskStatus,
        pub uuid: Uuid,
        pub description: String,
        pub tags: Vec<String>,
        pub date_created: DateTime<chrono::Local>,
        #[serde(default)]
        pub date_completed: Option<DateTime<chrono::Local>>,
        pub sub: Vec<Uuid>,
    }
