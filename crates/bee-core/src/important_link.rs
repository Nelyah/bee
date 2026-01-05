//! Important link domain model for user-defined URLs on tasks.
//!
//! Important links allow users to attach relevant URLs to tasks for quick
//! access to documentation, tickets, or other web resources.

use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// An important link attached to a task.
///
/// Unlike external links (GitLab, Jira) which have provider-specific sync,
/// important links are simple user-defined URLs with titles.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ImportantLink {
    /// Database primary key (None until persisted).
    pub(crate) id: Option<i32>,
    /// Unique identifier for this link.
    pub(crate) uuid: Uuid,
    /// The URL of the link.
    pub(crate) url: String,
    /// Display title for the link.
    pub(crate) title: String,
    /// When this link was created.
    pub(crate) created_at: DateTime<Local>,
}

impl ImportantLink {
    /// Creates a new important link.
    ///
    /// If `title` is None, the domain is extracted from the URL.
    pub fn new(url: String, title: Option<String>) -> Self {
        let title = title.unwrap_or_else(|| extract_domain(&url));
        Self {
            id: None,
            uuid: Uuid::new_v4(),
            url,
            title,
            created_at: Local::now(),
        }
    }

    // Getters for read access

    pub fn get_id(&self) -> Option<i32> {
        self.id
    }

    pub fn get_uuid(&self) -> Uuid {
        self.uuid
    }

    pub fn get_url(&self) -> &str {
        &self.url
    }

    pub fn get_title(&self) -> &str {
        &self.title
    }

    pub fn get_created_at(&self) -> DateTime<Local> {
        self.created_at
    }
}

/// Input for adding an important link via TaskProperties.
///
/// The title is optional; if omitted, it defaults to the URL domain.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ImportantLinkInput {
    /// The URL of the link.
    pub url: String,
    /// Optional display title (defaults to domain if not provided).
    pub title: Option<String>,
}

impl ImportantLinkInput {
    pub fn new(url: String, title: Option<String>) -> Self {
        Self { url, title }
    }
}

/// Extracts the domain from a URL for use as a default title.
///
/// Examples:
/// - `https://github.com/user/repo` -> `github.com`
/// - `http://docs.example.com/page` -> `docs.example.com`
/// - `invalid-url` -> `invalid-url` (returns input as-is)
fn extract_domain(url: &str) -> String {
    // Simple parsing without external crate
    // Look for "://" and extract the host portion
    if let Some(start) = url.find("://") {
        let after_scheme = &url[start + 3..];
        // Find the end of the host (first / or end of string)
        let end = after_scheme.find('/').unwrap_or(after_scheme.len());
        let host_part = &after_scheme[..end];
        // Remove port if present
        let host = host_part.split(':').next().unwrap_or(host_part);
        // Remove username:password@ if present
        let host = host.split('@').next_back().unwrap_or(host);
        if !host.is_empty() {
            return host.to_string();
        }
    }
    // Fallback: return the URL itself (truncated if too long)
    if url.len() > 50 {
        format!("{}...", &url[..47])
    } else {
        url.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_important_link_with_title() {
        let link = ImportantLink::new(
            "https://github.com/user/repo".to_string(),
            Some("My Repo".to_string()),
        );

        assert!(link.id.is_none());
        assert_eq!(link.url, "https://github.com/user/repo");
        assert_eq!(link.title, "My Repo");
        assert!(!link.uuid.is_nil());
    }

    #[test]
    fn test_new_important_link_without_title() {
        let link = ImportantLink::new("https://docs.example.com/guide".to_string(), None);

        assert_eq!(link.url, "https://docs.example.com/guide");
        assert_eq!(link.title, "docs.example.com");
    }

    #[test]
    fn test_extract_domain_https() {
        assert_eq!(extract_domain("https://github.com/user/repo"), "github.com");
    }

    #[test]
    fn test_extract_domain_http() {
        assert_eq!(
            extract_domain("http://example.com/path/to/page"),
            "example.com"
        );
    }

    #[test]
    fn test_extract_domain_with_subdomain() {
        assert_eq!(
            extract_domain("https://docs.rust-lang.org/book/"),
            "docs.rust-lang.org"
        );
    }

    #[test]
    fn test_extract_domain_invalid_url() {
        // Invalid URL returns the input as-is
        assert_eq!(extract_domain("not-a-valid-url"), "not-a-valid-url");
    }

    #[test]
    fn test_extract_domain_long_invalid_url() {
        let long_url = "a".repeat(60);
        let result = extract_domain(&long_url);
        assert!(result.len() <= 50);
        assert!(result.ends_with("..."));
    }

    #[test]
    fn test_getters() {
        let link = ImportantLink::new(
            "https://test.com/page".to_string(),
            Some("Test Page".to_string()),
        );

        assert_eq!(link.get_id(), None);
        assert_eq!(link.get_url(), "https://test.com/page");
        assert_eq!(link.get_title(), "Test Page");
        assert!(!link.get_uuid().is_nil());
    }

    #[test]
    fn test_important_link_input() {
        let input = ImportantLinkInput::new(
            "https://example.com".to_string(),
            Some("Example".to_string()),
        );

        assert_eq!(input.url, "https://example.com");
        assert_eq!(input.title, Some("Example".to_string()));
    }

    #[test]
    fn test_important_link_input_without_title() {
        let input = ImportantLinkInput::new("https://example.com".to_string(), None);

        assert_eq!(input.url, "https://example.com");
        assert_eq!(input.title, None);
    }

    #[test]
    fn test_serialization() {
        let link = ImportantLink::new(
            "https://serial.test.com".to_string(),
            Some("Serial Test".to_string()),
        );

        let json = serde_json::to_string(&link).expect("serialize");
        assert!(json.contains("serial.test.com"));
        assert!(json.contains("Serial Test"));

        let parsed: ImportantLink = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(parsed.url, link.url);
        assert_eq!(parsed.title, link.title);
        assert_eq!(parsed.uuid, link.uuid);
    }

    #[test]
    fn test_input_serialization() {
        let input = ImportantLinkInput::new(
            "https://input.test.com".to_string(),
            Some("Input Test".to_string()),
        );

        let json = serde_json::to_string(&input).expect("serialize");
        let parsed: ImportantLinkInput = serde_json::from_str(&json).expect("deserialize");

        assert_eq!(parsed.url, input.url);
        assert_eq!(parsed.title, input.title);
    }

    #[test]
    fn test_equality() {
        let link1 = ImportantLink::new("https://test.com".to_string(), Some("Test".to_string()));
        let link2 = ImportantLink::new("https://test.com".to_string(), Some("Test".to_string()));

        // Different UUIDs mean they're not equal
        assert_ne!(link1, link2);

        // Same link is equal to itself
        assert_eq!(link1, link1.clone());
    }

    #[test]
    fn test_ordering() {
        let link1 = ImportantLink::new("https://a.com".to_string(), Some("A".to_string()));
        let link2 = ImportantLink::new("https://b.com".to_string(), Some("B".to_string()));

        // Ordering should be consistent
        let cmp1 = link1.cmp(&link2);
        let cmp2 = link2.cmp(&link1);
        assert!(cmp1.is_lt() || cmp1.is_gt());
        assert_eq!(cmp1.reverse(), cmp2);
    }
}
