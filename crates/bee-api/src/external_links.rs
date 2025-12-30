use crate::config::SyncConfig;
use crate::dto::{
    ExternalLinkResolveResponse, ExternalLinkSyncResponse, GitlabMergeRequestDto, JiraIssueDto,
};
use bee_core::config::{ExternalLinksConfig, ProviderConfig};
use bee_core::external_links::ExternalLink;
use bee_core::storage::db::DbStore;
use chrono::{DateTime, Duration, Local, Utc};
use reqwest::Client;
use serde::Deserialize;
use serde_json::Value;
use std::{env, fmt};
use tokio::time::{Duration as TokioDuration, sleep};
use url::Url;
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProviderKind {
    Jira,
    Gitlab,
}

impl fmt::Display for ProviderKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ProviderKind::Jira => write!(f, "jira"),
            ProviderKind::Gitlab => write!(f, "gitlab"),
        }
    }
}

impl ProviderKind {
    fn from_str(value: &str) -> Option<Self> {
        match value {
            "jira" => Some(ProviderKind::Jira),
            "gitlab" => Some(ProviderKind::Gitlab),
            _ => None,
        }
    }
}

pub struct ParsedExternalLink {
    pub provider: ProviderKind,
    pub external_key: String,
}

#[derive(Debug, Deserialize)]
pub struct SyncQuery {
    pub force: Option<bool>,
}

#[derive(Debug, Clone, Copy)]
pub enum JiraIssueScope {
    Assigned,
    Created,
    Both,
}

pub fn parse_external_link(
    url: &str,
    config: &ExternalLinksConfig,
) -> Result<ParsedExternalLink, String> {
    let url = Url::parse(url).map_err(|e| format!("Invalid URL: {e}"))?;
    let url_str = url.as_str();

    if let Some(jira) = &config.jira {
        if url_str.starts_with(&normalize_base_url(&jira.base_url)?) {
            let key = parse_jira_key(&url)?;
            return Ok(ParsedExternalLink {
                provider: ProviderKind::Jira,
                external_key: key,
            });
        }
    }

    if let Some(gitlab) = &config.gitlab {
        if url_str.starts_with(&normalize_base_url(&gitlab.base_url)?) {
            let key = parse_gitlab_key(&url)?;
            return Ok(ParsedExternalLink {
                provider: ProviderKind::Gitlab,
                external_key: key,
            });
        }
    }

    Err("URL does not match any configured provider base URL".to_string())
}

pub async fn sync_single_link(
    client: &Client,
    config: &ExternalLinksConfig,
    sync: &SyncConfig,
    link: ExternalLink,
    force: bool,
) -> Result<ExternalLinkSyncResponse, String> {
    let provider = ProviderKind::from_str(&link.provider)
        .ok_or_else(|| format!("Unknown provider {}", link.provider))?;

    if !force && !is_due(&link, sync.stale_after_hours) {
        return Ok(ExternalLinkSyncResponse {
            attempted: 0,
            succeeded: 0,
            failed: 0,
            errors: Vec::new(),
        });
    }

    let result = fetch_and_cache_link(client, config, &link, provider).await;
    match result {
        Ok(()) => Ok(ExternalLinkSyncResponse {
            attempted: 1,
            succeeded: 1,
            failed: 0,
            errors: Vec::new(),
        }),
        Err(err) => Ok(ExternalLinkSyncResponse {
            attempted: 1,
            succeeded: 0,
            failed: 1,
            errors: vec![err],
        }),
    }
}

pub async fn sync_links_batch(
    client: &Client,
    config: &ExternalLinksConfig,
    sync: &SyncConfig,
    provider_filter: Option<&str>,
    task_uuid: Option<Uuid>,
    force: bool,
) -> Result<ExternalLinkSyncResponse, String> {
    let links = DbStore::list_external_links(provider_filter, task_uuid)
        .await
        .map_err(|e| format!("Failed to load external links: {e}"))?;

    let mut due_links: Vec<ExternalLink> = links
        .into_iter()
        .filter(|link| force || is_due(link, sync.stale_after_hours))
        .collect();

    due_links.sort_by(|a, b| a.provider.cmp(&b.provider));

    let mut attempted = 0;
    let mut succeeded = 0;
    let mut failed = 0;
    let mut errors = Vec::new();

    let batch_size = sync.batch_size.max(1);

    let mut idx = 0;
    while idx < due_links.len() {
        let end = (idx + batch_size).min(due_links.len());
        let chunk = &due_links[idx..end];

        for link in chunk {
            let provider = match ProviderKind::from_str(&link.provider) {
                Some(p) => p,
                None => {
                    failed += 1;
                    errors.push(format!("Unknown provider {}", link.provider));
                    continue;
                }
            };

            attempted += 1;
            match fetch_and_cache_link(client, config, link, provider).await {
                Ok(()) => succeeded += 1,
                Err(err) => {
                    failed += 1;
                    errors.push(err);
                }
            }

            if let Some(delay) = provider_delay_ms(config, provider) {
                if delay > 0 {
                    sleep(TokioDuration::from_millis(delay)).await;
                }
            }
        }

        idx = end;
    }

    Ok(ExternalLinkSyncResponse {
        attempted,
        succeeded,
        failed,
        errors,
    })
}

