---
name: writing-skills
description: Creates and improves Claude Code skills. Use this skill when asked to create a new skill, update an existing skill, or when learning something that should become a skill. Also invocable via /project:writing-skills for skill-writing guidance.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Writing Effective Skills

This skill teaches you how to create effective skills for Claude Code. Skills are on-demand knowledge packages that load when relevant, enabling large codebases to provide focused context without bloating every conversation.

## Skills vs CLAUDE.md vs Serena Memories

Choose the right location for knowledge:

| Location | Purpose | Load Behavior | Use When |
|----------|---------|---------------|----------|
| **CLAUDE.md** | Universal context | Always in context | Every interaction needs it (build commands, universal conventions) |
| **Skills** | On-demand knowledge | Loaded when relevant (~100 tokens metadata scan) | Specific domains, repeated tasks, architecture docs |
| **Serena Memories** | Persistent learnings | Read explicitly | Cross-session discoveries worth remembering |

### Decision Tree

1. **"Is this needed for EVERY interaction?"**
   - Yes → CLAUDE.md
   - No → Continue...

2. **"Is this domain-specific knowledge or a repeated task?"**
   - Yes → Skill
   - No → Continue...

3. **"Did I learn something that should persist across sessions?"**
   - Yes → Serena Memory
   - No → Probably doesn't need documenting

### Key Insight

Large codebases CAN'T fit everything in CLAUDE.md. Skills with progressive disclosure solve this:
- Skills metadata: ~100 tokens each (can handle 100+ skills)
- Full skill content: <5K tokens recommended
- Reference files: Load only when needed

## When to Create Skills

Three triggers:

### 1. Repeated Tasks (The 5/10 Rule)
Have you done this task 5+ times? Will you do it 10+ more times?
- Examples: Running specific test suites, deploying to staging, creating PR descriptions

### 2. Domain-Specific Reference
Knowledge you'd otherwise repeat when working in a specific area:
- Examples: "LauncherViewModel patterns", "API endpoint conventions", "Database schema reference"

### 3. Architecture That Shouldn't Bloat CLAUDE.md
Large architectural docs that are only relevant in specific contexts:
- Examples: "BigQuery table schemas", "Authentication flow documentation", "State management patterns"

## Skill Anatomy

### Required: Frontmatter

```yaml
---
name: skill-name
description: What it does AND when to use it. Third person. Include trigger words.
allowed-tools: Tool1, Tool2, Tool3
---
```

**Name requirements:**
- Max 64 characters
- Lowercase letters, numbers, hyphens only
- No reserved words: "anthropic", "claude"
- Prefer gerund form: `writing-tests`, `processing-pdfs`

**Description requirements:**
- Max 1024 characters, non-empty
- **Critical for discovery** - Claude uses this to decide relevance
- Always third person ("Processes..." not "I process..." or "You can...")
- Include WHAT it does AND WHEN to use it
- Include trigger words users might say

**Good description:**
```yaml
description: Writes SwiftUI UI tests using ViewInspector for behavior testing and swift-snapshot-testing for visual regression. Use when asked to write UI tests, view tests, snapshot tests, or test SwiftUI views.
```

**Bad descriptions:**
```yaml
description: Helps with testing  # Too vague
description: I can help you write tests  # Wrong person
description: Use this to test things  # No trigger words
```

### Body Structure

Follow the convention established in this codebase:

1. **Role/Purpose** (1-2 sentences)
2. **Key Information** (tables, patterns, or structured reference)
3. **Workflow/Process** (numbered steps for tasks)
4. **Guardrails** (three-tier boundaries)
5. **Examples Index** (if using progressive disclosure)

## Progressive Disclosure

### When to Split Content

- SKILL.md approaching 500 lines → Split
- Reference material not always needed → Separate file
- Multiple distinct domains → Domain-specific files

### How to Reference

Link from SKILL.md with clear context so Claude knows when to read:

```markdown
## Examples Index

See [EXAMPLES.md](EXAMPLES.md) for detailed examples:
- **Testing patterns** - Read when writing test-related skills
- **Workflow examples** - Read when creating process/task skills
- **Architecture reference** - Read when documenting codebase patterns
```

### Directory Structure

