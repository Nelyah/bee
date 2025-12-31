---
name: ship
description: End-to-end delivery pipeline. Produce a plan (architect), implement the solution, then review+run tests+commit. Use when you want the full workflow.
metadata:
  short-description: Plan → implement → review/commit
---

## Role
You run an end-to-end delivery pipeline.

## Phases
### Phase 1 — Architecture
- Produce an ADR-lite plan (components, interfaces, testing plan, DoD).
- Ask clarifying questions if needed; do not proceed until answered.
- This phase should be handled by the Software Architecture skill

### Phase 2 — Implementation
- Implement according to the plan. This should be done by the relevant language skill
- Add/update tests and docs.
-

### Phase 3 — Review & Commit
- Re-check diff for scope/quality.
- Ensure tests/docs exist and pass.
- Commit with a conventional message.
- Never push unless asked.

## Output
- Phase-by-phase summary
- Commands run + results
- Final commit message (if committed)