pub async fn fetch_recent_gitlab_merge_requests(
    client: &Client,
    config: &ExternalLinksConfig,
    limit: usize,
) -> Result<Vec<GitlabMergeRequestDto>, String> {
    let cfg = config
        .gitlab
        .as_ref()
        .ok_or_else(|| "GitLab is not configured".to_string())?;
    let base = normalize_base_url(&cfg.base_url)?;
    let token = resolve_token(cfg)?;

    let user_url = format!("{base}/api/v4/user");
    let user_response = client
        .get(user_url)
        .header("PRIVATE-TOKEN", token.as_str())
        .header("Accept", "application/json")
        .send()
        .await
        .map_err(|e| format!("Failed to call GitLab user API: {e}"))?;
    let status = user_response.status();
    let body = user_response
        .text()
        .await
        .map_err(|e| format!("Failed to read GitLab user response: {e}"))?;
    if !status.is_success() {
        return Err(format!("GitLab user API error {status}: {body}"));
    }

    let user: GitlabUser =
        serde_json::from_str(&body).map_err(|e| format!("Invalid GitLab user JSON: {e}"))?;

    let url = format!(
        "{base}/api/v4/merge_requests?scope=all&author_id={}&order_by=updated_at&sort=desc&per_page={}",
        user.id,
        limit.max(1)
    );
    let response = client
        .get(url)
        .header("PRIVATE-TOKEN", token.as_str())
        .header("Accept", "application/json")
        .send()
        .await
        .map_err(|e| format!("Failed to call GitLab merge request API: {e}"))?;
    let status = response.status();
    let body = response
        .text()
        .await
        .map_err(|e| format!("Failed to read GitLab merge request response: {e}"))?;
    if !status.is_success() {
        return Err(format!("GitLab merge request API error {status}: {body}"));
    }

    let raw: Vec<GitlabMergeRequestRaw> = serde_json::from_str(&body)
        .map_err(|e| format!("Invalid GitLab merge request JSON: {e}"))?;

    let mut results = Vec::with_capacity(raw.len());
    for item in raw {
        let updated = match DateTime::parse_from_rfc3339(&item.updated_at) {
            Ok(value) => value,
            Err(_) => continue,
        };
        let project_path = extract_gitlab_project_path(&item.web_url).unwrap_or_default();
        let pipeline_status = item
            .head_pipeline
            .as_ref()
            .and_then(|pipeline| pipeline.status.clone())
            .or_else(|| {
                item.pipeline
                    .as_ref()
                    .and_then(|pipeline| pipeline.status.clone())
            });
        let approved = if project_path.is_empty() {
            None
        } else {
            match fetch_gitlab_approval_status(
                client,
                &base,
                token.as_str(),
                &project_path,
                item.iid,
            )
            .await
            {
                Ok(value) => value,
                Err(_) => None,
            }
        };

        if cfg.min_delay_ms > 0 {
            sleep(TokioDuration::from_millis(cfg.min_delay_ms)).await;
        }

        results.push(GitlabMergeRequestDto {
            iid: item.iid,
            title: item.title,
            web_url: item.web_url,
            project_path,
            state: item.state,
            user_notes_count: item.user_notes_count,
            approved,
            pipeline_status,
            updated_at: updated.with_timezone(&Local),
        });
    }

    Ok(results)
}

