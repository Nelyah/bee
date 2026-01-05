//! Task urgency scoring module.
//!
//! This module computes a sophisticated urgency score for tasks based on multiple factors:
//! - Due date proximity (overdue tasks score highest)
//! - Blocking relationships (tasks that block others are more urgent)
//! - Activity momentum (recently worked tasks maintain priority)
//! - Age (old lingering tasks need attention)
//! - Staleness penalty (abandoned tasks sink)
//! - Status (active tasks boosted, blocked tasks deprioritized)
//! - Tags (user-defined priority markers)
//! - External links (GitLab/Jira activity signals)
//!
//! Score interpretation:
//! - Negative: deprioritized (blocked, stale, "low" tagged)
//! - Zero: neutral baseline (new pending task)
//! - Positive: urgent (due soon, blocking others, active work)

use serde::Deserialize;

use crate::external_links::ExternalLink;
use crate::task::TaskStatus;

/// Configuration for urgency scoring weights.
/// All weights can be customized via bee.toml.
#[derive(Debug, Clone, Deserialize, PartialEq)]
#[serde(default)]
pub struct UrgencyConfig {
    // Due date weights
    /// Maximum score for overdue tasks (default: 40)
    pub due_overdue_max: i64,
    /// Exponential decay rate for overdue calculation (default: 0.1)
    pub due_overdue_decay: f64,
    /// Score for tasks due today/tomorrow (default: 25)
    pub due_today: i64,
    /// Score for tasks due in 2-3 days (default: 15)
    pub due_three_days: i64,
    /// Score for tasks due in 4-7 days (default: 8)
    pub due_week: i64,
    /// Score for tasks due in 8-14 days (default: 3)
    pub due_two_weeks: i64,

    // Blocking weights
    /// Score for first blocked task (default: 12)
    pub blocking_first: i64,
    /// Maximum blocking score (default: 30)
    pub blocking_max: i64,

    // Activity weights
    /// Base score for activity today (default: 8)
    pub activity_active_today: i64,
    /// Additional score per recent update (default: 2)
    pub activity_per_update: i64,
    /// Maximum updates to count (default: 5)
    pub activity_max_updates: usize,

    // Age weights
    /// Age thresholds in days [14, 30, 60, 90] with scores [3, 6, 9, 12]
    pub age_threshold_2_weeks: i64,
    pub age_threshold_1_month: i64,
    pub age_threshold_2_months: i64,
    pub age_max: i64,

    // Staleness penalty
    /// Staleness thresholds: 7+ days = -3, 14+ days = -8, 30+ days = max penalty
    pub staleness_week_penalty: i64,
    pub staleness_two_weeks_penalty: i64,
    pub staleness_max_penalty: i64,

    // Status weights
    /// Score for Active status (default: 15)
    pub status_active: i64,
    /// Score for Blocked status (default: -25)
    pub status_blocked: i64,

    // Tag weights
    /// Score for "next" tag (default: 20)
    pub tag_next: i64,
    /// Score for "urgent"/"critical" tags (default: 15)
    pub tag_urgent: i64,
    /// Score for "important"/"priority" tags (default: 10)
    pub tag_important: i64,
    /// Score for "low"/"someday" tags (default: -10)
    pub tag_low: i64,
    /// Score for "waiting" tag (default: -15)
    pub tag_waiting: i64,
    /// Maximum positive tag score (default: 30)
    pub tag_max_positive: i64,
    /// Maximum negative tag score (default: -25)
    pub tag_max_negative: i64,

    // External link weights
    /// Score for failed GitLab pipeline (default: 20)
    pub external_pipeline_failed: i64,
    /// Score for MR awaiting approval (default: 10)
    pub external_awaiting_approval: i64,
    /// Score for high discussion activity (>5 notes) (default: 8)
    pub external_high_activity: i64,
    /// Score for medium discussion activity (3-5 notes) (default: 4)
    pub external_medium_activity: i64,
    /// Score for Jira "in review" status (default: 8)
    pub external_jira_review: i64,
    /// Score for Jira "blocked" status (default: 5)
    pub external_jira_blocked: i64,
    /// Score for sync errors (default: 3)
    pub external_sync_error: i64,
    /// Maximum external link score (default: 35)
    pub external_max: i64,
}

