---
name: ticket-workflow
description: >
  Orchestrates the full ticket workflow: Architect → Engineer → UI/UX Review.
  Use when implementing tickets, especially complex ones or those with UI changes.
  Invoke with /project:ticket-workflow or when user says "implement ticket",
  "full workflow", or "with review".
allowed-tools: Task, Bash, Read, Glob
---

# Ticket Implementation Workflow

Orchestrates a multi-agent workflow for implementing tickets with quality gates.

## Workflow Diagram

```
                    ┌─────────────────┐
                    │   START TICKET  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Is it complex? │
                    │ (3+ files, arch │
                    │  decisions, or  │
                    │ engineer asks)  │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │ YES                         │ NO
              ▼                             ▼
    ┌─────────────────┐           ┌─────────────────┐
    │   ARCHITECT     │           │                 │
    │  Creates plan   │           │                 │
    └────────┬────────┘           │                 │
             │                    │                 │
    ┌────────▼────────┐           │                 │
    │   ENGINEER      │◀──────────┘                 │
    │ Reviews plan    │                             │
    │ (approve/revise)│                             │
    └────────┬────────┘                             │
             │ Approved                             │
             ▼                                      │
    ┌─────────────────┐◀────────────────────────────┘
    │   ENGINEER      │
    │  Implements     │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │  Has UI changes?│
    └────────┬────────┘
             │
      ┌──────┴──────┐
      │ YES         │ NO
      ▼             ▼
┌───────────┐  ┌───────────┐
│ Generate  │  │   DONE    │
│Screenshots│  │  Commit   │
└─────┬─────┘  └───────────┘
      │
      ▼
┌───────────────┐
│  UI/UX REVIEW │
└───────┬───────┘
        │
   ┌────┴────┐
   │APPROVED?│
   └────┬────┘
        │
  ┌─────┴─────┐
  │YES        │NO
  ▼           ▼
┌─────┐  ┌─────────┐
│DONE │  │ Back to │
│     │  │ENGINEER │
└─────┘  └─────────┘
```

## Communication Protocol

**All agents must communicate with extreme directness.** No fluff, no hedging, no excessive politeness.

**Why:** Saves tokens, speeds iteration, reduces misunderstandings.

### Communication Rules

1. **Verdict first** - APPROVED / CHANGES REQUESTED / BLOCKED
2. **Specific** - "Line 42: missing null check" not "there might be an issue"
3. **Concise** - Max 1 sentence per point
4. **Honest** - Say what's wrong plainly
5. **No pleasantries** - Skip "Great work!", "I think maybe..."
6. **Bullets > paragraphs** - Easier to scan, fewer tokens
7. **Omit obvious** - Don't explain what the other agent already knows

### Good vs Bad Communication

**❌ Bad (vague, hedging):**
> "This is really good work overall! I was wondering if maybe we could possibly consider perhaps adjusting the font size a little bit? It might be slightly hard to read for some users, but it's just a thought. What do you think?"

**✅ Good (direct, actionable):**
> "CHANGES REQUESTED
> - Font size too small: 11px → 13px minimum
> - Reason: Fails WCAG AA contrast at current size"

**❌ Bad (buried feedback):**
> "I love the overall direction here. The architecture is quite thoughtful and shows good understanding of the codebase. One small thing I noticed is that we're missing error handling for the API call, which could cause issues in production. But other than that, everything looks great!"

**✅ Good (verdict first):**
> "CHANGES REQUESTED
> - Missing error handling in `fetchTasks()` - will crash on network failure
> - Add: `catch` block with user-facing error message"

### Response Formats

**Architect → Engineer:**
```
PLAN READY

Files to modify:
- path/file.rs - [what]
- path/file.swift - [what]

Steps:
1. [Action]
2. [Action]

Open questions: [if any, otherwise omit]
```

**Engineer → Architect (plan review):**
```
APPROVED
```
or
```
CHANGES REQUESTED
- [Issue 1]: [specific problem]
- [Issue 2]: [specific problem]
```

**Engineer → UI/UX:**
```
READY FOR REVIEW

Changed:
- TaskRow.swift - added hover hints
- TaskDetailView.swift - loading spinner

Screenshots:
- testTaskRow_selected.1.png
- testTaskDetail_loading.1.png
```

**UI/UX → Engineer:**
```
APPROVED
```
or
```
CHANGES REQUESTED
- [Component]: [Issue] → [Fix]
- [Component]: [Issue] → [Fix]
```

## The Three Agents

| Agent | Role | When Called |
|-------|------|-------------|
| `software-architect` | Creates implementation plan with ADR | Complex tickets, architectural decisions |
| `senior-engineer` | Implements code, runs tests | All tickets |
| `ui-ux-reviewer` | Reviews UI changes visually | Tickets with UI modifications |

