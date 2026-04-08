---
description: Installation guide for ABMS Phase 1 — rules engine, hooks, and correction tracking
tags: [install, setup, guide]
audience: { human: 90, agent: 10 }
purpose: { low-agency-process: 90, reference: 10 }
---

# Installing ABMS Phase 1

Phase 1 requires only bash and markdown. No Python, no external services.

## Prerequisites

- Claude Code installed and working
- `~/.claude/` directory exists
- `python3` available (used only for JSON parsing in hooks)

## Step 1: Copy hooks

Copy the existing hook scripts that ABMS integrates with:

```bash
mkdir -p ~/.claude/hooks
cp implementation/hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

If you already have hooks in `~/.claude/hooks/`, compare before overwriting — your versions may have customizations.

## Step 2: Copy rules engine

```bash
cp -r implementation/rules-engine ~/.claude/rules-engine
chmod +x ~/.claude/rules-engine/engine.sh
chmod +x ~/.claude/rules-engine/inject.sh
chmod +x ~/.claude/rules-engine/outcome.sh
```

## Step 3: Wire hooks into settings

Open `~/.claude/settings.json` and merge the hook configuration from `implementation/settings-hooks.json` into your existing `hooks` key.

If you don't have a `hooks` key yet, copy the entire block. If you do, add the ABMS entries alongside your existing hooks:

- **PreToolUse → Bash**: add `inject.sh` after your existing hooks
- **PreToolUse → Edit**: add `inject.sh`
- **PreToolUse → Write**: add `inject.sh`
- **PostToolUse → Bash**: add `outcome.sh` after your existing hooks
- **PostToolUse → Edit**: add `outcome.sh`
- **PostToolUse → Write**: add `outcome.sh`

## Step 4: Add permissions

In `~/.claude/settings.json` under `permissions.allow`, add:

```json
"Bash(~/.claude/rules-engine/inject.sh)",
"Bash(~/.claude/rules-engine/outcome.sh)",
"Bash(~/.claude/rules-engine/engine.sh)"
```

## Step 5: Verify

Test the engine routing:

```bash
~/.claude/rules-engine/engine.sh "Edit" "" "src/components/Foo.tsx"
# Should output: ui

~/.claude/rules-engine/engine.sh "Bash" "git commit -m test" ""
# Should output: commit
```

Test injection with simulated hook input:

```bash
echo '{"tool_name": "Edit", "tool_input": {"file_path": "src/components/Foo.tsx"}}' \
  | ~/.claude/rules-engine/inject.sh
# Should output UI verification rules
```

## Step 6: Start a new Claude Code session

The hooks take effect on the next session. Start Claude Code and edit a file — you should see ABMS rules injected into context before the edit proceeds.

## Filing corrections

When Claude makes a behavioral error, create a correction file:

```bash
cp ~/.claude/rules-engine/corrections/TEMPLATE.md \
   ~/.claude/rules-engine/corrections/$(date +%Y-%m-%d)_description.md
```

Edit the file:
- Set `tags` to match the rulesets where this correction should surface (e.g., `api, completion`)
- Set `date` to today
- Set `severity` to `low`, `medium`, `high`, or `critical`
- Write the correction in the body: what went wrong, what should happen instead

The correction will automatically surface when the tags match the current action's ruleset.

## Directory structure after install

```
~/.claude/
├── hooks/
│   ├── git-safety.sh          # Blocks dangerous git ops
│   ├── verify-gate.sh         # Blocks commits without test verification
│   ├── post-bash.sh           # Creates verification stamp on test pass
│   ├── edit-tracker.sh        # Clears verification stamp on edit
│   ├── init-project.sh        # Creates .claude/ project structure
│   ├── worklog-init.sh        # Registers sessions, coordinates concurrency
│   └── session-journal.sh     # Trims session journal on compaction
├── rules-engine/
│   ├── engine.sh              # Switch router: action → ruleset
│   ├── inject.sh              # PreToolUse hook: injects rules into context
│   ├── outcome.sh             # PostToolUse hook: tracks outcomes
│   ├── contexts/              # Static rules per work type
│   │   ├── api.md
│   │   ├── ui.md
│   │   ├── data.md
│   │   ├── commit.md
│   │   ├── push.md
│   │   ├── test-run.md
│   │   ├── test-write.md
│   │   ├── infra.md
│   │   └── general.md
│   ├── corrections/           # Tagged correction files (grows over time)
│   │   └── TEMPLATE.md
│   ├── outcomes.log           # Auto-generated action log
│   └── .last-injection        # Auto-generated marker for outcome tracking
└── settings.json              # Hook configuration
```
