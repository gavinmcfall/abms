---
description: Worklog protocol — concurrent session coordination so multiple AI instances don't step on each other
tags: [protocol, worklog, concurrency, sessions]
audience: { human: 40, agent: 60 }
purpose: { low-agency-process: 60, reference: 40 }
---

# Worklog Protocol

The worklog coordinates multiple concurrent Claude Code sessions working on the same project. The hook handles registration and cleanup automatically — the AI's job is minimal.

## File Location

`<project>/.claude/worklog.md`

Created automatically by `worklog-init.sh` on first session.

## Format (v2)

```
# WORKLOG v2

@ACTIVE
# sid|registered|last_active|scope
68b9b242|2026-04-08T17:56+1200|2026-04-08T17:56+1200|unset

@LOG
# timestamp|sid|op|detail
2026-04-08T17:56+1200|68b9b242|REG|started
```

## Session Identity

On startup, the hook prints `WORKLOG_SID=<8-char-hex>`. The AI must remember this. After compaction, the SID is re-injected from `.sid-*` files.

## What the Hook Does Automatically

| Action | Mechanism |
|--------|-----------|
| Register new session | `worklog-init.sh` at SessionStart |
| Clean stale sessions (>4h) | `worklog-init.sh` at SessionStart |
| Create `.sid-<SID>` identity file | `worklog-init.sh` at SessionStart |
| Delete stale `.sid-*` files | `worklog-init.sh` at SessionStart |
| Trim @LOG to 50 entries | `worklog-init.sh` at SessionStart |
| Warn on multi-session pre-commit | `git-safety.sh` at PreToolUse |
| Re-inject SID after compaction | Compact recovery hook at SessionStart |

## What the AI Does Manually

| Event | Action |
|-------|--------|
| Starting work on a scope | Update @ACTIVE scope. Log `SCO` |
| Changing scope | Update @ACTIVE scope. Log `SCO` |
| After committing | Log `CMT` |

All writes use flock for atomic operations:

```bash
# Set scope
flock -w 3 .claude/.worklog.lock -c \
  "sed -i 's/^<SID>|.*/<SID>|<registered>|<now>|<scope>/' .claude/worklog.md"

# Log an operation
flock -w 3 .claude/.worklog.lock -c \
  "echo '<now>|<SID>|<op>|<detail>' >> .claude/worklog.md"
```

## Operation Codes

| Code | Meaning |
|------|---------|
| `REG` | Session registered |
| `SCO` | Scope changed |
| `CMT` | Committed |
| `CLN` | Stale session cleaned |
| `END` | Session ended |

## Pre-Commit Safety

`git-safety.sh` checks @ACTIVE for multiple sessions. If more than one session is active, it outputs an advisory warning. The AI should check what the other session is working on and confirm with the user before committing.

## Supporting Files

| File | Purpose |
|------|---------|
| `.claude/worklog.md` | The worklog itself |
| `.claude/.worklog.lock` | flock mutex for atomic writes |
| `.claude/.sid-<hex>` | Session identity sidecar (one per active session) |
