---
description: Architecture design for ABMS — the prosthetic limbic system for AI coding assistants
tags: [design, architecture, rules-engine, mempalace, fademem, hooks, limbic]
audience: { human: 55, agent: 45 }
purpose: { design: 75, flow: 15, reference: 10 }
---

# Design: Adaptive Behavioral Memory System

## Context

ABMS is a prosthetic limbic system composed of four integrated capabilities:

1. **Verbatim memory with spatial indexing** — Store everything, make it findable. MemPalace provides ChromaDB-backed semantic search organized into wings (projects/people), rooms (topics), and halls (memory types). A temporal knowledge graph tracks facts with validity windows.

2. **Salience-weighted forgetting** — Not everything matters equally. FadeMem-inspired importance scoring (semantic relevance + access frequency + recency) determines what surfaces and what fades. Corrections receive a salience boost over routine memories.

3. **Point-of-action injection** — Rules and memories surface in the recency zone of context, right before the AI acts. A switch-based rules engine matches the current action (tool, file, command) to relevant context. This is the delivery mechanism for everything the other components store and score.

4. **Outcome tracking and correction lifecycle** — Actions are logged. Corrections are filed from real incidents. Recurring corrections escalate from advisory to enforced. The system gets smarter from use.

Three flows document the operational processes:
- **Injection** — surfacing knowledge pre-action (02-flow-injection.md)
- **Outcome tracking** — capturing results post-action (03-flow-outcomes.md)
- **Correction lifecycle** — filing, matching, decaying, promoting corrections (04-flow-correction.md)

The design must integrate with 8 existing Claude Code hooks, the auto-memory system, session journal, worklog, and verification gate without replacing any of them.

## Constraints

- **Phase 1 must be zero-dependency.** Bash scripts and markdown files only. No Python, no ChromaDB, no external services.
- **Hook timeout budget.** PreToolUse hooks should complete in <1 second for Phase 1, <5 seconds for Phase 2+. Users feel latency on every action.
- **Context budget.** Injected rules consume context window tokens. Must be bounded to avoid competing with the actual work.
- **Human-readable state.** All corrections, rules, and logs must be readable and editable with a text editor.
- **Coexistence.** Existing hooks (git-safety, verify-gate, edit-tracker, post-bash) continue to function unchanged.

---

## Design

### Directory Structure

```
~/.claude/rules-engine/
├── engine.sh                    # Switch router: action → ruleset
├── inject.sh                    # PreToolUse hook: orchestrates injection
├── outcome.sh                   # PostToolUse hook: tracks outcomes
├── contexts/                    # Static rules per work type
│   ├── api.md                   # API verification rules
│   ├── ui.md                    # UI verification rules  
│   ├── data.md                  # Data verification rules
│   ├── commit.md                # Pre-commit rules
│   ├── push.md                  # Pre-push rules
│   ├── test-run.md              # Test execution rules
│   ├── test-write.md            # Test authoring rules
│   ├── infra.md                 # Infrastructure rules
│   └── general.md               # Fallback rules
├── anti-patterns/               # Common failure patterns (always loaded)
│   ├── shallow-200.md           # "200 is not verification"
│   ├── renders-not-works.md     # "Rendering is not working"
│   └── tests-pass-lie.md        # "Tests passing ≠ correct"
├── corrections/                 # Tagged correction files (grows over time)
│   └── YYYY-MM-DD_description.md
├── outcomes.log                 # Append-only action log (rotated)
└── .last-injection              # Marker file: what was injected pre-action
```

This directory lives alongside existing hook infrastructure:

```
~/.claude/
├── hooks/                       # EXISTING — unchanged
│   ├── git-safety.sh
│   ├── verify-gate.sh
│   ├── post-bash.sh
│   ├── edit-tracker.sh
│   ├── init-project.sh
│   ├── worklog-init.sh
│   └── session-journal.sh
├── rules-engine/                # NEW — ABMS
│   ├── (structure above)
├── settings.json                # MODIFIED — new hooks added to chains
├── CLAUDE.md                    # EXISTING — unchanged
├── rules/                       # EXISTING — unchanged
└── projects/                    # EXISTING — unchanged
```

