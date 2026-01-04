//! Attachment domain model for file attachments on tasks.
//!
//! Attachments are stored as BLOBs directly in the database.
//! The [`Attachment`] struct contains metadata only - use the storage layer
//! to retrieve the actual file data when needed.

use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// File attachment metadata (without the actual file data).
///
/// For performance, the file data is loaded separately via
/// `DbStore::get_attachment_data()` to avoid loading large BLOBs
/// during list operations.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Attachment {
    /// Database primary key.
    pub id: i32,
    /// UUID of the task this attachment belongs to.
    pub task_uuid: Uuid,
    /// Unique identifier for this attachment.
    pub uuid: Uuid,
    /// Original filename.
    pub filename: String,
    /// MIME type (e.g., "application/pdf", "image/png").
    pub mime_type: String,
    /// File size in bytes.
    pub size_bytes: i64,
    /// When the attachment was added.
    pub created_at: DateTime<Local>,
}

impl Attachment {
    /// Returns a human-readable file size (e.g., "2.4 MB").
    pub fn formatted_size(&self) -> String {
        const KB: i64 = 1024;
        const MB: i64 = KB * 1024;
        const GB: i64 = MB * 1024;

        if self.size_bytes >= GB {
            format!("{:.1} GB", self.size_bytes as f64 / GB as f64)
        } else if self.size_bytes >= MB {
            format!("{:.1} MB", self.size_bytes as f64 / MB as f64)
        } else if self.size_bytes >= KB {
            format!("{:.1} KB", self.size_bytes as f64 / KB as f64)
        } else {
            format!("{} bytes", self.size_bytes)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_formatted_size_bytes() {
        let attachment = Attachment {
            id: 1,
            task_uuid: Uuid::new_v4(),
            uuid: Uuid::new_v4(),
            filename: "test.txt".to_string(),
            mime_type: "text/plain".to_string(),
            size_bytes: 500,
            created_at: Local::now(),
        };
        assert_eq!(attachment.formatted_size(), "500 bytes");
    }

    #[test]
    fn test_formatted_size_kb() {
        let attachment = Attachment {
            id: 1,
            task_uuid: Uuid::new_v4(),
            uuid: Uuid::new_v4(),
            filename: "test.txt".to_string(),
            mime_type: "text/plain".to_string(),
            size_bytes: 2048,
            created_at: Local::now(),
        };
        assert_eq!(attachment.formatted_size(), "2.0 KB");
    }

    #[test]
    fn test_formatted_size_mb() {
        let attachment = Attachment {
            id: 1,
            task_uuid: Uuid::new_v4(),
            uuid: Uuid::new_v4(),
            filename: "test.txt".to_string(),
            mime_type: "text/plain".to_string(),
            size_bytes: 2_500_000,
            created_at: Local::now(),
        };
        assert_eq!(attachment.formatted_size(), "2.4 MB");
    }

    #[test]
    fn test_formatted_size_gb() {
        let attachment = Attachment {
            id: 1,
            task_uuid: Uuid::new_v4(),
            uuid: Uuid::new_v4(),
            filename: "test.txt".to_string(),
            mime_type: "text/plain".to_string(),
            size_bytes: 1_500_000_000,
            created_at: Local::now(),
        };
        assert_eq!(attachment.formatted_size(), "1.4 GB");
    }
}
