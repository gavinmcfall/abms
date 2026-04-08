---
description: Flow for pre-action rule injection — how rules and corrections reach the assistant at the moment of action
tags: [flow, injection, pre-action, hooks, rules-engine]
audience: { human: 60, agent: 40 }
purpose: { flow: 80, design: 20 }
---

# Flow: Rule Injection (Pre-Action)

## Purpose

Surface relevant rules, corrections, and forgotten context to the AI assistant immediately before it acts — placing them in the recency zone of the context window where attention is strongest.

## Actors

| Actor | Role |
|-------|------|
| **Assistant** | About to execute a tool (Edit, Write, Bash, etc.) |
| **Claude Code harness** | Fires PreToolUse hook, passes tool JSON on stdin |
| **inject.sh** | Hook script — orchestrates the injection pipeline |
| **engine.sh** | Switch router — matches action to ruleset |
| **Rules directory** | Static rule files and tagged correction files |
| **Worklog** | Provides current scope context |
| **MemPalace** | Provides semantic search and knowledge graph (Phase 2+) |
| **FadeMem scorer** | Ranks memory results by importance (Phase 3+) |

## Trigger

Any `PreToolUse` event fired by the Claude Code harness. The harness provides JSON on stdin containing:
- `tool_name` — the tool being invoked (Bash, Edit, Write, Read, etc.)
- `tool_input` — the tool's parameters (command for Bash, file_path for Edit, etc.)

## Stages

```
┌─────────────────────────────────────────────────┐
│ 1. RECEIVE                                       │
│    Parse tool_name and tool_input from stdin JSON │
│    Extract: command (if Bash), file_path (if      │
│    Edit/Write), any other action signals          │
└────────────────────┬────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│ 2. ROUTE (engine.sh)                             │
│    Switch on tool + command + file path:          │
│                                                   │
│    Bash:                                          │
│      git commit*  → ruleset: commit               │
│      git push*    → ruleset: push                 │
│      *test*       → ruleset: test-run             │
│      *build*      → ruleset: build                │
│      curl/wget    → ruleset: api-call             │
│      *            → ruleset: general-bash         │
│                                                   │
│    Edit/Write:                                    │
│      *.tsx|*.jsx|*/components/*  → ruleset: ui     │
│      */api/*|*/routes/*         → ruleset: api     │
│      *.sql|*/migrations/*       → ruleset: data    │
│      *.test.*|*.spec.*          → ruleset: test    │
│      *.yaml|*/k8s/*|Dockerfile  → ruleset: infra   │
│      *                          → ruleset: general │
│                                                   │
│    Output: RULESET name                           │
└────────────────────┬────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│ 3. ENRICH (scope context)                        │
│    Read worklog scope from .claude/worklog.md     │
│    If scope provides stronger signal than file    │
│    path, override or augment the ruleset.         │
│                                                   │
│    Example: scope="scbridge-ui" + file="utils.ts" │
│    → augment with UI rules despite .ts extension  │
└────────────────────┬────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│ 4. LOAD STATIC RULES                             │
│    Cat the matching context file:                 │
│      rules-engine/contexts/{ruleset}.md           │
│                                                   │
│    Search corrections by tag:                     │
│      grep -rl "^tags:.*{ruleset}" corrections/    │
│      Cat matching correction files                │
└────────────────────┬────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│ 5. QUERY MEMORY (Phase 2+)                       │
│    Build contextual query from:                   │
│      tool + file + scope + ruleset                │
│                                                   │
│    mempalace_search:                              │
│      "corrections for {ruleset} in {scope}"       │
│      wing={project}, room=hall_advice             │
│                                                   │
│    mempalace_kg_query:                            │
│      entity="claude", predicate="failed_at"       │
│      → past failure patterns                      │
│                                                   │
│    Score results by FadeMem importance (Phase 3+):│
│      I(t) = α·relevance + β·frequency + γ·recency│
│      Surface top N (configurable, default 3)      │
└────────────────────┬────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│ 6. INJECT                                        │
│    Concatenate: static rules + corrections +      │
│    memory results (if any)                        │
│                                                   │
│    Budget: max ~500 tokens to avoid context bloat │
│    Truncate lowest-importance items if over budget │
│                                                   │
│    Output to stdout → harness injects into        │
│    assistant's context (recency zone)             │
└─────────────────────────────────────────────────┘
```

## Failure Modes

| Failure | Impact | Mitigation |
|---------|--------|------------|
| No matching ruleset | No rules injected; action proceeds uninstructed | `general.md` catches everything not matched by a specific ruleset |
| Wrong ruleset matched | Irrelevant rules injected; assistant confused | Worklog scope as override; user can tag scope explicitly |
| Too many rules injected | Context bloat; rules compete with each other | Token budget cap (default 500); importance scoring prioritizes |
| MemPalace unavailable | No memory query results | Phase 1 operates without MemPalace; Layer 5 is skipped gracefully |
| Hook timeout | Injection doesn't complete; action proceeds | Set timeout to 5-10 seconds; static rules load in <100ms |
| Correction tagged wrong | Surfaces in wrong context | Tags are human-editable; frequent misfires indicate bad tagging |

## Coexistence With Existing Hooks

This hook runs alongside, not instead of, existing PreToolUse hooks:

```json
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "~/.claude/hooks/git-safety.sh" },
    { "type": "command", "command": "~/.claude/hooks/verify-gate.sh" },
    { "type": "command", "command": "~/.claude/rules-engine/inject.sh", "timeout": 10 }
  ]
}
```

The inject hook is advisory (outputs rules), not blocking. The existing git-safety and verify-gate hooks remain blocking where appropriate. Order: safety checks first, then rule injection.

For Edit/Write tools, inject.sh is added alongside the existing edit-tracker.sh.

## Output Format

The hook outputs plain text that the harness injects as context. Format:

```
── ABMS Rules ({ruleset}) ──────────────────────
{static rules content}

── Corrections ──────────────────────────────────
{matched correction content, if any}

── Memory ({N} results, scored) ─────────────────
{MemPalace search results, if Phase 2+ active}
─────────────────────────────────────────────────
```
