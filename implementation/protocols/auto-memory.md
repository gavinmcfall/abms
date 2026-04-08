---
description: Auto-memory protocol — persistent file-based memory that loads automatically at session start
tags: [protocol, memory, persistence, sessions]
audience: { human: 40, agent: 60 }
purpose: { reference: 60, low-agency-process: 40 }
---

# Auto-Memory Protocol

File-based memory that persists across sessions and loads automatically into the AI's context at startup.

## File Location

`~/.claude/projects/<project-id>/memory/`

Each project gets its own memory directory, keyed by a project identifier derived from the working directory path.

## Index File

`MEMORY.md` is the index. It is always loaded into the AI's context at session start. Each entry is one line, under ~150 characters:

```markdown
# Memory Index

- [User role](user_role.md) — senior engineer, Go + React, first time in this codebase
- [No mocking DB](feedback_no_mocks.md) — integration tests must hit real database
- [Auth rewrite](project_auth.md) — driven by legal/compliance, not tech debt
```

Lines after 200 are truncated. Keep the index concise.

## Memory File Format

Each memory is a separate markdown file with YAML frontmatter:

```markdown
---
name: descriptive name
description: one-line description used to decide relevance in future sessions
type: user | feedback | project | reference
---

Memory content here.
```

## Memory Types

| Type | Contains | When to Save |
|------|----------|-------------|
| **user** | Role, goals, preferences, knowledge level | When you learn about the user |
| **feedback** | Behavioral corrections — what to do and what to avoid | When the user corrects approach (positive or negative) |
| **project** | Ongoing work, goals, decisions, deadlines | When you learn who is doing what, why, or by when |
| **reference** | Pointers to external resources | When you learn where information lives |

## Writing a Memory

Two steps:

1. Write the memory file (e.g., `feedback_verify_api.md`)
2. Add a pointer to `MEMORY.md`

## What NOT to Save

- Code patterns or architecture (derive from code)
- Git history (use `git log`)
- Debugging solutions (the fix is in the code)
- Ephemeral task details (use tasks or session journal)
- Anything in CLAUDE.md (already loaded)

## Relationship to ABMS

Auto-memory stores facts about the user, project, and general corrections. ABMS corrections are more specific — they are tagged to action types and surfaced at the point of action, not at session start. The two systems complement each other:

- Auto-memory: "Gavin prefers Tailwind" (loaded at session start, general context)
- ABMS correction: "Last time you edited UI, you forgot to check mobile viewport" (loaded pre-action, specific to UI edits)

When an ABMS correction is so fundamental that it should always be present regardless of action type, it may be worth also adding as an auto-memory feedback entry.
