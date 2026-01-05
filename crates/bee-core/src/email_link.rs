//! Email link domain model for linking emails to tasks.
//!
//! Email links store references to emails in Apple Mail, allowing users
//! to quickly access related emails from their tasks. The `message://` URL
//! scheme is used to open emails in Mail.app.

use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Email link metadata (reference to an email in Mail.app).
///
/// Unlike attachments which store file data, email links only store
/// the metadata needed to identify and open the email.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct EmailLink {
    /// Database primary key (None until persisted).
    pub(crate) id: Option<i32>,
    /// Unique identifier for this email link.
    pub(crate) uuid: Uuid,
    /// RFC 5322 Message-ID (e.g., "<abc123@example.com>").
    pub(crate) message_id: String,
    /// Email subject line.
    pub(crate) subject: String,
    /// Sender email address or name.
    pub(crate) sender: String,
    /// When the email was sent (parsed from EML Date header).
    pub(crate) sent_date: Option<DateTime<Local>>,
    /// When this link was created.
    pub(crate) created_at: DateTime<Local>,
}

impl EmailLink {
    /// Creates a new email link with the given parameters.
    pub fn new(
        message_id: String,
        subject: String,
        sender: String,
        sent_date: Option<DateTime<Local>>,
    ) -> Self {
        Self {
            id: None,
            uuid: Uuid::new_v4(),
            message_id,
            subject,
            sender,
            sent_date,
            created_at: Local::now(),
        }
    }

    /// Returns the `message://` URL to open this email in Mail.app.
    ///
    /// The Message-ID is URL-encoded to handle special characters.
    pub fn mail_url(&self) -> String {
        // Message-ID typically includes angle brackets, encode them properly
        let id = self
            .message_id
            .trim_start_matches('<')
            .trim_end_matches('>');
        // URL-encode the message ID and wrap in angle brackets
        let encoded = urlencoding::encode(id);
        format!("message://%3c{}%3e", encoded)
    }

    // Getters for read access
    pub fn get_id(&self) -> Option<i32> {
        self.id
    }

    pub fn get_uuid(&self) -> Uuid {
        self.uuid
    }

    pub fn get_message_id(&self) -> &str {
        &self.message_id
    }

    pub fn get_subject(&self) -> &str {
        &self.subject
    }

    pub fn get_sender(&self) -> &str {
        &self.sender
    }

    pub fn get_sent_date(&self) -> Option<DateTime<Local>> {
        self.sent_date
    }

    pub fn get_created_at(&self) -> DateTime<Local> {
        self.created_at
    }
}

/// Input for adding an email link via TaskProperties.
///
/// This is the data needed to create a new EmailLink, typically
/// parsed from an EML file dropped into the UI.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct EmailLinkInput {
    /// RFC 5322 Message-ID.
    pub message_id: String,
    /// Email subject line.
    pub subject: String,
    /// Sender email address or name.
    pub sender: String,
    /// When the email was sent.
    pub sent_date: Option<DateTime<Local>>,
}