### Component: engine.sh (Switch Router)

**Purpose:** Given an action (tool + command + file path), return the matching ruleset name.

**Input:** Three positional arguments:
1. `$1` — tool name (Bash, Edit, Write, Read)
2. `$2` — command string (for Bash) or empty
3. `$3` — file path (for Edit/Write) or empty

**Output:** Ruleset name on stdout (e.g., "api", "ui", "commit")

**Logic:**

```bash
#!/bin/bash
# engine.sh — route action to ruleset

TOOL="$1"
COMMAND="$2"
FILE_PATH="$3"

case "$TOOL" in
  Bash)
    case "$COMMAND" in
      git\ commit*|git\ -c\ *commit*)  echo "commit" ;;
      git\ push*)                       echo "push" ;;
      *test*|*jest*|*pytest*|*vitest*|*cargo\ test*|*go\ test*)
                                        echo "test-run" ;;
      *build*|*compile*|*tsc*)          echo "build" ;;
      curl*|wget*|http*)                echo "api-call" ;;
      *)                                echo "general-bash" ;;
    esac
    ;;
  Edit|Write)
    case "$FILE_PATH" in
      *.tsx|*.jsx|*.vue|*.svelte|*/components/*|*/pages/*|*/views/*)
        echo "ui" ;;
      */api/*|*/routes/*|*/handlers/*|*/controllers/*|*/endpoints/*)
        echo "api" ;;
      *.sql|*/migrations/*|*/seeds/*|*/fixtures/*)
        echo "data" ;;
      *.test.*|*.spec.*|*__tests__/*|*__mocks__/*)
        echo "test-write" ;;
      *.yaml|*.yml|*.toml|*/k8s/*|*/deploy/*|Dockerfile*|docker-compose*)
        echo "infra" ;;
      *)
        echo "general" ;;
    esac
    ;;
  *)
    echo "general" ;;
esac
```

**Extension point:** The case statement is the extension mechanism. Adding a new pattern is adding a line. No configuration files, no registries, no abstraction.

### Component: inject.sh (PreToolUse Hook)

**Purpose:** Orchestrate the four-layer injection pipeline and output rules to stdout.

**Input:** JSON on stdin from Claude Code harness.

**Output:** Concatenated rules on stdout (injected into assistant context).

**Logic (Phase 1):**

```bash
#!/bin/bash
# inject.sh — PreToolUse hook for ABMS rule injection

RULES_DIR="$HOME/.claude/rules-engine"
MAX_TOKENS=500  # approximate, using line count as proxy

# Parse input JSON
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))" 2>/dev/null)

TOOL_INPUT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
print(ti.get('command', ti.get('file_path', '')))" 2>/dev/null)

# Determine file_path and command
case "$TOOL" in
  Bash)   COMMAND="$TOOL_INPUT"; FILE_PATH="" ;;
  Edit|Write) COMMAND=""; FILE_PATH="$TOOL_INPUT" ;;
  *)      COMMAND=""; FILE_PATH="" ;;
esac

# Layer 1: Route to ruleset
RULESET=$("$RULES_DIR/engine.sh" "$TOOL" "$COMMAND" "$FILE_PATH")

# Layer 2: Check worklog scope for override
SCOPE=""
if [ -f "$CLAUDE_PROJECT_DIR/.claude/worklog.md" ]; then
  SCOPE=$(grep "^[a-f0-9]" "$CLAUDE_PROJECT_DIR/.claude/worklog.md" \
    | head -1 | cut -d'|' -f4 | tr -d ' ')
fi

# Layer 3: Load static rules
OUTPUT=""
CONTEXT_FILE="$RULES_DIR/contexts/$RULESET.md"
if [ -f "$CONTEXT_FILE" ]; then
  OUTPUT+="── ABMS Rules ($RULESET) ──
"
  OUTPUT+=$(cat "$CONTEXT_FILE")
  OUTPUT+="
"
fi

# Layer 4: Load matching corrections
CORRECTIONS=""
for f in "$RULES_DIR/corrections/"*.md; do
  [ -f "$f" ] || continue
  if head -10 "$f" | grep -q "^tags:.*$RULESET"; then
    CORRECTIONS+="$(sed -n '/^---$/,/^---$/!p' "$f" | head -20)
---
"
  fi
done

if [ -n "$CORRECTIONS" ]; then
  OUTPUT+="── Corrections ──
$CORRECTIONS"
fi

# Write marker for outcome.sh (what was injected)
echo "$RULESET" > "$RULES_DIR/.last-injection"

# Budget check (approximate: count lines as token proxy)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [ "$LINE_COUNT" -gt 40 ]; then
  # Truncate to budget — keep context rules, trim corrections
  OUTPUT=$(echo "$OUTPUT" | head -40)
  OUTPUT+="
(truncated — $LINE_COUNT lines available, showing 40)"
fi

# Output — harness injects this into context
[ -n "$OUTPUT" ] && echo "$OUTPUT"

exit 0
```

