use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ExternalLink {
    pub id: i32,
    pub task_uuid: Uuid,
    pub provider: String,
    pub url: String,
    pub external_key: String,
    pub cached_response: Option<String>,
    pub last_synced_at: Option<DateTime<Utc>>,
    pub sync_error: Option<String>,
}
