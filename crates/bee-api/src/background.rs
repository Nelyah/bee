//! Background tasks for the bee-api service.
//!
//! This module contains long-running background jobs that execute alongside
//! the main API server.

use std::time::Duration;

use bee_core::UserFacingError;
use bee_core::config::ExternalLinksConfig;
use reqwest::Client;
use tokio::time::{MissedTickBehavior, interval};

use crate::config::SyncConfig;
use crate::external_links::sync_links_batch;

/// Spawns the background external links sync job.
///
/// The job runs periodically (default every 15 minutes) and syncs external links
/// that have become stale (not synced within `stale_after_hours`).
///
/// This keeps urgency scores based on GitLab/Jira data up-to-date without
/// requiring explicit user action.
///
/// # Arguments
///
/// * `external_links_config` - Provider configuration (GitLab/Jira base URLs and tokens)
/// * `sync_config` - Sync settings (stale threshold, batch size, interval)
///
/// # Behavior
///
/// - If `sync_config.background_enabled` is false, returns immediately without spawning
/// - The job logs sync results at info level
/// - Errors are logged but don't stop the job; it will retry on the next interval
/// - Uses `MissedTickBehavior::Delay` to avoid burst syncing after delays
pub fn spawn_external_links_sync_job(
    external_links_config: ExternalLinksConfig,
    sync_config: SyncConfig,
) {
    if !sync_config.background_enabled {
        log::info!("Background external links sync is disabled");
        return;
    }

    let interval_mins = sync_config.background_interval_minutes;
    log::info!(
        "Starting background external links sync (interval: {} minutes, stale after: {} hours)",
        interval_mins,
        sync_config.stale_after_hours
    );

    tokio::spawn(async move {
        run_sync_loop(external_links_config, sync_config).await;
    });
}

async fn run_sync_loop(external_links_config: ExternalLinksConfig, sync_config: SyncConfig) {
    let interval_duration = Duration::from_secs(sync_config.background_interval_minutes * 60);
    let mut tick = interval(interval_duration);

    // Don't burst sync if we fall behind - just wait for the next tick
    tick.set_missed_tick_behavior(MissedTickBehavior::Delay);

    // Skip the first immediate tick - wait for the first interval to pass
    tick.tick().await;

    let client = Client::new();

    loop {
        tick.tick().await;

        log::debug!("Running background external links sync");

        match sync_links_batch(
            &client,
            &external_links_config,
            &sync_config,
            None,  // All providers
            None,  // All tasks
            false, // Only stale links
        )
        .await
        {
            Ok(result) => {
                if result.attempted > 0 {
                    log::info!(
                        "Background sync complete: {}/{} succeeded ({} failed)",
                        result.succeeded,
                        result.attempted,
                        result.failed
                    );
                    if !result.errors.is_empty() {
                        log::warn!("Sync errors: {:?}", result.errors);
                    }
                } else {
                    log::debug!("Background sync: no stale links to sync");
                }
            }
            Err(err) => {
                log::error!("Background sync failed: {}", err.developer_message());
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sync_config_defaults() {
        let config = SyncConfig::default();
        assert!(config.background_enabled);
        assert_eq!(config.background_interval_minutes, 15);
        assert_eq!(config.stale_after_hours, 24);
        assert_eq!(config.batch_size, 10);
    }

    #[test]
    fn test_disabled_sync_returns_immediately() {
        let config = SyncConfig {
            background_enabled: false,
            ..Default::default()
        };
        // This just verifies the function doesn't panic when disabled
        spawn_external_links_sync_job(ExternalLinksConfig::default(), config);
    }
}