impl EmailLinkInput {
    pub fn new(
        message_id: String,
        subject: String,
        sender: String,
        sent_date: Option<DateTime<Local>>,
    ) -> Self {
        Self {
            message_id,
            subject,
            sender,
            sent_date,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_email_link() {
        let link = EmailLink::new(
            "<test123@example.com>".to_string(),
            "Test Subject".to_string(),
            "sender@example.com".to_string(),
            None,
        );

        assert!(link.id.is_none());
        assert_eq!(link.message_id, "<test123@example.com>");
        assert_eq!(link.subject, "Test Subject");
        assert_eq!(link.sender, "sender@example.com");
        assert!(link.sent_date.is_none());
    }

    #[test]
    fn test_new_email_link_with_sent_date() {
        let sent = Local::now();
        let link = EmailLink::new(
            "<msg@test.com>".to_string(),
            "With Date".to_string(),
            "alice@example.com".to_string(),
            Some(sent),
        );

        assert_eq!(link.get_sent_date(), Some(sent));
        assert!(link.get_created_at() >= sent);
    }

    #[test]
    fn test_mail_url_simple() {
        let link = EmailLink::new(
            "<test123@example.com>".to_string(),
            "Test".to_string(),
            "sender@example.com".to_string(),
            None,
        );

        // Message-ID without angle brackets, URL-encoded
        assert_eq!(link.mail_url(), "message://%3ctest123%40example.com%3e");
    }

    #[test]
    fn test_mail_url_without_brackets() {
        let link = EmailLink::new(
            "test123@example.com".to_string(),
            "Test".to_string(),
            "sender@example.com".to_string(),
            None,
        );

        assert_eq!(link.mail_url(), "message://%3ctest123%40example.com%3e");
    }

    #[test]
    fn test_mail_url_with_special_characters() {
        // Message IDs can contain various special characters
        let link = EmailLink::new(
            "<CAD+8Ob=abc123.456_test@mail.gmail.com>".to_string(),
            "Test".to_string(),
            "sender@gmail.com".to_string(),
            None,
        );

        let url = link.mail_url();
        assert!(url.starts_with("message://%3c"));
        assert!(url.ends_with("%3e"));
        // The + sign should be encoded
        assert!(url.contains("%2B"));
    }

    #[test]
    fn test_getters() {
        let link = EmailLink::new(
            "<abc@test.com>".to_string(),
            "My Subject".to_string(),
            "Bob <bob@example.com>".to_string(),
            None,
        );

        assert_eq!(link.get_id(), None);
        assert_eq!(link.get_message_id(), "<abc@test.com>");
        assert_eq!(link.get_subject(), "My Subject");
        assert_eq!(link.get_sender(), "Bob <bob@example.com>");
        assert_eq!(link.get_sent_date(), None);
        // UUID should be valid
        assert!(!link.get_uuid().is_nil());
    }

    #[test]
    fn test_email_link_input() {
        let input = EmailLinkInput::new(
            "<msg@test.com>".to_string(),
            "Subject".to_string(),
            "test@test.com".to_string(),
            Some(Local::now()),
        );

        assert_eq!(input.message_id, "<msg@test.com>");
        assert!(input.sent_date.is_some());
    }

    #[test]
    fn test_email_link_serialization() {
        let link = EmailLink::new(
            "<serial@test.com>".to_string(),
            "Serialization Test".to_string(),
            "sender@test.com".to_string(),
            None,
        );

        let json = serde_json::to_string(&link).expect("serialize");
        assert!(json.contains("serial@test.com"));
        assert!(json.contains("Serialization Test"));

        let parsed: EmailLink = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(parsed.message_id, link.message_id);
        assert_eq!(parsed.subject, link.subject);
        assert_eq!(parsed.uuid, link.uuid);
    }

    #[test]
    fn test_email_link_input_serialization() {
        let input = EmailLinkInput::new(
            "<input@test.com>".to_string(),
            "Input Test".to_string(),
            "sender@test.com".to_string(),
            None,
        );

        let json = serde_json::to_string(&input).expect("serialize");
        let parsed: EmailLinkInput = serde_json::from_str(&json).expect("deserialize");

        assert_eq!(parsed.message_id, input.message_id);
        assert_eq!(parsed.subject, input.subject);
        assert_eq!(parsed.sender, input.sender);
    }

    #[test]
    fn test_email_link_equality() {
        let link1 = EmailLink::new(
            "<same@test.com>".to_string(),
            "Same".to_string(),
            "sender@test.com".to_string(),
            None,
        );
        let link2 = EmailLink::new(
            "<same@test.com>".to_string(),
            "Same".to_string(),
            "sender@test.com".to_string(),
            None,
        );

        // Different UUIDs mean they're not equal
        assert_ne!(link1, link2);

        // But same link is equal to itself
        assert_eq!(link1, link1.clone());
    }

    #[test]
    fn test_email_link_ordering() {
        // EmailLink derives Ord for use in collections
        let link1 = EmailLink::new(
            "<a@test.com>".to_string(),
            "A".to_string(),
            "a@test.com".to_string(),
            None,
        );
        let link2 = EmailLink::new(
            "<b@test.com>".to_string(),
            "B".to_string(),
            "b@test.com".to_string(),
            None,
        );

        // Ordering should be consistent (doesn't matter which is greater)
        let cmp1 = link1.cmp(&link2);
        let cmp2 = link2.cmp(&link1);
        assert!(cmp1.is_lt() || cmp1.is_gt());
        assert_eq!(cmp1.reverse(), cmp2);
    }
}
