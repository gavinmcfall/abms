# Setting Up ABMS — Quick Start Guide

This gets you a working Adaptive Behavioral Memory System for Claude Code. It makes Claude remember past mistakes and surface relevant corrections before every action — instead of repeating the same failures session after session.

**What it does:** Every time Claude is about to edit a file, run a command, or commit code, a hook fires that injects context-specific rules and any corrections you've filed from past incidents. Over time, the corrections that keep being relevant rise in importance, and the ones that stop mattering fade.

**What you need:** Claude Code installed and working, a terminal, ~30 minutes.

---

## Phase 1: Rules Engine (no dependencies, just bash + markdown)

### Step 1: Clone the repo

```bash
git clone https://github.com/gavinmcfall/abms.git
cd abms
```

### Step 2: Copy the hooks

If you already have hooks in `~/.claude/hooks/`, back them up first:

```bash
# Back up existing hooks (if any)
[ -d ~/.claude/hooks ] && cp -r ~/.claude/hooks ~/.claude/hooks.backup

# Copy ABMS hooks
mkdir -p ~/.claude/hooks
cp implementation/hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

### Step 3: Copy the rules engine

```bash
cp -r implementation/rules-engine ~/.claude/rules-engine
chmod +x ~/.claude/rules-engine/engine.sh
chmod +x ~/.claude/rules-engine/inject.sh
chmod +x ~/.claude/rules-engine/outcome.sh
```

### Step 4: Wire the hooks into Claude Code

Open `~/.claude/settings.json` in your editor. If you don't have one yet, create it.

You need to add hook entries. The full configuration is in `implementation/settings-hooks.json` — you can use it as a reference. The key sections to add under the `"hooks"` key:

**PreToolUse** — these fire BEFORE Claude uses a tool:

```json
"PreToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      { "type": "command", "command": "~/.claude/hooks/git-safety.sh" },
      { "type": "command", "command": "~/.claude/hooks/verify-gate.sh" },
      { "type": "command", "command": "~/.claude/rules-engine/inject.sh", "timeout": 5 }
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
]
```

**PostToolUse** — these fire AFTER Claude uses a tool:

```json
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
```

**Also add these supporting hooks** (session management, compaction survival):

```json
"PreCompact": [
  {
    "matcher": "auto",
    "hooks": [
      { "type": "command", "command": "~/.claude/hooks/session-journal.sh", "timeout": 30, "async": true }
    ]
  }
],
"SessionStart": [
  {
    "matcher": "",
    "hooks": [
      { "type": "command", "command": "~/.claude/hooks/init-project.sh" },
      { "type": "command", "command": "~/.claude/hooks/worklog-init.sh", "timeout": 15 }
    ]
  },
  {
    "matcher": "compact",
    "hooks": [
      { "type": "command", "command": "cat $CLAUDE_PROJECT_DIR/.claude/session-journal.md 2>/dev/null || echo 'No journal found'" },
      { "type": "command", "command": "SID_FILE=$(ls -t $CLAUDE_PROJECT_DIR/.claude/.sid-* 2>/dev/null | head -1); echo \"WORKLOG_SID=$(cat $SID_FILE 2>/dev/null || echo unknown)\"; cat $CLAUDE_PROJECT_DIR/.claude/worklog.md 2>/dev/null || echo 'No worklog'" }
    ]
  }
]
```

If you already have hooks in your settings.json, add the ABMS entries alongside them — don't replace existing hooks.

### Step 5: Add permissions

Under `"permissions"` → `"allow"` in settings.json, add:

```json
"Bash(~/.claude/hooks/git-safety.sh)",
"Bash(~/.claude/hooks/session-journal.sh)",
"Bash(~/.claude/hooks/init-project.sh)",
"Bash(~/.claude/hooks/verify-gate.sh)",
"Bash(~/.claude/hooks/post-bash.sh)",
"Bash(~/.claude/hooks/edit-tracker.sh)",
"Bash(~/.claude/rules-engine/inject.sh)",
"Bash(~/.claude/rules-engine/outcome.sh)",
"Bash(~/.claude/rules-engine/engine.sh)"
```

### Step 6: Add ABMS to your CLAUDE.md

Add this to the top of your `~/.claude/CLAUDE.md` (create the file if it doesn't exist):

```markdown
## ABMS — Adaptive Behavioral Memory System

You have a prosthetic limbic system. Before every tool call, corrections from past incidents and context-specific verification rules are injected into your context via hooks. These are not suggestions — they are lessons from real failures.

