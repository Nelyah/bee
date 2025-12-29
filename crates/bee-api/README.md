# bee-api

`bee-api` is the REST API server for Bee. The binary name is `beed`.

## Run

From the repo root:

```
cargo run -p bee-api
```

Environment overrides:

- `BEE_API_ADDR` overrides the bind address (default `127.0.0.1:3000`).
- `BEE_API_CONFIG` points to a specific config file.

## Configuration

The API config file is separate from the CLI config.

Lookup order:

1. `BEE_API_CONFIG`
2. `bee-api.toml`
3. `$XDG_CONFIG_HOME/bee-api/config.toml`
4. `$HOME/.config/bee-api/config.toml`
5. `$HOME/.bee-api.toml`

Example config:

```toml
[api]
bind_addr = "127.0.0.1:3000"
undo_count = 1
allowed_actions = ["add", "list", "modify", "done", "delete", "start", "stop", "annotate"]

[api.report]
filters = ["status:pending or status:active"]
columns = ["id", "date_created", "summary", "tags", "urgency"]
column_names = ["ID", "Date created", "Summary", "Tags", "Urgency"]
default = true
```

## API Docs

Swagger UI is available at:

- `/v1/docs`
- OpenAPI JSON at `/v1/openapi.json`

## Endpoints

- `GET /v1/health`
- `POST /v1/parse`
- `POST /v1/action`

Example parse request:

```json
{ "input": "add finish report +work project:demo" }
```

Example action request:

```json
{
  "action": "add",
  "properties": {
    "summary": "finish report",
    "tags_add": ["work"],
    "project": {"id": null, "name": "demo"}
  },
  "filter": null
}
```