## Step-by-Step Execution

### Step 0: Triage

Determine if the ticket needs architectural planning:

**Needs Architect if:**
- Touches 3+ components or files
- Requires design decisions (data model, API shape, patterns)
- Affects multiple layers (Core + Actions + CLI/API + UI)
- Engineer is unsure how to approach it
- New feature (not a bug fix)

**Skip to Engineer if:**
- Simple bug fix with clear cause
- Single-file change
- Following an existing pattern exactly
- Engineer already knows the approach

### Step 1: Architecture (if needed)

```
Spawn: software-architect

Prompt:
---
## Ticket: [TITLE]

### Description
[DESCRIPTION]

### Acceptance Criteria
[CRITERIA]

Please create an implementation plan following your ADR format.
Consider the existing patterns in this codebase.
---
```

**Architect outputs:** Architecture Decision Record with:
- Context and requirements
- High-level design
- Component breakdown
- Implementation steps

### Step 2: Engineer Reviews Plan

```
Spawn: senior-engineer

Prompt:
---
## Plan Review Request

The architect has created this plan for: [TICKET_TITLE]

### Proposed Plan
[ARCHITECT'S ADR OUTPUT]

### Your Task
1. Review this plan for implementability
2. Flag any concerns or questions
3. Either:
   - APPROVE: "Plan approved, proceeding with implementation"
   - REQUEST CHANGES: Specific feedback for architect

Do NOT implement yet - just review the plan.
---
```

**If changes requested:** Go back to Architect with feedback, iterate until agreement.

### Step 3: Implementation

```
Spawn: senior-engineer

Prompt:
---
## Implementation: [TICKET_TITLE]

### Plan to Follow
[APPROVED PLAN - or ticket description if no plan needed]

### Acceptance Criteria
[CRITERIA]

### Instructions
1. Implement following the plan
2. Add/update tests
3. Run `lefthook run pre-commit --all-files`
4. Report:
   - Summary of changes
   - Files modified
   - UI components changed (if any)
   - Test results
---
```

**Engineer outputs:**
- Implementation summary
- List of modified files
- List of UI components touched
- Test results (pass/fail)

### Step 4: Generate Screenshots (if UI changed)

If engineer reports UI components were modified:

```bash
# Generate fresh screenshots
swift test --filter "ScreenshotCatalog"

# Or specific views
swift test --filter "ScreenshotCatalog/testContentView_listWithTasks"
```

### Step 5: UI/UX Review (if UI changed)

```
Spawn: ui-ux-reviewer

Prompt:
---
## Review Request: [TICKET_TITLE]

### What Was Implemented
[ENGINEER'S SUMMARY]

### UI Components Modified
[LIST FROM ENGINEER]

### Screenshots to Review
Read these files:
- macos-launcher/Tests/.../ScreenshotCatalog/[relevant].1.png

### Acceptance Criteria
[CRITERIA]

Please review and respond with:
- APPROVED: Visual and functional criteria met
- CHANGES REQUESTED: Specific issues with recommendations
---
```

### Step 6: Handle Review Result

**If APPROVED:**
- Commit the changes (if not already)
- Report success to user

**If CHANGES REQUESTED:**
- Pass feedback to Engineer
- Engineer fixes issues
- Re-generate screenshots
- Re-run UI/UX review
- Repeat until approved

## Quick Reference Commands

```bash
# Run pre-commit hooks
lefthook run pre-commit --all-files

# Generate all catalog screenshots
swift test --filter "ScreenshotCatalog"

# Run all Rust tests
cargo test

# Run all Swift tests
swift test
```

## Example Flow

**Ticket:** "Add keyboard shortcut hints to TaskRow on hover"

**Triage:** UI change + new component → full workflow

**Architect:**
```
PLAN READY
- New: HoverHintView.swift
- Modify: TaskRow.swift - show hints on isHovered
- Style: DesignTokens.TypeScale.caption
- Test: Add testTaskRow_hovered snapshot
```

**Engineer (review):**
```
APPROVED
```

**Engineer (implement):**
```
DONE
- Added: HoverHintView.swift
- Modified: TaskRow.swift
- Tests: pass
- Screenshot: testTaskRow_selected.1.png
```

**UI/UX:**
```
CHANGES REQUESTED
- Font: 11px → 13px (readability)
```

**Engineer (fix):**
```
FIXED
- Updated to TypeScale.bodySm
- Screenshot regenerated
```

**UI/UX:**
```
APPROVED
```

**Done.** Committed.
