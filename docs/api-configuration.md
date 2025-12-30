# API Configuration

This project uses a single `bee.toml` configuration file. API-specific settings live under
`[api]` while provider credentials for external links live under `[core.external_links]`.

## Example

```toml
[core.external_links.jira]
base_url = "https://jira.example.com"
token = "your-jira-token"
# Optional: minimum delay between requests (ms) to respect rate limits.
min_delay_ms = 250

[core.external_links.gitlab]
base_url = "https://gitlab.example.com"
token = "your-gitlab-token"
# Optional: minimum delay between requests (ms) to respect rate limits.
min_delay_ms = 250

[api]
bind_addr = "127.0.0.1:3000"
undo_count = 1
allowed_actions = ["add", "list", "modify", "done", "delete", "start", "stop", "annotate"]

[api.external_links.sync]
# Sync any link if it is older than this many hours.
stale_after_hours = 24
# Maximum number of links per batch.
batch_size = 10
```

## Notes

- `base_url` must match the host in the external link URLs; the parser only accepts links that
  start with the configured base URL.
- Jira uses OAuth Bearer token (`Authorization: Bearer <token>`).
- GitLab uses `PRIVATE-TOKEN` header.
- API sync logic reads provider config from `[core.external_links]`.
- The API reads `bee.toml` via the same discovery logic as `bee-core`.
