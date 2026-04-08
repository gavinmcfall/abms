---
description: Complete inventory of existing Claude Code infrastructure that ABMS integrates with
tags: [reference, hooks, memory, infrastructure, claude-code]
audience: { human: 50, agent: 50 }
purpose: { reference: 90, design: 10 }
---

# Existing Systems Reference

Complete inventory of the Claude Code infrastructure that ABMS integrates with. All file paths and behaviors verified by direct observation on April 8, 2026.

---

## Hook Architecture

### Configuration

**File:** `~/.claude/settings.json` (under `hooks` key)

Hooks are shell commands that execute in response to Claude Code events. They receive JSON on stdin and can output text to stdout (injected into assistant context) or return a blocking decision.

### Hook Inventory

#### init-project.sh
- **Event:** SessionStart
- **Purpose:** Creates `.claude/` directory and template session journal for new projects
- **Reads:** Checks if `.claude/` and `.claude/session-journal.md` exist
- **Writes:** `.claude/` directory, `.claude/session-journal.md` (template)
- **Location:** `~/.claude/hooks/init-project.sh`

#### worklog-init.sh
- **Event:** SessionStart
- **Purpose:** Registers session with unique 8-char hex SID, cleans stale sessions (>4h), trims log to 50 entries
- **Reads:** `.claude/worklog.md`, system time
- **Writes:** `.claude/worklog.md`, `.claude/.sid-<SID>`, `.claude/.worklog.lock`
- **Output:** `WORKLOG_SID=<hex>` injected into session context
- **Location:** `~/.claude/hooks/worklog-init.sh`

#### session-journal.sh
- **Event:** PreCompact
- **Purpose:** Trims session journal to 300 lines (keeps header + newest entries)
- **Reads:** `.claude/session-journal.md`
- **Writes:** `.claude/session-journal.md` (trimmed)
- **Location:** `~/.claude/hooks/session-journal.sh`

#### Compact Recovery
- **Event:** SessionStart (matcher: "compact")
- **Purpose:** Re-injects session journal and SID after compaction
- **Reads:** `.claude/session-journal.md`, `.claude/.sid-*`, `.claude/worklog.md`
- **Writes:** Nothing (read-only recovery)
- **Configuration:** Inline commands in settings.json (not separate scripts)

#### git-safety.sh
- **Event:** PreToolUse (Bash)
- **Purpose:** Blocks dangerous git operations (--amend, --force, reset --hard, etc.). Advisory warning if multiple sessions active.
- **Reads:** stdin JSON (command), `.claude/worklog.md`
- **Writes:** Nothing
- **Blocks:** Returns exit 2 to block execution
- **Location:** `~/.claude/hooks/git-safety.sh`

#### verify-gate.sh
- **Event:** PreToolUse (Bash)
- **Purpose:** Blocks `git commit` if no verification stamp exists or stamp is stale (>30 min)
- **Reads:** `.claude/.verified` (checks existence and age)
- **Writes:** Deletes `.verified` if stale
- **Blocks:** Returns exit 2 to block commit
- **Location:** `~/.claude/hooks/verify-gate.sh`

#### post-bash.sh
- **Event:** PostToolUse (Bash)
- **Purpose:** Creates verification stamp when test/build commands pass (exit 0). Tracks session elapsed time.
- **Reads:** stdin JSON (command, exit code), `.claude/.session-tracker`
- **Writes:** `.claude/.verified` (on test pass), `.claude/.session-tracker`
- **Recognized test commands:** npm test, pytest, go test, cargo test, dotnet test, make test, bun test, pnpm test, yarn test, gradle test, mvn test
- **Location:** `~/.claude/hooks/post-bash.sh`

#### edit-tracker.sh
- **Event:** PostToolUse (Edit, Write)
- **Purpose:** Clears verification stamp on every file edit. Counts edits, nudges every 5.
- **Reads:** `.claude/.verified`, `.claude/.edit-count`
- **Writes:** Deletes `.claude/.verified`, updates `.claude/.edit-count`
- **Location:** `~/.claude/hooks/edit-tracker.sh`

### Verification Gate Chain

