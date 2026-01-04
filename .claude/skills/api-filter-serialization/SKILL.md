---
name: api-filter-serialization
description: Documents the JSON format required when sending filters to the bee API from clients (Swift, etc.). Use when implementing API calls that include filters, debugging "invalid filter" errors, or working on client-server filter serialization. (project)
allowed-tools: Read, Grep, Edit, Write
---

# API Filter Serialization Format

When sending filters to the bee API (e.g., `/v1/action` endpoint), clients must use the correct JSON format that matches Rust's typetag serialization.

## The Key Rule

Rust's Filter trait uses:
```rust
#[typetag::serde(tag = "type", content = "value")]
pub trait Filter { ... }
```

This means **all filter content must be wrapped in a `"value"` field**.

## Correct vs Incorrect Format

### Wrong (flat structure)
```json
{
    "type": "UuidFilter",
    "uuid": "a1b2c3d4-..."
}
```

### Correct (content wrapped in "value")
```json
{
    "type": "UuidFilter",
    "value": {
        "uuid": "a1b2c3d4-..."
    }
}
```

## Filter Type Naming

**IMPORTANT**: Filter type names must use exact casing from the API. Common mistake:
- Wrong: `"UUIDFilter"` (all caps UUID)
- Correct: `"UuidFilter"` (Pascal case)

The API will return an error like `unknown variant 'UUIDFilter', expected one of...` if casing is wrong.

## Common Filter Formats

| Filter Type | Correct JSON |
|-------------|--------------|
| UuidFilter | `{"type": "UuidFilter", "value": {"uuid": "..."}}` |
| StatusFilter | `{"type": "StatusFilter", "value": {"status": "pending"}}` |
| ProjectFilter | `{"type": "ProjectFilter", "value": {"project": "...", "include_subprojects": true}}` |
| TagFilter | `{"type": "TagFilter", "value": {"tag_name": "...", "include": true}}` |
| TaskIdFilter | `{"type": "TaskIdFilter", "value": {"id": 123}}` |

## Swift Example

```swift
// Correct
let filter: JSONValue = .object([
    "type": .string("UuidFilter"),
    "value": .object(["uuid": .string(task.uuid)]),
])

// Wrong - will fail deserialization
let filter: JSONValue = .object([
    "type": .string("UuidFilter"),
    "uuid": .string(task.uuid),
])
```

## Symptoms of Wrong Format

- API returns "invalid filter" error
- Actions fail with vague error messages like "failed to add annotation"
- Filter deserialization silently fails, causing empty task lists

## Where This Applies

- `POST /v1/action` - the `filter` field in ActionRequest
- Any direct filter JSON construction in client code
- Filters returned from `POST /v1/parse` already use the correct format

## Guardrails

### Always Do
- Wrap filter fields in a `"value"` object
- Check existing filter serialization tests when adding new filter types

### Never Do
- Send filter fields at the top level alongside `"type"`