When you see `── ABMS ──` or `── Corrections ──` in hook output:
1. **Read them.** They are there because you made this specific type of mistake before.
2. **Follow them.** The correction exists because ignoring the pattern burned someone.
3. **Before claiming done**, ask yourself: does my evidence satisfy the injected rules, or am I about to repeat a documented failure?
```

### Step 7: Verify it works

Start a new Claude Code session and try editing a file:

```bash
# Test the engine directly
~/.claude/rules-engine/engine.sh "Edit" "" "src/components/Foo.tsx"
# Should output: ui

# Test injection with simulated input
echo '{"tool_name": "Edit", "tool_input": {"file_path": "src/components/Foo.tsx"}}' \
  | ~/.claude/rules-engine/inject.sh
# Should output UI verification rules
```

If you see rules output, it's working. Every Edit, Write, and Bash action in Claude Code will now get context-specific rules injected.

### Step 8: Delete the example corrections

The repo includes example corrections from someone else's incidents. Delete them and start fresh — your corrections should come from your own experience:

```bash
rm ~/.claude/rules-engine/corrections/2026-04-11_*.md
```

The `TEMPLATE.md` file stays — use it as the format reference.

---

## Filing Your First Correction

When Claude does something that frustrates you — gives up on a feature, claims something works without checking, modifies tests instead of fixing code — file a correction:

```bash
cp ~/.claude/rules-engine/corrections/TEMPLATE.md \
   ~/.claude/rules-engine/corrections/$(date +%Y-%m-%d)_short-description.md
```

Edit the file:

```markdown
---
tags: api, completion
date: 2026-04-11
severity: high
access_count: 0
last_accessed: null
promoted_to: null
---

What went wrong and what should have happened.

Be specific — this will be shown to Claude right before it makes
the same type of mistake again.
```

**Tags** determine when it surfaces. Available rulesets: `api`, `ui`, `data`, `commit`, `push`, `test-run`, `test-write`, `infra`, `general`. A correction tagged `api` will surface every time Claude edits an API file.

That's it. The correction will surface automatically on matching actions from now on.

---

## Phase 2: MemPalace (optional, adds semantic memory search)

Phase 2 adds a searchable memory bank so Claude can ask "what have I forgotten?" before every action. Requires Python.

### Install

```bash
# Use pipx for isolated install (recommended)
pipx install mempalace

# Or standard pip if your Python isn't externally-managed
pip install mempalace
```

### Initialize and mine your conversations

```bash
# Initialize the palace
mempalace init ~/your-main-project --yes

# Mine your Claude Code conversation history
mempalace mine ~/.claude/projects --mode convos

# Mine project files
mempalace mine ~/your-project
```

Mining conversation history can take hours depending on how many sessions you have. Run it in the background:

```bash
nohup mempalace mine ~/.claude/projects --mode convos > /tmp/mempalace-mine.log 2>&1 &
```

### Register the MCP server

For pipx installs:
```bash
claude mcp add --scope user mempalace -- \
  ~/.local/pipx/venvs/mempalace/bin/python -m mempalace.mcp_server