async fn fetch_gitlab_approval_status(
    client: &Client,
    base_url: &str,
    token: &str,
    project_path: &str,
    iid: i64,
) -> Result<Option<bool>, String> {
    let encoded_project = urlencoding::encode(project_path);
    let url =
        format!("{base_url}/api/v4/projects/{encoded_project}/merge_requests/{iid}/approvals");
    let response = client
        .get(url)
        .header("PRIVATE-TOKEN", token)
        .header("Accept", "application/json")
        .send()
        .await
        .map_err(|e| format!("Failed to call GitLab approval API: {e}"))?;
    let status = response.status();
    let body = response
        .text()
        .await
        .map_err(|e| format!("Failed to read GitLab approval response: {e}"))?;
    if !status.is_success() {
        return Err(format!("GitLab approval API error {status}: {body}"));
    }

    let payload: GitlabApprovalRaw =
        serde_json::from_str(&body).map_err(|e| format!("Invalid GitLab approval JSON: {e}"))?;
    Ok(payload.approved)
}

pub async fn fetch_recent_jira_issues(
    client: &Client,
    config: &ExternalLinksConfig,
    limit: usize,
    scope: JiraIssueScope,
) -> Result<Vec<JiraIssueDto>, String> {
    let cfg = config
        .jira
        .as_ref()
        .ok_or_else(|| "Jira is not configured".to_string())?;
    let base = normalize_base_url(&cfg.base_url)?;
    let token = resolve_token(cfg)?;

    let jql = match scope {
        JiraIssueScope::Assigned => "assignee = currentUser()",
        JiraIssueScope::Created => "reporter = currentUser()",
        JiraIssueScope::Both => "(assignee = currentUser() OR reporter = currentUser())",
    };
    let query = format!(
        "{base}/rest/api/3/search?jql={}&maxResults={}&fields=summary,status,assignee,updated",
        urlencoding::encode(&format!("{jql} ORDER BY updated DESC")),
        limit.max(1)
    );

    let response = client
        .get(query)
        .bearer_auth(token)
        .header("Accept", "application/json")
        .send()
        .await
        .map_err(|e| format!("Failed to call Jira search API: {e}"))?;
    let status = response.status();
    let body = response
        .text()
        .await
        .map_err(|e| format!("Failed to read Jira search response: {e}"))?;
    if !status.is_success() {
        return Err(format!("Jira search API error {status}: {body}"));
    }

    let raw: JiraSearchResponse =
        serde_json::from_str(&body).map_err(|e| format!("Invalid Jira search JSON: {e}"))?;

    Ok(raw
        .issues
        .into_iter()
        .filter_map(|issue| {
            let updated = DateTime::parse_from_rfc3339(&issue.fields.updated).ok()?;
            Some(JiraIssueDto {
                key: issue.key.clone(),
                summary: issue.fields.summary,
                status: issue.fields.status.name,
                web_url: format!("{base}/browse/{}", issue.key),
                updated_at: updated.with_timezone(&Local),
            })
        })
        .collect())
}

pub async fn resolve_external_link(
    client: &Client,
    config: &ExternalLinksConfig,
    provider: ProviderKind,
    input: &str,
) -> Result<ExternalLinkResolveResponse, String> {
    if input.starts_with("http://") || input.starts_with("https://") {
        return Ok(ExternalLinkResolveResponse {
            url: input.to_string(),
        });
    }

    match provider {
        ProviderKind::Jira => {
            let cfg = config
                .jira
                .as_ref()
                .ok_or_else(|| "Jira is not configured".to_string())?;
            let base = normalize_base_url(&cfg.base_url)?;

            if is_jira_key(input) {
                return Ok(ExternalLinkResolveResponse {
                    url: format!("{base}/browse/{input}"),
                });
            }

            let issues = fetch_recent_jira_issues(client, config, 20, JiraIssueScope::Both).await?;
            if let Some(match_issue) = issues
                .iter()
                .find(|issue| issue.summary.to_lowercase().contains(&input.to_lowercase()))
            {
                return Ok(ExternalLinkResolveResponse {
                    url: match_issue.web_url.clone(),
                });
            }
        }
        ProviderKind::Gitlab => {
            let cfg = config
                .gitlab
                .as_ref()
                .ok_or_else(|| "GitLab is not configured".to_string())?;
            let base = normalize_base_url(&cfg.base_url)?;

            let mrs = fetch_recent_gitlab_merge_requests(client, config, 20).await?;
            if let Ok(iid) = input.parse::<i64>() {
                if let Some(mr) = mrs.iter().find(|mr| mr.iid == iid) {
                    return Ok(ExternalLinkResolveResponse {
                        url: mr.web_url.clone(),
                    });
                }
            }

            if let Some(mr) = mrs
                .iter()
                .find(|mr| mr.title.to_lowercase().contains(&input.to_lowercase()))
            {
                return Ok(ExternalLinkResolveResponse {
                    url: mr.web_url.clone(),
                });
            }

            if let Some(mr) = mrs.iter().find(|mr| mr.web_url.starts_with(&base)) {
                return Ok(ExternalLinkResolveResponse {
                    url: mr.web_url.clone(),
                });
            }
        }
    }

    Err("No matching external link found".to_string())
}