**Note on Python dependency:** The JSON parsing uses Python (available on all systems with Claude Code). If a pure-bash JSON parser is preferred, `jq` can substitute. The engine.sh itself is pure bash.

### Component: outcome.sh (PostToolUse Hook)

**Purpose:** Log outcomes and update correction access counts.

**Input:** JSON on stdin from Claude Code harness.

**Output:** None to stdout (this hook is a writer, not an injector).

**Logic (Phase 1):**

```bash
#!/bin/bash
# outcome.sh — PostToolUse hook for ABMS outcome tracking

RULES_DIR="$HOME/.claude/rules-engine"
LOG="$RULES_DIR/outcomes.log"
MARKER="$RULES_DIR/.last-injection"

# Parse input
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))" 2>/dev/null)

EXIT_CODE=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_result', {}).get('exit_code', 0))" 2>/dev/null)

# Log outcome
echo "$(date -Iseconds)|$TOOL|exit:$EXIT_CODE" >> "$LOG"

# Rotate log if over 500 lines
if [ $(wc -l < "$LOG" 2>/dev/null || echo 0) -gt 500 ]; then
  tail -250 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

# Bump access counts for corrections that were injected
if [ -f "$MARKER" ]; then
  RULESET=$(cat "$MARKER")
  for f in "$RULES_DIR/corrections/"*.md; do
    [ -f "$f" ] || continue
    if head -10 "$f" | grep -q "^tags:.*$RULESET"; then
      # Increment access_count in frontmatter
      if grep -q "^access_count:" "$f"; then
        COUNT=$(grep "^access_count:" "$f" | cut -d' ' -f2)
        NEW_COUNT=$((COUNT + 1))
        sed -i "s/^access_count: .*/access_count: $NEW_COUNT/" "$f"
        sed -i "s/^last_accessed: .*/last_accessed: $(date -Iseconds)/" "$f"
      fi
    fi
  done

  # Check for promotion candidates
  for f in "$RULES_DIR/corrections/"*.md; do
    [ -f "$f" ] || continue
    COUNT=$(grep "^access_count:" "$f" 2>/dev/null | cut -d' ' -f2)
    if [ "${COUNT:-0}" -ge 5 ]; then
      NAME=$(basename "$f")
      echo "⚠ RECURRING: $NAME (fired $COUNT times). Consider promoting to contexts/$RULESET.md"
    fi
  done

  rm -f "$MARKER"
fi

exit 0
```

### Hook Configuration