```

For standard pip installs:
```bash
claude mcp add --scope user mempalace -- python -m mempalace.mcp_server
```

The `--scope user` is important — without it, the MCP server only loads in the directory where you ran the command.

### Add auto-save hooks

Add these to your `~/.claude/settings.json` hooks section:

```json
"Stop": [
  {
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": "mempalace hook run --hook stop --harness claude-code",
      "timeout": 30
    }]
  }
],
"PreCompact": [
  {
    "matcher": "auto",
    "hooks": [{
      "type": "command",
      "command": "mempalace hook run --hook precompact --harness claude-code",
      "timeout": 60
    }]
  }
]
```

Add `PreCompact` alongside any existing PreCompact hooks (don't replace them).

### Swap to the Phase 2 inject.sh

```bash
cp ~/.claude/rules-engine/inject.sh ~/.claude/rules-engine/inject.sh.phase1.bak
cp implementation/phase-2-memory/inject-phase2.sh ~/.claude/rules-engine/inject.sh
chmod +x ~/.claude/rules-engine/inject.sh
```

Now every action will search your palace for relevant memories alongside the static rules.

---

## Phase 3: FadeMem Scoring (optional, ranks memory by importance)

Adds importance scoring so the most relevant memories surface first.

```bash
cp implementation/phase-3-salience/fademem_scorer.py ~/.claude/rules-engine/
cp implementation/phase-3-salience/score_results.py ~/.claude/rules-engine/
```

inject.sh automatically detects the scorer and uses it. No other configuration needed.

---

## Phase 4: Lifecycle Automation (optional)

Adds tools to review which corrections should be promoted to permanent rules.

```bash
cp implementation/phase-4-self-improving/promote.sh ~/.claude/rules-engine/
cp implementation/phase-4-self-improving/escalate.sh ~/.claude/rules-engine/
cp implementation/phase-4-self-improving/lifecycle.sh ~/.claude/rules-engine/
chmod +x ~/.claude/rules-engine/promote.sh
chmod +x ~/.claude/rules-engine/escalate.sh
chmod +x ~/.claude/rules-engine/lifecycle.sh
```

Run the lifecycle review anytime:

```bash
~/.claude/rules-engine/promote.sh
```

Or set up a weekly cron:

```bash
crontab -e
# Add: 0 9 * * 1 ~/.claude/rules-engine/lifecycle.sh >> /tmp/abms-lifecycle.log 2>&1
```

---

## Enforcement Layer: dcg (strongly recommended)

ABMS corrections are advisory — they surface in context but don't block the action. For destructive operations (DROP TABLE, rm -rf, git push --force, kubectl delete, etc.), advisory isn't enough. This is the role of [dcg (Destructive Command Guard)](https://github.com/Dicklesworthstone/destructive_command_guard) — a Rust-based hook with 49+ security packs that physically blocks destructive commands.

dcg is developed independently from ABMS but integrates into the same PreToolUse hook chain. See [DCG-INTEGRATION.md](implementation/hooks/DCG-INTEGRATION.md) for the full integration rationale.

### Install dcg

Try the official installer first:

```bash
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.sh?$(date +%s)" | bash -s -- --easy-mode
```

The installer auto-wires dcg into Claude Code, Gemini CLI, Codex, and Cursor settings files.

### glibc version mismatch (Ubuntu 22.04 and older)

On Ubuntu 22.04 LTS (glibc 2.35), the pre-built binary fails to load (requires glibc 2.39). Build from source:

```bash
cargo install --git https://github.com/Dicklesworthstone/destructive_command_guard --locked destructive_command_guard
```

Then update the hook path in `~/.claude/settings.json` from `/home/youruser/.local/bin/dcg` to `/home/youruser/.cargo/bin/dcg`.

### Configure packs for your stack

The default install only enables the `core` pack. Copy the stack-appropriate config:

```bash
mkdir -p ~/.config/dcg
cp implementation/hooks/dcg-config.toml ~/.config/dcg/config.toml
```

Review the file and comment out packs you don't need (e.g. remove `cloud.aws` if you don't use AWS). Each pack adds blocking rules for a specific tool category.

### Keep destructive-gate.sh for custom scripts

dcg doesn't know about custom scripts with destructive flags (e.g. `load_staging.py --full-wipe`). The included `destructive-gate.sh` catches these:

- `--full-wipe`, `--wipe`, `--truncate`, `--reset-hard`, `--drop-all`, `--nuke`, `--purge-all`

It runs AFTER dcg in the hook chain. Your settings.json should have:

```json
"PreToolUse": [{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "~/.cargo/bin/dcg" },
    { "type": "command", "command": "~/.claude/hooks/destructive-gate.sh" },
    { "type": "command", "command": "~/.claude/hooks/git-safety.sh" },
    { "type": "command", "command": "~/.claude/hooks/verify-gate.sh" },
    { "type": "command", "command": "~/.claude/rules-engine/inject.sh", "timeout": 5 }
  ]
}]
```

Hard enforcement first (dcg, destructive-gate, verify-gate), advisory last (inject.sh for ABMS rules and memory).

---

## How It Works (the short version)

Every time Claude is about to use a tool (edit a file, run a command, commit), hooks fire in sequence:

**Hard enforcement (fails closed):**
1. **dcg** — Blocks 49+ classes of destructive commands (rm -rf, DROP TABLE, kubectl delete, git push --force, etc.)
2. **destructive-gate.sh** — Blocks custom script flags (--full-wipe, --nuke, etc.) that dcg doesn't know about
3. **git-safety.sh** — Blocks dangerous git operations
4. **verify-gate.sh** — Blocks git commits without passing tests

**Advisory (informs but doesn't block):**
5. **inject.sh** — Routes the action, loads context-specific rules, matches corrections by tag, searches memory, scores by importance, injects all of it into Claude's context

Advisory lands in Claude's context in the "recency zone" — right before the action, where attention is strongest. Not at the start of the session where it would fade over a long conversation.

After the action, another hook logs the outcome and bumps access counts on corrections that fired. Corrections that keep being relevant grow in importance. Corrections that stop matching fade naturally. Every Monday, the lifecycle script reviews correction health and flags promotion candidates.

When advisory corrections aren't enough (the AI ignores them despite 100+ surfacings), the escalation path is: correction → permanent rule → blocking hook. The dcg integration is where that final enforcement lives.

The full design rationale, research, and architecture documentation is in the `declaration/` directory if you want to understand the why behind all of this.