The most effective behavioral enforcement mechanism:

```
Edit file → edit-tracker.sh clears .verified
                    ↓
Run tests → post-bash.sh creates .verified (if pass)
                    ↓
git commit → verify-gate.sh checks .verified exists and is <30min old
                    ↓
           Blocked if missing or stale
```

This works because it operates at the action level — it physically prevents the undesired action.

---

## Memory Systems

### Auto-Memory
- **Location:** `~/.claude/projects/<project-id>/memory/`
- **Index:** `MEMORY.md` (loaded into every session automatically)
- **Types:** user, feedback, project, reference
- **Format:** Markdown files with YAML frontmatter (name, description, type)
- **Injection:** Automatic at session start
- **Current state:** 4 entries in home project

### CLAUDE.md
- **Location:** `~/.claude/CLAUDE.md` (global), project-level `.claude/CLAUDE.md`
- **Content:** 20 behavioral rules + session journal protocol + worklog protocol + subagent model selection
- **Injection:** Automatic at session start (primacy zone)

### Rules Files
- **Location:** `~/.claude/rules/*.md`
- **Files:** `skills.md`, `review-patterns.md`, `session-cleanup.md`
- **Injection:** Referenced at session start

### Session Journal
- **Location:** `<project>/.claude/session-journal.md`
- **Structure:** Current State (overwritten) + Log (append-only, newest first)
- **Persistence:** Survives compaction (re-injected by compact recovery hook)
- **Trimming:** 300 lines max (session-journal.sh PreCompact hook)

### Worklog
- **Location:** `<project>/.claude/worklog.md`
- **Structure:** @ACTIVE (current sessions) + @LOG (operations)
- **Persistence:** Survives sessions
- **Trimming:** 50 entries max
- **Locking:** flock on `.claude/.worklog.lock`

### Harness Internals (Opaque)
- `~/.claude/history.jsonl` — full conversation history (not queryable by assistant)
- `~/.claude/file-history/` — 210 directories of file edit snapshots
- `~/.claude/projects/<id>/sessions-index.json` — session metadata
- `~/.claude/.credentials.json` — cached auth tokens

---

## MCP Servers

### With Local Data Storage
- **Memory MCP** — knowledge graph entities in `~/.claude/projects/*/memory/`

### External Services
- Google Calendar, Gmail — Google cloud
- Cloudflare (5 servers) — DNS, observability, workers, builds, agents SDK
- Migadu — email management
- Brave Search — web search (15-min cache)
- Firecrawl — web scraping
- Context7 — documentation lookup

### Stateless
- Playwright — browser automation
- Fetch — HTTP requests
- Mermaid — diagram validation
- Time — current time
- 21st-dev-magic — component building
- Instant Domain Search — domain checking

---

## File Map

```
~/.claude/
├── CLAUDE.md                              # Behavioral rules (injected every session)
├── rules/*.md                             # Supplementary rules
├── settings.json                          # Hooks, permissions, MCP config
├── settings.local.json                    # Local overrides
├── .credentials.json                      # Auth tokens (auto-managed)
├── history.jsonl                          # Conversation history (opaque)
├── master-prompts/gavin-core-profile.md   # Personality profile
├── hooks/
│   ├── init-project.sh
│   ├── worklog-init.sh
│   ├── session-journal.sh
│   ├── git-safety.sh
│   ├── verify-gate.sh
│   ├── post-bash.sh
│   └── edit-tracker.sh
├── plugins/cache/                         # Plugin code (auto-managed)
├── file-history/                          # File edit snapshots
├── projects/<project-id>/
│   ├── memory/
│   │   ├── MEMORY.md                      # Memory index
│   │   └── *.md                           # Individual memories
│   ├── sessions-index.json
│   └── <session-uuid>.jsonl

<project>/.claude/
├── session-journal.md                     # Living journal
├── worklog.md                             # Session coordination
├── .worklog.lock                          # Mutex
├── .sid-*                                 # Session identity files
├── .verified                              # Test verification stamp
├── .edit-count                            # Edit counter
└── .session-tracker                       # Session elapsed time
```