impl Default for UrgencyConfig {
    fn default() -> Self {
        Self {
            // Due date
            due_overdue_max: 40,
            due_overdue_decay: 0.1,
            due_today: 25,
            due_three_days: 15,
            due_week: 8,
            due_two_weeks: 3,

            // Blocking
            blocking_first: 12,
            blocking_max: 30,

            // Activity
            activity_active_today: 8,
            activity_per_update: 2,
            activity_max_updates: 5,

            // Age
            age_threshold_2_weeks: 3,
            age_threshold_1_month: 6,
            age_threshold_2_months: 9,
            age_max: 12,

            // Staleness
            staleness_week_penalty: -3,
            staleness_two_weeks_penalty: -8,
            staleness_max_penalty: -15,

            // Status
            status_active: 15,
            status_blocked: -25,

            // Tags
            tag_next: 20,
            tag_urgent: 15,
            tag_important: 10,
            tag_low: -10,
            tag_waiting: -15,
            tag_max_positive: 30,
            tag_max_negative: -25,

            // External
            external_pipeline_failed: 20,
            external_awaiting_approval: 10,
            external_high_activity: 8,
            external_medium_activity: 4,
            external_jira_review: 8,
            external_jira_blocked: 5,
            external_sync_error: 3,
            external_max: 35,
        }
    }
}

/// Cached GitLab MR data for urgency scoring.
#[derive(Debug, Deserialize)]
pub struct GitlabCachedMR {
    pub pipeline_status: Option<String>,
    pub approved: Option<bool>,
    pub user_notes_count: Option<i64>,
}

/// Cached Jira issue data for urgency scoring.
#[derive(Debug, Deserialize)]
pub struct JiraCachedIssue {
    pub status: String,
}

// =============================================================================
// Component Functions
// =============================================================================

/// Compute urgency component from due date.
///
/// - Overdue tasks: exponential curve up to max (higher = more urgent)
/// - Due today/tomorrow: high score
/// - Due within week: moderate score
/// - Due far out: zero
///
/// # Arguments
/// * `days_until_due` - Days until due date (negative if overdue)
/// * `config` - Urgency configuration
///
/// # Returns
/// Score from 0 to due_overdue_max
pub fn due_component(days_until_due: f64, config: &UrgencyConfig) -> i64 {
    if days_until_due < 0.0 {
        // OVERDUE: use exponential curve 1 - e^(-decay * days)
        // This approaches max asymptotically, preventing score explosion
        let overdue_days = -days_until_due;
        let score = config.due_overdue_max as f64
            * (1.0 - (-config.due_overdue_decay * overdue_days).exp());
        score.round() as i64
    } else if days_until_due <= 1.0 {
        config.due_today
    } else if days_until_due <= 3.0 {
        config.due_three_days
    } else if days_until_due <= 7.0 {
        config.due_week
    } else if days_until_due <= 14.0 {
        config.due_two_weeks
    } else {
        0
    }
}

/// Compute urgency component from blocking relationships.
///
/// Tasks that block other tasks get priority boost with diminishing returns.
///
/// # Arguments
/// * `blocked_count` - Number of tasks this task is blocking
/// * `config` - Urgency configuration
///
/// # Returns
/// Score from 0 to blocking_max
pub fn blocking_component(blocked_count: usize, config: &UrgencyConfig) -> i64 {
    if blocked_count == 0 {
        return 0;
    }

    // Diminishing returns: first task adds most, subsequent add less
    // 1 -> first, 2 -> first + 0.66*first, 3 -> first + 0.66*first + 0.33*first, etc.
    let first = config.blocking_first as f64;
    let score = match blocked_count {
        1 => first,
        2 => first + first * 0.66,
        3 => first + first * 0.66 + first * 0.5,
        _ => {
            // Base for 3, then +2 per additional up to max
            let base = first + first * 0.66 + first * 0.5;
            let additional = ((blocked_count - 3).min(4) * 2) as f64;
            base + additional
        }
    };

    (score.round() as i64).min(config.blocking_max)
}