```
.claude/skills/my-skill/
├── SKILL.md              # Main content (loaded when triggered)
├── REFERENCE.md          # Detailed reference (loaded as needed)
├── EXAMPLES.md           # Examples (loaded as needed)
└── scripts/              # Utility scripts (executed, not loaded)
```

## Degrees of Freedom

Match specificity to task fragility:

### High Freedom (Flexible Guidance)
Use when multiple approaches are valid:
```markdown
## Code Review Process
1. Analyze structure and organization
2. Check for bugs or edge cases
3. Suggest improvements
4. Verify conventions
```

### Medium Freedom (Preferred Pattern + Options)
Use when a default exists but variation is acceptable:
```markdown
## Report Format
Use this template, adapting as needed for context:
[template here]
```

### Low Freedom (Exact Instructions)
Use when operations are fragile or consistency is critical:
```markdown
## Database Migration
Run exactly this command:
```bash
python scripts/migrate.py --verify --backup
```
Do not modify flags.
```

## Three-Tier Boundaries

Define guardrails clearly:

```markdown
## Guardrails

### Always Do
- Run tests before completing
- Follow existing code patterns
- Document public APIs

### Ask First
- Adding new dependencies
- Changing public interfaces
- Modifying configuration files

### Never Do
- Commit secrets or credentials
- Skip pre-commit hooks
- Force push to main
```

## Organization & Limits

### Token Budgets
- SKILL.md body: Under 500 lines for optimal performance
- Full skill when loaded: <5K tokens recommended
- Each skill metadata: ~100 tokens

### File Placement
```
.claude/skills/<skill-name>/SKILL.md
```

### Naming Conventions
- Use gerund form: `writing-tests`, `creating-menus`
- Or noun phrases: `test-patterns`, `menu-structure`
- Be specific: `launcher-viewmodel-patterns` not `viewmodel-stuff`

## Anti-Patterns

### Vague Descriptions
**Bad:** `description: Helps with code`
**Good:** `description: Reviews Rust code for idiomatic patterns, error handling, and async correctness. Use when reviewing Rust PRs or asking for code review.`

### Over-Explaining What Claude Knows
**Bad:** "PDF (Portable Document Format) is a file format that..."
**Good:** "Use pdfplumber for text extraction:" [code]

### Time-Sensitive Content
**Bad:** "If you're doing this before August 2025, use v1..."
**Good:** Use "old patterns" sections:
```markdown
## Current Method
Use v2 API...

<details>
<summary>Legacy v1 API (deprecated 2025-08)</summary>
[old docs]
</details>
```

### Deeply Nested References
**Bad:** SKILL.md → advanced.md → details.md
**Good:** All references one level from SKILL.md

### Windows Paths
**Bad:** `scripts\helper.py`
**Good:** `scripts/helper.py`

### Too Many Options
**Bad:** "Use pypdf, or pdfplumber, or PyMuPDF, or..."
**Good:** "Use pdfplumber. For OCR, use pdf2image with pytesseract instead."

## Quick Reference Checklist

Before finishing a skill:

### Core Quality
- [ ] Description is specific, third person, includes triggers
- [ ] SKILL.md body under 500 lines
- [ ] Additional content in separate files if needed
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract

### Structure
- [ ] Frontmatter has name, description, allowed-tools
- [ ] File references are one level deep
- [ ] Three-tier boundaries defined (if applicable)
- [ ] Workflow has clear numbered steps (if task-focused)

### Discovery
- [ ] Description says WHAT AND WHEN
- [ ] Trigger words included
- [ ] Tests activation with sample queries

## Examples Index

See [EXAMPLES.md](EXAMPLES.md) for detailed examples. Each example is prefaced with when to reference it:

1. **Decision Tree Scenarios** - When deciding where knowledge belongs
2. **Architecture Reference Skill** - When creating domain-specific pattern docs
3. **Task Skill (Testing)** - When creating testing-related skills
4. **Task Skill (Workflow)** - When creating process/task skills
5. **Minimal Skill** - When creating quick utility skills
6. **Description Examples** - When writing/improving descriptions
7. **Progressive Disclosure** - When splitting content across files
8. **Three-Tier Boundaries** - When defining guardrails