fn normalize_base_url(base_url: &str) -> Result<String, String> {
    let url = Url::parse(base_url).map_err(|e| format!("Invalid base URL: {e}"))?;
    Ok(url.as_str().trim_end_matches('/').to_string())
}

fn parse_jira_key(url: &Url) -> Result<String, String> {
    let segments: Vec<&str> = url
        .path_segments()
        .map(|s| s.filter(|seg| !seg.is_empty()).collect())
        .unwrap_or_default();

    for (idx, segment) in segments.iter().enumerate() {
        if *segment == "browse" {
            if let Some(key) = segments.get(idx + 1) {
                if is_jira_key(key) {
                    return Ok((*key).to_string());
                }
            }
        }
        if is_jira_key(segment) {
            return Ok((*segment).to_string());
        }
    }

    Err("Unable to parse Jira issue key from URL".to_string())
}

fn is_jira_key(segment: &str) -> bool {
    let mut parts = segment.splitn(2, '-');
    let project = parts.next().unwrap_or("");
    let number = parts.next().unwrap_or("");
    if project.is_empty() || number.is_empty() {
        return false;
    }
    if !project
        .chars()
        .all(|c| c.is_ascii_uppercase() || c.is_ascii_digit())
    {
        return false;
    }
    if !number.chars().all(|c| c.is_ascii_digit()) {
        return false;
    }
    true
}

fn parse_gitlab_key(url: &Url) -> Result<String, String> {
    let segments: Vec<&str> = url
        .path_segments()
        .map(|s| s.filter(|seg| !seg.is_empty()).collect())
        .unwrap_or_default();

    let dash_index = segments.iter().position(|seg| *seg == "-");
    let Some(dash_index) = dash_index else {
        return Err("GitLab URL missing '/-/' segment".to_string());
    };

    let project_segments = &segments[..dash_index];
    let project_path = project_segments.join("/");

    let resource = segments
        .get(dash_index + 1)
        .ok_or_else(|| "GitLab URL missing resource segment".to_string())?;
    let iid = segments
        .get(dash_index + 2)
        .ok_or_else(|| "GitLab URL missing IID segment".to_string())?;

    match *resource {
        "issues" => Ok(format!("issue:{project_path}:{iid}")),
        "merge_requests" => Ok(format!("mr:{project_path}:{iid}")),
        _ => Err("GitLab URL must be an issue or merge request".to_string()),
    }
}

fn is_due(link: &ExternalLink, stale_after_hours: i64) -> bool {
    if link.cached_response.is_none() || link.last_synced_at.is_none() {
        return true;
    }
    let Some(last_synced) = link.last_synced_at else {
        return true;
    };
    let cutoff = Utc::now() - Duration::hours(stale_after_hours);
    last_synced < cutoff
}

fn provider_delay_ms(config: &ExternalLinksConfig, provider: ProviderKind) -> Option<u64> {
    match provider {
        ProviderKind::Jira => config.jira.as_ref().map(|cfg| cfg.min_delay_ms),
        ProviderKind::Gitlab => config.gitlab.as_ref().map(|cfg| cfg.min_delay_ms),
    }
}

fn resolve_token(cfg: &ProviderConfig) -> Result<String, String> {
    if let Some(value) = cfg.token.value.as_ref().filter(|v| !v.trim().is_empty()) {
        return Ok(value.to_string());
    }

    if let Some(env_key) = cfg.token.env.as_ref().filter(|v| !v.trim().is_empty()) {
        return env::var(env_key).map_err(|_| {
            format!(
                "Environment variable '{}' is not set for provider token",
                env_key
            )
        });
    }

    Err("Provider token must specify value or env".to_string())
}