/// Compute urgency component from recent activity.
///
/// Recent activity indicates momentum - keep working on it.
///
/// # Arguments
/// * `days_since_last` - Days since last activity (from history)
/// * `updates_last_7d` - Number of updates in the last 7 days
/// * `config` - Urgency configuration
///
/// # Returns
/// Score from 0 to (activity_active_today + activity_per_update * activity_max_updates)
pub fn activity_component(
    days_since_last: f64,
    updates_last_7d: usize,
    config: &UrgencyConfig,
) -> i64 {
    if days_since_last <= 1.0 {
        // Active today: base + bonus per recent update
        let update_bonus = (updates_last_7d.min(config.activity_max_updates)
            * config.activity_per_update as usize) as i64;
        config.activity_active_today + update_bonus
    } else if days_since_last <= 3.0 {
        // Active recently: reduced base + smaller bonus
        let update_bonus = updates_last_7d.min(3) as i64;
        5 + update_bonus
    } else if days_since_last <= 7.0 {
        // Active this week: minimal score
        2
    } else {
        0
    }
}

/// Compute urgency component from task age.
///
/// Old pending tasks accumulate urgency (they're lingering).
///
/// # Arguments
/// * `age_days` - Days since task creation
/// * `config` - Urgency configuration
///
/// # Returns
/// Score from 0 to age_max
pub fn age_component(age_days: f64, config: &UrgencyConfig) -> i64 {
    if age_days < 14.0 {
        0
    } else if age_days < 30.0 {
        config.age_threshold_2_weeks
    } else if age_days < 60.0 {
        config.age_threshold_1_month
    } else if age_days < 90.0 {
        config.age_threshold_2_months
    } else {
        config.age_max
    }
}

/// Compute staleness penalty.
///
/// Old tasks with no recent activity are probably abandoned - deprioritize.
/// Note: Only applies to tasks older than 14 days.
///
/// # Arguments
/// * `days_since_last` - Days since last activity
/// * `age_days` - Days since task creation
/// * `config` - Urgency configuration
///
/// # Returns
/// Score from staleness_max_penalty to 0 (always <= 0)
pub fn staleness_penalty(days_since_last: f64, age_days: f64, config: &UrgencyConfig) -> i64 {
    // New tasks can't be stale
    if age_days < 14.0 {
        return 0;
    }

    if days_since_last > 30.0 {
        config.staleness_max_penalty
    } else if days_since_last > 14.0 {
        config.staleness_two_weeks_penalty
    } else if days_since_last > 7.0 {
        config.staleness_week_penalty
    } else {
        0
    }
}

/// Compute status modifier.
///
/// - Active: user is working on it, boost priority
/// - Blocked: can't act on it, deprioritize
/// - Pending: neutral
///
/// # Arguments
/// * `status` - Task status
/// * `config` - Urgency configuration
///
/// # Returns
/// Score from status_blocked to status_active
pub fn status_modifier(status: TaskStatus, config: &UrgencyConfig) -> i64 {
    match status {
        TaskStatus::Active => config.status_active,
        TaskStatus::Blocked => config.status_blocked,
        TaskStatus::Pending => 0,
        TaskStatus::Completed | TaskStatus::Deleted => 0,
    }
}

/// Compute tag modifier.
///
/// Recognizes common priority tags and applies weights.
/// Multiple tags stack but are clamped to prevent gaming.
///
/// # Arguments
/// * `tags` - Task tags
/// * `config` - Urgency configuration
///
/// # Returns
/// Score clamped between tag_max_negative and tag_max_positive
pub fn tag_modifier(tags: &[String], config: &UrgencyConfig) -> i64 {
    let mut score = 0i64;

    for tag in tags {
        let tag_lower = tag.to_lowercase();
        score += match tag_lower.as_str() {
            "next" => config.tag_next,
            "urgent" | "critical" => config.tag_urgent,
            "important" | "priority" => config.tag_important,
            "low" | "someday" => config.tag_low,
            "waiting" => config.tag_waiting,
            _ => 0,
        };
    }

    score.clamp(config.tag_max_negative, config.tag_max_positive)
}

