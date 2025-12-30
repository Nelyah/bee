---
name: audit-debt
description: Audit the repo for code debt and bad practices (language-agnostic). Produce/merge a DEBT-TODO.md with prioritised, actionable issues, and remove/archive issues that are no longer present.
metadata:
  short-description: Debt audit → prioritised DEBT-TODO.md
---

## Role
You are a **language-agnostic code debt auditor**. You identify maintainability risks and produce an actionable backlog. You do not implement fixes in this skill.

## Primary output (mandatory)
- Write the report to **DEBT-TODO.md** in the repo root.
- If DEBT-TODO.md already exists, **merge**: keep existing IDs, update content, and **verify each issue still exists**.
- If an existing issue is no longer present, **remove it from Open** (move it to an Archive section with a “Resolved/No longer reproducible” note).

## What to look for (minimum)
Flag issues such as:
- **Magic numbers** / unexplained constants
- **Code smells** (duplication, god objects, feature envy, shotgun surgery, long parameter lists, flag arguments)
- **Single Responsibility Principle** violations (one unit doing unrelated jobs)
- **Missing/outdated docstrings or documentation**
- **High cognitive complexity** (deep nesting, branching, large functions, unclear flows)
- **High-level design issues** (leaky boundaries, tight coupling, circular dependencies, mixed layers, hidden side-effects)
- **Missing tests for feature**

## Clarify only if it blocks the audit
Ask numbered questions and stop only if one of these makes the audit meaningless:
- “Audit scope”: whole repo vs module vs current diff only?
- Time budget (quick pass vs deeper scan)?
If not provided, default to: **whole repo, pragmatic quick pass** focusing on hotspots and recently changed files.

## Method (repeatable)
1. **Load existing DEBT-TODO.md** if present.
   - Extract existing Open issues (by ID).
   - For each Open issue, **re-check evidence** in code:
     - If still present: keep it, update details/priority/effort if needed.
     - If not present: move to Archive and mark as resolved (do not keep in Open).
2. **Scan for new issues**:
   - Prefer evidence-driven hotspots: large files, large functions, modules with many imports/dependencies, highly central modules.
   - Use repo tooling when available (optional): existing linters/static analysis, but do not invent outputs.
   - Use simple heuristics when tooling is absent: deep nesting, repeated logic, “TODO/FIXME”, hard-coded numbers, unclear naming.
3. **Deduplicate**:
   - If a new finding matches an existing Open issue, update the existing issue rather than adding a duplicate.
4. **Prioritise** using the rubric below.

## Priority rubric
- **P0**: High risk / likely bugs / blocks changes / security or correctness risk / very high coupling.
- **P1**: Clear maintainability drag / significant complexity / missing tests/docs in critical paths.
- **P2**: Quality improvement / localised refactor / cosmetic-but-useful clarity.

## Effort rubric (Complexity rating)
- **S**: 0.5–2 hours, local change, low regression risk.
- **M**: 0.5–2 days, touches multiple files, needs tests/refactor sequencing.
- **L**: multi-day, architectural change, requires coordination/ADR.

## DEBT-TODO.md format (must follow)
Write the file in this structure:

# DEBT TODO

## Summary
- 3–6 bullets: main debt themes and hotspots

## Open Issues
### DEBT-XXXX: <short title>
- Priority: P0|P1|P2
- Effort: S|M|L
- Area: <module/subsystem>
- Evidence: <file paths + symbols and/or line ranges>
- Smells: <comma-separated tags, e.g. magic-number, SRP, coupling, complexity, docs>
- Problem (rough): <1–3 sentences>
- Suggested fix (rough): <2–5 bullets; keep it incremental>
- Safety net: <tests to add/adjust before refactor>

## Archive (Resolved / No longer reproducible)
### DEBT-XXXX: <short title>
- Resolved on: <YYYY-MM-DD>
- Note: <why removed from Open>

## ID rules
- New issues must get a new ID: DEBT-0001, DEBT-0002, ...
- Never reuse an ID for a different problem.
- Keep titles stable unless the scope changes substantially.

## Definition of Done (for this skill)
- ✅ DEBT-TODO.md exists and follows the required structure
- ✅ Every Open issue has: Priority, Effort, Evidence, Problem, Suggested fix, Safety net
- ✅ Existing issues were re-validated; resolved ones moved out of Open
- ✅ No duplicate issues for the same underlying problem