async fn fetch_and_cache_link(
    client: &Client,
    config: &ExternalLinksConfig,
    link: &ExternalLink,
    provider: ProviderKind,
) -> Result<(), String> {
    let now = Utc::now();
    let result = match provider {
        ProviderKind::Jira => {
            let cfg = config
                .jira
                .as_ref()
                .ok_or_else(|| "Jira is not configured".to_string())?;
            fetch_jira_issue(client, cfg, &link.external_key).await
        }
        ProviderKind::Gitlab => {
            let cfg = config
                .gitlab
                .as_ref()
                .ok_or_else(|| "GitLab is not configured".to_string())?;
            fetch_gitlab_item(client, cfg, &link.external_key).await
        }
    };

    match result {
        Ok(json) => DbStore::update_external_link_cache_success(link.id, json, now)
            .await
            .map_err(|e| format!("Failed to update cache: {e}"))?,
        Err(err) => {
            DbStore::update_external_link_sync_error(link.id, err.to_string())
                .await
                .map_err(|e| format!("Failed to update sync error: {e}"))?;
            return Err(err);
        }
    }

    Ok(())
}

async fn fetch_jira_issue(
    client: &Client,
    cfg: &ProviderConfig,
    issue_key: &str,
) -> Result<String, String> {
    let base = normalize_base_url(&cfg.base_url)?;
    let token = resolve_token(cfg)?;
    let url = format!("{base}/rest/api/3/issue/{issue_key}?fields=summary,status,assignee,updated");

    let response = client
        .get(url)
        .bearer_auth(token)
        .header("Accept", "application/json")
        .send()
        .await
        .map_err(|e| format!("Failed to call Jira API: {e}"))?;

    let status = response.status();
    let body = response
        .text()
        .await
        .map_err(|e| format!("Failed to read Jira response: {e}"))?;
    if !status.is_success() {
        return Err(format!("Jira API error {status}: {body}"));
    }

    Ok(body)
}

async fn fetch_gitlab_item(
    client: &Client,
    cfg: &ProviderConfig,
    external_key: &str,
) -> Result<String, String> {
    let (kind, project_path, iid) = parse_gitlab_external_key(external_key)?;
    let base = normalize_base_url(&cfg.base_url)?;
    let token = resolve_token(cfg)?;
    let encoded_project =
        url::form_urlencoded::byte_serialize(project_path.as_bytes()).collect::<String>();

    let url = match kind {
        GitlabLinkKind::Issue => {
            format!("{base}/api/v4/projects/{encoded_project}/issues/{iid}")
        }
        GitlabLinkKind::MergeRequest => {
            format!("{base}/api/v4/projects/{encoded_project}/merge_requests/{iid}")
        }
    };

    let response = client
        .get(url)
        .header("PRIVATE-TOKEN", token.as_str())
        .header("Accept", "application/json")
        .send()
        .await
        .map_err(|e| format!("Failed to call GitLab API: {e}"))?;
    let status = response.status();
    let body = response
        .text()
        .await
        .map_err(|e| format!("Failed to read GitLab response: {e}"))?;
    if !status.is_success() {
        return Err(format!("GitLab API error {status}: {body}"));
    }

    if matches!(kind, GitlabLinkKind::MergeRequest) {
        let approvals_url =
            format!("{base}/api/v4/projects/{encoded_project}/merge_requests/{iid}/approvals");
        let approvals_resp = client
            .get(approvals_url)
            .header("PRIVATE-TOKEN", token.as_str())
            .header("Accept", "application/json")
            .send()
            .await
            .map_err(|e| format!("Failed to call GitLab approvals API: {e}"))?;
        let approvals_status = approvals_resp.status();
        let approvals_body = approvals_resp
            .text()
            .await
            .map_err(|e| format!("Failed to read GitLab approvals response: {e}"))?;
        if !approvals_status.is_success() {
            return Err(format!(
                "GitLab approvals API error {approvals_status}: {approvals_body}"
            ));
        }

        let mr_json: Value =
            serde_json::from_str(&body).map_err(|e| format!("Invalid MR JSON: {e}"))?;
        let approvals_json: Value = serde_json::from_str(&approvals_body)
            .map_err(|e| format!("Invalid approvals JSON: {e}"))?;
        let combined = serde_json::json!({
            "merge_request": mr_json,
            "approvals": approvals_json
        });
        return Ok(
            serde_json::to_string(&combined).map_err(|e| format!("Serialize JSON failed: {e}"))?
        );
    }

    Ok(body)
}

