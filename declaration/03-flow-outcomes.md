---
description: Flow for post-action outcome tracking — how actions and their results are captured for future learning
tags: [flow, outcomes, post-action, tracking, feedback-loop]
audience: { human: 60, agent: 40 }
purpose: { flow: 80, design: 20 }
---

# Flow: Outcome Tracking (Post-Action)

## Purpose

Capture what happened after an action — success, failure, or correction — so the system builds a record of behavioral patterns over time. This is the write side of the feedback loop; the injection flow is the read side.

## Actors

| Actor | Role |
|-------|------|
| **Assistant** | Just completed a tool action |
| **Claude Code harness** | Fires PostToolUse hook, passes tool JSON + result on stdin |
| **outcome.sh** | Hook script — captures and routes outcomes |
| **Corrections directory** | Receives new correction files when user corrects behavior |
| **MemPalace** | Stores outcome records (Phase 2+) |
| **Knowledge graph** | Tracks failure patterns as entity-relationship triples (Phase 2+) |
| **User** | May correct the assistant's action, triggering a correction capture |

## Trigger

Any `PostToolUse` event fired by the Claude Code harness. The harness provides JSON on stdin containing:
- `tool_name` — the tool that was invoked
- `tool_input` — the tool's parameters
- `tool_result` — the output (including exit code for Bash)

## Stages

```
┌──────────────────────────────────────────────────┐
│ 1. RECEIVE                                        │
│    Parse tool_name, tool_input, tool_result        │
│    Determine outcome type:                         │
│      - test command + exit 0   → test-pass         │
│      - test command + exit ≠0  → test-fail         │
│      - git commit + success    → committed         │
│      - edit/write              → file-changed       │
│      - other                   → action-completed   │
└─────────────────────┬────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────┐
│ 2. LOG (Phase 1: lightweight)                     │
│    Append to .claude/rules-engine/outcomes.log:    │
│      timestamp | tool | command/file | outcome     │
│                                                    │
│    This is a simple append-only log for Phase 1.   │
│    Kept small — rotated at 500 lines.              │
└─────────────────────┬────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────┐
│ 3. BUMP ACCESS COUNTS (Phase 1)                   │
│    If rules were injected pre-action (inject.sh    │
│    wrote a marker file with the matched ruleset    │
│    and correction IDs):                            │
│                                                    │
│    For each correction that was surfaced:           │
│      Increment access_count in correction YAML     │
│      Update last_accessed timestamp                │
│                                                    │
│    This drives the FadeMem importance scoring —    │
│    frequently-accessed corrections stay relevant.   │
└─────────────────────┬────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────┐
│ 4. STORE IN PALACE (Phase 2+)                     │
│    mempalace_add_drawer:                           │
│      wing: project wing                            │
│      room: action type                             │
│      hall: hall_events                              │
│      content: verbatim action + outcome             │
│                                                    │
│    For test failures, committed code, and           │
│    significant outcomes only — not every edit.      │
└─────────────────────┬────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────┐
│ 5. UPDATE KNOWLEDGE GRAPH (Phase 2+)              │
│    On correction (when user corrects behavior):    │
│                                                    │
│    mempalace_kg_add:                               │
│      ("claude", "failed_at", "{pattern}",          │
│       valid_from=now)                              │
│                                                    │
│    On repeated failure:                            │
│      Query existing failures for this pattern      │
│      Update count/frequency                        │
│                                                    │
│    On success after previous failure:              │
│      mempalace_kg_add:                             │
│        ("claude", "recovered_from", "{pattern}",   │
│         valid_from=now)                            │
└──────────────────────────────────────────────────┘
```

## The Correction Capture Problem

The hardest part of this flow: **how does the system know the user is correcting the assistant vs. continuing the conversation?**

Explicit signals:
- User says "no", "wrong", "that's not right", "you didn't check"
- User edits a file the assistant just edited (undo/fix pattern)
- User reverts a commit the assistant just made

These could be detected by a hook or by pattern matching on user messages. However, false positives are dangerous — misinterpreting "no, the other approach" as a behavioral correction would pollute the correction store.

**Phase 1 approach:** Corrections are filed manually. The user runs a command or uses a shorthand to file a correction:

```bash
# Quick correction filing
abms correct --tags "ui,shallow-verification" \
  "Claimed UI was done without checking mobile viewport"
```

Or creates a markdown file directly in `corrections/`.

**Phase 2+ approach:** The assistant recognizes correction patterns and asks:

```
"That sounds like a correction to my approach. 
Should I file this as a behavioral correction? [y/n]"
```

User confirms → correction filed automatically with context.

**Phase 3+ approach:** Outcome.sh detects correction signals (user immediately re-editing, explicit negation patterns) and files corrections with lower confidence, requiring user confirmation on next access.

## Failure Modes

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Outcome logging overwhelms storage | Disk fills, performance degrades | Log rotation at 500 lines; Phase 2+ stores selectively |
| Correction filed with wrong tags | Surfaces in wrong context | Tags are human-editable; review process for high-frequency corrections |
| False positive correction detection (Phase 2+) | Pollutes correction store | Require user confirmation; low-confidence corrections marked |
| Access count inflation | Corrections appear more important than they are | Access count is per-unique-action, not per-hook-fire |
| KG grows unbounded | Query performance degrades | Invalidate resolved patterns; prune after 90 days of no access |

## Output

The outcome hook is primarily a writer, not a reader. Its outputs are:
- Appended lines in `outcomes.log`
- Updated `access_count` and `last_accessed` in correction frontmatter
- MemPalace drawers and KG triples (Phase 2+)

It does not inject content into the assistant's context — that is the injection flow's job.