Added to `~/.claude/settings.json`, alongside existing hooks:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/git-safety.sh" },
          { "type": "command", "command": "~/.claude/hooks/verify-gate.sh" },
          { "type": "command", "command": "~/.claude/rules-engine/inject.sh", "timeout": 10 }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          { "type": "command", "command": "~/.claude/rules-engine/inject.sh", "timeout": 5 }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "~/.claude/rules-engine/inject.sh", "timeout": 5 }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/post-bash.sh", "timeout": 10 },
          { "type": "command", "command": "~/.claude/rules-engine/outcome.sh", "timeout": 5 }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/edit-tracker.sh", "timeout": 5 },
          { "type": "command", "command": "~/.claude/rules-engine/outcome.sh", "timeout": 5 }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/edit-tracker.sh", "timeout": 5 },
          { "type": "command", "command": "~/.claude/rules-engine/outcome.sh", "timeout": 5 }
        ]
      }
    ]
  }
}
```

### MemPalace Integration (Phase 2)

MemPalace runs as a separate MCP server:

```bash
claude mcp add mempalace -- python -m mempalace.mcp_server
```

**inject.sh gains Layer 5:** After loading static rules and corrections, it queries MemPalace:

```bash
# Phase 2 addition to inject.sh
if command -v mempalace &>/dev/null; then
  QUERY="corrections for $RULESET work in scope $SCOPE"
  MEMORY_RESULTS=$(mempalace search "$QUERY" \
    --wing "wing_$(basename $CLAUDE_PROJECT_DIR)" \
    --room "hall_advice" \
    --limit 3 2>/dev/null)
  
  if [ -n "$MEMORY_RESULTS" ]; then
    OUTPUT+="── Memory ──
$MEMORY_RESULTS
"
  fi
fi
```

**outcome.sh gains Palace writes:** Significant outcomes (test failures, corrections) are stored as drawers:

```bash
# Phase 2 addition to outcome.sh
if command -v mempalace &>/dev/null && [ "$EXIT_CODE" != "0" ]; then
  mempalace add-drawer \
    --wing "wing_$(basename $CLAUDE_PROJECT_DIR)" \
    --room "$RULESET" \
    --hall "hall_events" \
    --content "Test failure: $TOOL exit $EXIT_CODE at $(date -Iseconds)" \
    2>/dev/null
fi
```

**Auto-save hooks** from MemPalace are added alongside existing hooks:

```json
{
  "Stop": [{
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": "/path/to/mempalace/hooks/mempal_save_hook.sh",
      "timeout": 30
    }]
  }],
  "PreCompact": [{
    "matcher": "",
    "hooks": [
      { "type": "command", "command": "~/.claude/hooks/session-journal.sh", "timeout": 30, "async": true },
      { "type": "command", "command": "/path/to/mempalace/hooks/mempal_precompact_hook.sh", "timeout": 30 }
    ]
  }]
}
```

### FadeMem Scoring (Phase 3)

A Python module that scores MemPalace search results before injection:

```python
# fademem_scorer.py — importance scoring for memory results

import math
from datetime import datetime

def importance(memory, current_context, now=None):
    """Score a memory result by FadeMem importance formula."""
    now = now or datetime.now()
    
    # Semantic relevance (0-1, from MemPalace search distance)
    relevance = memory.get("similarity", 0.5)
    
    # Access frequency (saturating)
    access_count = memory.get("access_count", 0)
    frequency = access_count / (1 + access_count)
    
    # Recency (exponential decay, half-life ~14 days)
    last_accessed = memory.get("last_accessed")
    if last_accessed:
        days_since = (now - datetime.fromisoformat(last_accessed)).days
        recency = math.exp(-0.05 * days_since)
    else:
        recency = 0.1  # never accessed = low recency
    
    # Weighted combination
    score = 0.5 * relevance + 0.3 * frequency + 0.2 * recency
    
    # Correction boost
    if memory.get("hall") == "hall_advice" or "correction" in memory.get("tags", ""):
        score *= 1.5
    
    return min(score, 1.0)