#[derive(Debug)]
enum GitlabLinkKind {
    Issue,
    MergeRequest,
}

fn parse_gitlab_external_key(key: &str) -> Result<(GitlabLinkKind, String, String), String> {
    let mut parts = key.splitn(3, ':');
    let kind = parts.next().unwrap_or("");
    let project = parts.next().unwrap_or("");
    let iid = parts.next().unwrap_or("");

    if project.is_empty() || iid.is_empty() {
        return Err("Invalid GitLab external key".to_string());
    }

    match kind {
        "issue" => Ok((GitlabLinkKind::Issue, project.to_string(), iid.to_string())),
        "mr" => Ok((
            GitlabLinkKind::MergeRequest,
            project.to_string(),
            iid.to_string(),
        )),
        _ => Err("Unknown GitLab external key type".to_string()),
    }
}

#[derive(Debug, Deserialize)]
struct GitlabUser {
    id: i64,
}

#[derive(Debug, Deserialize)]
struct GitlabMergeRequestRaw {
    iid: i64,
    title: String,
    web_url: String,
    state: String,
    updated_at: String,
    user_notes_count: Option<i64>,
    pipeline: Option<GitlabPipelineRaw>,
    head_pipeline: Option<GitlabPipelineRaw>,
}

#[derive(Debug, Deserialize)]
struct GitlabPipelineRaw {
    status: Option<String>,
}

#[derive(Debug, Deserialize)]
struct GitlabApprovalRaw {
    approved: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct JiraSearchResponse {
    issues: Vec<JiraIssueRaw>,
}

#[derive(Debug, Deserialize)]
struct JiraIssueRaw {
    key: String,
    fields: JiraIssueFields,
}

#[derive(Debug, Deserialize)]
struct JiraIssueFields {
    summary: String,
    status: JiraStatus,
    updated: String,
}

#[derive(Debug, Deserialize)]
struct JiraStatus {
    name: String,
}

fn extract_gitlab_project_path(web_url: &str) -> Option<String> {
    let url = Url::parse(web_url).ok()?;
    let segments: Vec<&str> = url
        .path_segments()
        .map(|s| s.filter(|seg| !seg.is_empty()).collect())
        .unwrap_or_default();
    let dash_index = segments.iter().position(|seg| *seg == "-")?;
    let project_segments = &segments[..dash_index];
    if project_segments.is_empty() {
        return None;
    }
    Some(project_segments.join("/"))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn config_with_base_urls(jira_base: &str, gitlab_base: &str) -> ExternalLinksConfig {
        ExternalLinksConfig {
            jira: Some(ProviderConfig {
                base_url: jira_base.to_string(),
                token: bee_core::config::TokenConfig {
                    value: Some("jira-token".to_string()),
                    env: None,
                },
                min_delay_ms: 0,
            }),
            gitlab: Some(ProviderConfig {
                base_url: gitlab_base.to_string(),
                token: bee_core::config::TokenConfig {
                    value: Some("gitlab-token".to_string()),
                    env: None,
                },
                min_delay_ms: 0,
            }),
        }
    }

    #[test]
    fn parse_jira_link() {
        let config =
            config_with_base_urls("https://jira.example.com", "https://gitlab.example.com");
        let parsed = parse_external_link("https://jira.example.com/browse/ABC-123", &config)
            .expect("jira link parses");
        assert_eq!(parsed.provider, ProviderKind::Jira);
        assert_eq!(parsed.external_key, "ABC-123");
    }

    #[test]
    fn parse_gitlab_issue_link() {
        let config =
            config_with_base_urls("https://jira.example.com", "https://gitlab.example.com");
        let parsed = parse_external_link(
            "https://gitlab.example.com/group/project/-/issues/42",
            &config,
        )
        .expect("gitlab issue link parses");
        assert_eq!(parsed.provider, ProviderKind::Gitlab);
        assert_eq!(parsed.external_key, "issue:group/project:42");
    }

    #[test]
    fn parse_gitlab_mr_link() {
        let config =
            config_with_base_urls("https://jira.example.com", "https://gitlab.example.com");
        let parsed = parse_external_link(
            "https://gitlab.example.com/group/project/-/merge_requests/99",
            &config,
        )
        .expect("gitlab mr link parses");
        assert_eq!(parsed.provider, ProviderKind::Gitlab);
        assert_eq!(parsed.external_key, "mr:group/project:99");
    }
}
