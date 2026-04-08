---
description: Session journal protocol — living document that survives compaction and captures what happened, what was decided, and why
tags: [protocol, session-journal, compaction, persistence]
audience: { human: 40, agent: 60 }
purpose: { low-agency-process: 60, reference: 40 }
---

# Session Journal Protocol

The session journal is a living notebook that persists across compactions. It captures the history of what happened, what was decided, and why — so that after compaction strips detailed context, the AI can recover its bearings.

## File Location

`<project>/.claude/session-journal.md`

Created automatically by `init-project.sh` on first session in a project.

## Structure

The journal has two parts:

### Current State (overwritten each update)

```markdown
## Current State
- **Focus:** what is being worked on right now
- **Blocked:** blockers, or "nothing"
```

This is a snapshot of NOW. Overwrite it completely each time you update.

### Log (append-only, newest first)

```markdown
## Log

### YYYY-MM-DD HH:MM — Event type: brief title
- What happened and why
- Key details a future session needs
- Files changed, decisions made, blockers hit
```

New entries go at the top, under `## Log`. Never overwrite existing entries.

## Event Types

| Type | When |
|------|------|
| `Plan` | A plan is approved or a direction is chosen |
| `Started` | Work kicks off on a new task or scope |
| `Completed` | A piece of work is done (commit, deployment, investigation) |
| `Decision` | A key decision is made — include WHY |
| `Blocked` | Something is preventing progress |
| `Context` | Before compaction — capture anything not yet journaled |

## When to Write

Write a log entry when ANY of these happen:
- A plan is approved or a direction is chosen
- Work kicks off on a new task
- A piece of work is completed
- A key decision is made (and WHY)
- Before compaction (capture anything not yet journaled)

## Compaction Behavior

### PreCompact hook (`session-journal.sh`)
- Trims the journal to 300 lines maximum
- Keeps the header and newest entries
- Oldest entries are dropped first

### Compact recovery (SessionStart matcher="compact")
- The full journal content is re-injected into the AI's context after compaction
- The AI's session ID (SID) is also re-injected from `.sid-*` files
- This is the primary mechanism for context survival across compaction

## Rules

- Always update Current State when writing a log entry
- Entries are append-only (newest first under `## Log`)
- Keep entries concise — 2-5 bullets each
- Include the WHY, not just the what
- Convert relative dates to absolute dates (e.g., "Thursday" becomes "2026-04-10")
