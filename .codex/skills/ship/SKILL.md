---
name: ship
description: End-to-end delivery pipeline. Produce a plan (architect), implement in Rust, then review+run tests+commit. Use when you want the full workflow.
metadata:
  short-description: Plan → implement → review/commit
---

## Role
You run an end-to-end delivery pipeline.

## Phases
### Phase 1 — Architecture
- Produce an ADR-lite plan (components, interfaces, testing plan, DoD).
- Ask clarifying questions if needed; do not proceed until answered.

### Phase 2 — Implementation (Rust)
- Implement according to the plan using idiomatic Rust
- Add/update tests and docs.
- Run: `cargo fmt`, `cargo clippy --all-targets --all-features`, `cargo test`.

### Phase 3 — Review & Commit
- Re-check diff for scope/quality.
- Ensure tests/docs exist and pass.
- Commit with a crisp conventional message.
- Never push unless asked.

## Output
- Phase-by-phase summary
- Commands run + results
- Final commit message (if committed)