```

inject.sh calls this scorer to rank memory results before injection, ensuring the most important results surface within the token budget.

### Cross-Cutting Concerns

**Performance:** Phase 1 hooks add <100ms per action (file reads only). Phase 2+ adds MemPalace query latency (~200-500ms for ChromaDB search). If timeout is hit, injection is skipped gracefully — the action proceeds without rules.

**Context budget:** Default 500 tokens (~40 lines). Configurable via `MAX_TOKENS` in inject.sh. If the combined output exceeds budget, items are trimmed by importance (corrections first, then memory results, static rules last).

**Multi-agent sessions:** Each agent has its own session, but all agents read the same rules-engine directory. Corrections filed by one agent benefit all agents. The worklog scope helps differentiate which rules are relevant per agent.

**Idempotency:** inject.sh can fire multiple times for the same action (e.g., if the harness retries). The marker file is overwritten, not appended. outcome.sh access count bumps are per-action, not per-fire.

---

## Trade-offs

| Chose | Over | Because |
|-------|------|---------|
| Bash scripts for Phase 1 | Python/Node from the start | Zero dependencies; anyone with a shell can use it |
| Markdown correction files | Database (SQLite, ChromaDB) | Human-readable, git-trackable, editable with any editor |
| Tag-based matching | Semantic matching only | Fast, predictable, debuggable; semantic matching added in Phase 2 |
| Advisory injection | Blocking hooks for all rules | Blocking is heavy-handed; reserve for proven persistent failures |
| Token budget cap | Unlimited injection | Context is finite; injecting too much is as bad as injecting nothing |
| Manual correction filing (Phase 1) | Automatic detection | False positive corrections would poison the store; manual is safer |
| FadeMem-style decay | Hard expiration dates | Decay preserves corrections that might become relevant again; expiration is permanent |

## Alternatives Considered

**Replace CLAUDE.md rules with ABMS entirely.** Rejected — CLAUDE.md serves a different purpose (identity, behavioral baseline). ABMS supplements with context-specific rules at the point of action. They are complementary.

**Use the existing MCP memory server instead of MemPalace.** The existing `mcp__memory` server provides basic CRUD on the same memory directory. MemPalace adds semantic search, spatial indexing, knowledge graph, and auto-save hooks that the basic server lacks. MemPalace is the better foundation for Phase 2+.

**Build a custom vector store instead of using MemPalace.** MemPalace already achieves 96.6% recall and has a working MCP server with 19 tools. Building from scratch would duplicate solved work.

**Use Letta instead of MemPalace.** Letta is a full agent runtime — significantly more complex, requires PostgreSQL, and replaces rather than integrates with Claude Code's architecture. MemPalace is a memory layer that bolts on.

**Implement real-time emotion detection on user messages.** Considered for salience scoring — detecting frustration or emphasis. Rejected as unreliable and creepy. Access frequency is a better proxy for importance: corrections that keep being needed are inherently important.

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Hook latency slows every action | Medium | High (UX) | Strict timeouts; Phase 1 is <100ms; graceful degradation |
| Wrong rules injected, confusing assistant | Medium | Medium | Worklog scope override; user can tag scope; rules are visible |
| Correction store grows unbounded | Low | Low | FadeMem decay; manual review; promotion removes active corrections |
| MemPalace ChromaDB corruption | Low | Medium | Phase 1 operates without MemPalace; corrections are files, not DB |
| User stops filing corrections | High | High | System value degrades without input; auto-detection in Phase 2+ reduces burden |
| Token budget too small, important rules truncated | Medium | Medium | Configurable budget; importance scoring prioritizes; user can adjust |
| Semantic search returns irrelevant results | Medium | Low | Tag matching as primary (Phase 1); semantic as supplement (Phase 2+) |

## Extension Points

- **New rulesets:** Add a case to engine.sh and a file to contexts/
- **New correction tags:** Just use them — no registration required
- **Custom scoring:** Replace fademem_scorer.py with any scoring function
- **Alternative memory backends:** Replace MemPalace search calls with any vector store
- **Blocking escalation:** When a correction fires N times without behavioral change, generate a blocking hook script (like verify-gate.sh). For destructive operations specifically, the production implementation is [dcg](https://github.com/Dicklesworthstone/destructive_command_guard) — a Rust-based hook with 49+ security packs. See `implementation/hooks/DCG-INTEGRATION.md` for how dcg fits the escalation ladder.
- **Multi-model verification:** Generate prompts for Gemini/Codex to cross-check (integrates with existing review-extensions skill)
