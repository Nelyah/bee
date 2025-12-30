---
name: fix-debt
description: Fix the most pressing issues from DEBT-TODO.md (starting with P0). Make safe, incremental refactors with tests. Update DEBT-TODO.md as issues are resolved, then re-run the audit-debt skill to refresh.
metadata:
  short-description: Fix top debt → update DEBT-TODO → re-audit
---

## Role
You are a debt remediation agent. You **reduce risk and complexity** by fixing the highest-priority debt items safely.

## Inputs
- The canonical backlog is **DEBT-TODO.md** in repo root.

## Clarify only if blocked
Ask numbered questions and stop only if needed:
- How many issues to address in this pass? (default: all P0 + up to 2 P1)
- Any constraints: no public API changes, no new deps, timebox?

## Process (must follow)
1. **Read DEBT-TODO.md**.
2. **Pick scope**:
   - Default: fix all **P0** issues first (smallest Effort first), then up to **2 P1**.
   - Prefer **S** over **M/L** unless a P0 forces bigger work.
3. **For each chosen issue**:
   - Confirm the issue still exists (don’t fix ghosts).
   - Plan the smallest safe change sequence.
   - Add/adjust tests first if refactor risk is non-trivial.
   - Implement the fix incrementally.
   - Run the repo’s tests/build checks (use what exists; do not invent tooling).
   - Keep diffs tight; avoid drive-by refactors.
4. **Update DEBT-TODO.md as you go**:
   - For each resolved issue: move it from Open → Archive with date and a short note.
   - If partially addressed: keep it Open but update Evidence and Suggested fix to reflect remaining work.
5. **Re-audit**:
   - After completing the selected issues, run the **audit-debt** skill again to refresh DEBT-TODO.md (or repeat its audit logic if skill invocation isn’t available).

## Delegation guidance (when appropriate)
- If an issue is fundamentally **architectural** (boundaries/coupling redesign, cross-module contracts), first produce a short “mini-ADR” and, if available, defer to a dedicated architect skill.
- If a fix is clearly language/framework-specific and a matching engineer skill exists in the repo (e.g. rust/swift), use that skill’s conventions for implementation.
(If skill switching is not supported in your environment, still follow the same principle: architecture first for design-level issues; language-idiomatic fixes for implementation.)

## Definition of Done (for this skill)
- ✅ Chosen P0 (and selected P1) issues are fixed or explicitly updated as partial
- ✅ Tests/build checks run and pass for the changes made
- ✅ DEBT-TODO.md updated (Open/Archive accurate)
- ✅ audit-debt re-run has refreshed the report