/// Compute external link urgency component.
///
/// Parses cached GitLab/Jira responses to extract urgency signals:
/// - GitLab: pipeline failures, pending approval, discussion activity
/// - Jira: review status, blocked status
///
/// # Arguments
/// * `external_links` - Task's external links with cached responses
/// * `config` - Urgency configuration
///
/// # Returns
/// Score from 0 to external_max
pub fn external_link_component(external_links: &[ExternalLink], config: &UrgencyConfig) -> i64 {
    let mut score = 0i64;

    for link in external_links {
        // Check for sync errors
        if link.sync_error.is_some() {
            score += config.external_sync_error;
        }

        // Parse cached response if available
        let Some(cached) = &link.cached_response else {
            continue;
        };

        match link.provider.as_str() {
            "gitlab" => {
                if let Ok(mr) = serde_json::from_str::<GitlabCachedMR>(cached) {
                    // Pipeline failed = CI broken, needs attention
                    if mr.pipeline_status.as_deref() == Some("failed") {
                        score += config.external_pipeline_failed;
                    }

                    // Awaiting approval = others waiting on review
                    if mr.approved == Some(false) {
                        score += config.external_awaiting_approval;
                    }

                    // High discussion activity = active engagement
                    let notes = mr.user_notes_count.unwrap_or(0);
                    if notes > 5 {
                        score += config.external_high_activity;
                    } else if notes > 2 {
                        score += config.external_medium_activity;
                    }
                }
            }
            "jira" => {
                if let Ok(issue) = serde_json::from_str::<JiraCachedIssue>(cached) {
                    let status_lower = issue.status.to_lowercase();

                    // In review = someone's looking at it
                    if status_lower.contains("review") {
                        score += config.external_jira_review;
                    }

                    // Blocked externally
                    if status_lower.contains("blocked") {
                        score += config.external_jira_blocked;
                    }
                }
            }
            _ => {}
        }
    }

    score.clamp(0, config.external_max)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn default_config() -> UrgencyConfig {
        UrgencyConfig::default()
    }

    // =========================================================================
    // Due Date Component Tests
    // =========================================================================

    #[test]
    fn due_component_overdue_1_day() {
        let config = default_config();
        let score = due_component(-1.0, &config);
        // 40 * (1 - e^(-0.1 * 1)) ≈ 40 * 0.095 ≈ 4
        assert!((3..=5).contains(&score), "Expected ~4, got {}", score);
    }

    #[test]
    fn due_component_overdue_5_days() {
        let config = default_config();
        let score = due_component(-5.0, &config);
        // 40 * (1 - e^(-0.5)) ≈ 40 * 0.393 ≈ 16
        assert!((14..=18).contains(&score), "Expected ~16, got {}", score);
    }

    #[test]
    fn due_component_overdue_30_days() {
        let config = default_config();
        let score = due_component(-30.0, &config);
        // 40 * (1 - e^(-3)) ≈ 40 * 0.95 ≈ 38
        assert!((35..=40).contains(&score), "Expected ~38, got {}", score);
    }

    #[test]
    fn due_component_overdue_100_days() {
        let config = default_config();
        let score = due_component(-100.0, &config);
        // Should be at or very close to max (40)
        assert!((39..=40).contains(&score), "Expected ~40, got {}", score);
    }

    #[test]
    fn due_component_due_today() {
        let config = default_config();
        assert_eq!(due_component(0.0, &config), 25);
        assert_eq!(due_component(0.5, &config), 25);
        assert_eq!(due_component(1.0, &config), 25);
    }

    #[test]
    fn due_component_due_in_2_days() {
        let config = default_config();
        assert_eq!(due_component(2.0, &config), 15);
    }

    #[test]
    fn due_component_due_in_3_days() {
        let config = default_config();
        assert_eq!(due_component(3.0, &config), 15);
    }

    #[test]
    fn due_component_due_in_5_days() {
        let config = default_config();
        assert_eq!(due_component(5.0, &config), 8);
    }

    #[test]
    fn due_component_due_in_7_days() {
        let config = default_config();
        assert_eq!(due_component(7.0, &config), 8);
    }

    #[test]
    fn due_component_due_in_10_days() {
        let config = default_config();
        assert_eq!(due_component(10.0, &config), 3);
    }

    #[test]
    fn due_component_due_in_14_days() {
        let config = default_config();
        assert_eq!(due_component(14.0, &config), 3);
    }

    #[test]
    fn due_component_due_in_30_days() {
        let config = default_config();
        assert_eq!(due_component(30.0, &config), 0);
    }

    #[test]
    fn due_component_due_in_365_days() {
        let config = default_config();
        assert_eq!(due_component(365.0, &config), 0);
    }

    // =========================================================================
    // Blocking Component Tests
    // =========================================================================

    #[test]
    fn blocking_component_zero_blocked() {
        let config = default_config();
        assert_eq!(blocking_component(0, &config), 0);
    }

    #[test]
    fn blocking_component_one_blocked() {
        let config = default_config();
        assert_eq!(blocking_component(1, &config), 12);
    }

    #[test]
    fn blocking_component_two_blocked() {
        let config = default_config();
        let score = blocking_component(2, &config);
        // 12 + 12*0.66 = 12 + 7.92 ≈ 20
        assert_eq!(score, 20);
    }

    #[test]
    fn blocking_component_three_blocked() {
        let config = default_config();
        let score = blocking_component(3, &config);
        // 12 + 7.92 + 6 = 25.92 ≈ 26
        assert_eq!(score, 26);
    }

    #[test]
    fn blocking_component_ten_blocked() {
        let config = default_config();
        let score = blocking_component(10, &config);
        // Should be capped at 30
        assert_eq!(score, 30);
    }

    #[test]
    fn blocking_component_hundred_blocked() {
        let config = default_config();
        let score = blocking_component(100, &config);
        // Should be capped at 30
        assert_eq!(score, 30);
    }

    // =========================================================================
    // Activity Component Tests
    // =========================================================================

    #[test]
    fn activity_component_active_today_no_updates() {
        let config = default_config();
        assert_eq!(activity_component(0.5, 0, &config), 8);
    }

    #[test]
    fn activity_component_active_today_1_update() {
        let config = default_config();
        assert_eq!(activity_component(0.5, 1, &config), 10);
    }

    #[test]
    fn activity_component_active_today_5_updates() {
        let config = default_config();
        assert_eq!(activity_component(0.5, 5, &config), 18);
    }

    #[test]
    fn activity_component_active_today_10_updates() {
        let config = default_config();
        // Capped at 5 updates
        assert_eq!(activity_component(0.5, 10, &config), 18);
    }

    #[test]
    fn activity_component_active_2_days_ago() {
        let config = default_config();
        let score = activity_component(2.0, 2, &config);
        assert_eq!(score, 7); // 5 + 2
    }

    #[test]
    fn activity_component_active_5_days_ago() {
        let config = default_config();
        assert_eq!(activity_component(5.0, 5, &config), 2);
    }

    #[test]
    fn activity_component_active_8_days_ago() {
        let config = default_config();
        assert_eq!(activity_component(8.0, 5, &config), 0);
    }

    #[test]
    fn activity_component_active_30_days_ago() {
        let config = default_config();
        assert_eq!(activity_component(30.0, 5, &config), 0);
    }

    // =========================================================================
    // Age Component Tests
    // =========================================================================

    #[test]
    fn age_component_0_days() {
        let config = default_config();
        assert_eq!(age_component(0.0, &config), 0);
    }

    #[test]
    fn age_component_13_days() {
        let config = default_config();
        assert_eq!(age_component(13.0, &config), 0);
    }

    #[test]
    fn age_component_14_days() {
        let config = default_config();
        assert_eq!(age_component(14.0, &config), 3);
    }

    #[test]
    fn age_component_29_days() {
        let config = default_config();
        assert_eq!(age_component(29.0, &config), 3);
    }

    #[test]
    fn age_component_30_days() {
        let config = default_config();
        assert_eq!(age_component(30.0, &config), 6);
    }

    #[test]
    fn age_component_59_days() {
        let config = default_config();
        assert_eq!(age_component(59.0, &config), 6);
    }

    #[test]
    fn age_component_60_days() {
        let config = default_config();
        assert_eq!(age_component(60.0, &config), 9);
    }

    #[test]
    fn age_component_90_days() {
        let config = default_config();
        assert_eq!(age_component(90.0, &config), 12);
    }

    #[test]
    fn age_component_365_days() {
        let config = default_config();
        assert_eq!(age_component(365.0, &config), 12);
    }

    // =========================================================================
    // Staleness Penalty Tests
    // =========================================================================

    #[test]
    fn staleness_new_task_no_activity() {
        let config = default_config();
        // New task (< 14 days old) can't be stale
        assert_eq!(staleness_penalty(100.0, 10.0, &config), 0);
    }

    #[test]
    fn staleness_old_task_active_today() {
        let config = default_config();
        assert_eq!(staleness_penalty(0.5, 60.0, &config), 0);
    }

    #[test]
    fn staleness_old_task_active_7_days() {
        let config = default_config();
        assert_eq!(staleness_penalty(7.0, 60.0, &config), 0);
    }

    #[test]
    fn staleness_old_task_active_8_days() {
        let config = default_config();
        assert_eq!(staleness_penalty(8.0, 60.0, &config), -3);
    }

    #[test]
    fn staleness_old_task_active_14_days() {
        let config = default_config();
        assert_eq!(staleness_penalty(14.0, 60.0, &config), -3);
    }

    #[test]
    fn staleness_old_task_active_15_days() {
        let config = default_config();
        assert_eq!(staleness_penalty(15.0, 60.0, &config), -8);
    }

    #[test]
    fn staleness_old_task_active_30_days() {
        let config = default_config();
        assert_eq!(staleness_penalty(30.0, 60.0, &config), -8);
    }

    #[test]
    fn staleness_old_task_active_31_days() {
        let config = default_config();
        assert_eq!(staleness_penalty(31.0, 60.0, &config), -15);
    }

    #[test]
    fn staleness_old_task_active_100_days() {
        let config = default_config();
        assert_eq!(staleness_penalty(100.0, 120.0, &config), -15);
    }

    // =========================================================================
    // Status Modifier Tests
    // =========================================================================

    #[test]
    fn status_modifier_pending() {
        let config = default_config();
        assert_eq!(status_modifier(TaskStatus::Pending, &config), 0);
    }

    #[test]
    fn status_modifier_active() {
        let config = default_config();
        assert_eq!(status_modifier(TaskStatus::Active, &config), 15);
    }

    #[test]
    fn status_modifier_blocked() {
        let config = default_config();
        assert_eq!(status_modifier(TaskStatus::Blocked, &config), -25);
    }

    #[test]
    fn status_modifier_completed() {
        let config = default_config();
        assert_eq!(status_modifier(TaskStatus::Completed, &config), 0);
    }

    #[test]
    fn status_modifier_deleted() {
        let config = default_config();
        assert_eq!(status_modifier(TaskStatus::Deleted, &config), 0);
    }

    // =========================================================================
    // Tag Modifier Tests
    // =========================================================================

    #[test]
    fn tag_modifier_no_tags() {
        let config = default_config();
        assert_eq!(tag_modifier(&[], &config), 0);
    }

    #[test]
    fn tag_modifier_next() {
        let config = default_config();
        assert_eq!(tag_modifier(&["next".to_string()], &config), 20);
    }

    #[test]
    fn tag_modifier_urgent() {
        let config = default_config();
        assert_eq!(tag_modifier(&["urgent".to_string()], &config), 15);
    }

    #[test]
    fn tag_modifier_critical() {
        let config = default_config();
        assert_eq!(tag_modifier(&["critical".to_string()], &config), 15);
    }

    #[test]
    fn tag_modifier_important() {
        let config = default_config();
        assert_eq!(tag_modifier(&["important".to_string()], &config), 10);
    }

    #[test]
    fn tag_modifier_low() {
        let config = default_config();
        assert_eq!(tag_modifier(&["low".to_string()], &config), -10);
    }

    #[test]
    fn tag_modifier_waiting() {
        let config = default_config();
        assert_eq!(tag_modifier(&["waiting".to_string()], &config), -15);
    }

    #[test]
    fn tag_modifier_multiple_positive() {
        let config = default_config();
        // next (20) + urgent (15) = 35, but clamped to 30
        let tags = vec!["next".to_string(), "urgent".to_string()];
        assert_eq!(tag_modifier(&tags, &config), 30);
    }

    #[test]
    fn tag_modifier_multiple_negative() {
        let config = default_config();
        // low (-10) + waiting (-15) = -25, exactly at clamp
        let tags = vec!["low".to_string(), "waiting".to_string()];
        assert_eq!(tag_modifier(&tags, &config), -25);
    }

    #[test]
    fn tag_modifier_mixed() {
        let config = default_config();
        // next (20) + low (-10) = 10
        let tags = vec!["next".to_string(), "low".to_string()];
        assert_eq!(tag_modifier(&tags, &config), 10);
    }

    #[test]
    fn tag_modifier_unknown_tag() {
        let config = default_config();
        assert_eq!(tag_modifier(&["foobar".to_string()], &config), 0);
    }

    #[test]
    fn tag_modifier_case_insensitive() {
        let config = default_config();
        assert_eq!(tag_modifier(&["NEXT".to_string()], &config), 20);
        assert_eq!(tag_modifier(&["Next".to_string()], &config), 20);
        assert_eq!(tag_modifier(&["URGENT".to_string()], &config), 15);
    }

    // =========================================================================
    // External Link Component Tests
    // =========================================================================

    #[test]
    fn external_gitlab_no_links() {
        let config = default_config();
        assert_eq!(external_link_component(&[], &config), 0);
    }

    #[test]
    fn external_gitlab_no_cached_response() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "gitlab".to_string(),
            url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
            external_key: "mr:foo/bar:1".to_string(),
            cached_response: None,
            last_synced_at: None,
            sync_error: None,
        }];
        assert_eq!(external_link_component(&links, &config), 0);
    }

    #[test]
    fn external_gitlab_pipeline_failed() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "gitlab".to_string(),
            url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
            external_key: "mr:foo/bar:1".to_string(),
            cached_response: Some(r#"{"pipeline_status": "failed"}"#.to_string()),
            last_synced_at: None,
            sync_error: None,
        }];
        assert_eq!(external_link_component(&links, &config), 20);
    }

    #[test]
    fn external_gitlab_pipeline_success() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "gitlab".to_string(),
            url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
            external_key: "mr:foo/bar:1".to_string(),
            cached_response: Some(r#"{"pipeline_status": "success"}"#.to_string()),
            last_synced_at: None,
            sync_error: None,
        }];
        assert_eq!(external_link_component(&links, &config), 0);
    }

    #[test]
    fn external_gitlab_awaiting_approval() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "gitlab".to_string(),
            url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
            external_key: "mr:foo/bar:1".to_string(),
            cached_response: Some(r#"{"approved": false}"#.to_string()),
            last_synced_at: None,
            sync_error: None,
        }];
        assert_eq!(external_link_component(&links, &config), 10);
    }

    #[test]
    fn external_gitlab_high_notes_count() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "gitlab".to_string(),
            url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
            external_key: "mr:foo/bar:1".to_string(),
            cached_response: Some(r#"{"user_notes_count": 10}"#.to_string()),
            last_synced_at: None,
            sync_error: None,
        }];
        assert_eq!(external_link_component(&links, &config), 8);
    }

    #[test]
    fn external_gitlab_medium_notes_count() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "gitlab".to_string(),
            url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
            external_key: "mr:foo/bar:1".to_string(),
            cached_response: Some(r#"{"user_notes_count": 4}"#.to_string()),
            last_synced_at: None,
            sync_error: None,
        }];
        assert_eq!(external_link_component(&links, &config), 4);
    }

    #[test]
    fn external_gitlab_combined_signals() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "gitlab".to_string(),
            url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
            external_key: "mr:foo/bar:1".to_string(),
            cached_response: Some(
                r#"{"pipeline_status": "failed", "approved": false, "user_notes_count": 10}"#
                    .to_string(),
            ),
            last_synced_at: None,
            sync_error: None,
        }];
        // 20 (failed) + 10 (not approved) + 8 (high notes) = 38, capped at 35
        assert_eq!(external_link_component(&links, &config), 35);
    }

    #[test]
    fn external_gitlab_malformed_json() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "gitlab".to_string(),
            url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
            external_key: "mr:foo/bar:1".to_string(),
            cached_response: Some("not valid json".to_string()),
            last_synced_at: None,
            sync_error: None,
        }];
        // Should gracefully handle malformed JSON
        assert_eq!(external_link_component(&links, &config), 0);
    }

    #[test]
    fn external_jira_status_in_review() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "jira".to_string(),
            url: "https://jira.example.com/browse/PROJ-123".to_string(),
            external_key: "PROJ-123".to_string(),
            cached_response: Some(r#"{"status": "In Review"}"#.to_string()),
            last_synced_at: None,
            sync_error: None,
        }];
        assert_eq!(external_link_component(&links, &config), 8);
    }

    #[test]
    fn external_jira_status_blocked() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "jira".to_string(),
            url: "https://jira.example.com/browse/PROJ-123".to_string(),
            external_key: "PROJ-123".to_string(),
            cached_response: Some(r#"{"status": "Blocked"}"#.to_string()),
            last_synced_at: None,
            sync_error: None,
        }];
        assert_eq!(external_link_component(&links, &config), 5);
    }

    #[test]
    fn external_jira_case_insensitive() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "jira".to_string(),
            url: "https://jira.example.com/browse/PROJ-123".to_string(),
            external_key: "PROJ-123".to_string(),
            cached_response: Some(r#"{"status": "IN REVIEW"}"#.to_string()),
            last_synced_at: None,
            sync_error: None,
        }];
        assert_eq!(external_link_component(&links, &config), 8);
    }

    #[test]
    fn external_sync_error_adds_score() {
        let config = default_config();
        let links = vec![ExternalLink {
            id: 1,
            task_uuid: uuid::Uuid::new_v4(),
            provider: "gitlab".to_string(),
            url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
            external_key: "mr:foo/bar:1".to_string(),
            cached_response: None,
            last_synced_at: None,
            sync_error: Some("Connection timeout".to_string()),
        }];
        assert_eq!(external_link_component(&links, &config), 3);
    }

    #[test]
    fn external_multiple_links() {
        let config = default_config();
        let links = vec![
            ExternalLink {
                id: 1,
                task_uuid: uuid::Uuid::new_v4(),
                provider: "gitlab".to_string(),
                url: "https://gitlab.com/foo/bar/-/merge_requests/1".to_string(),
                external_key: "mr:foo/bar:1".to_string(),
                cached_response: Some(r#"{"pipeline_status": "failed"}"#.to_string()),
                last_synced_at: None,
                sync_error: None,
            },
            ExternalLink {
                id: 2,
                task_uuid: uuid::Uuid::new_v4(),
                provider: "jira".to_string(),
                url: "https://jira.example.com/browse/PROJ-123".to_string(),
                external_key: "PROJ-123".to_string(),
                cached_response: Some(r#"{"status": "In Review"}"#.to_string()),
                last_synced_at: None,
                sync_error: None,
            },
        ];
        // 20 (gitlab failed) + 8 (jira review) = 28
        assert_eq!(external_link_component(&links, &config), 28);
    }
}
