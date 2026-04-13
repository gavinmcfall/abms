---
description: How dcg (Destructive Command Guard) integrates with ABMS as the primary enforcement layer
tags: [hooks, dcg, enforcement, escalation]
audience: { human: 60, agent: 40 }
purpose: { reference: 60, design: 40 }
---

# dcg Integration

## Context

The ABMS escalation ladder (from the RFC):
1. Incident → correction (advisory, surfaces on matching actions)
2. Recurring correction → permanent rule (advisory, always present)
3. **Persistent failure despite rule → blocking hook (enforcement)**

[dcg (Destructive Command Guard)](https://github.com/Dicklesworthstone/destructive_command_guard) is the production implementation of step 3 for destructive commands. It's a Rust-based hook with 49+ security packs covering git, filesystem, databases, Kubernetes, Docker, cloud providers, CDNs, infrastructure-as-code, and more.

## Why dcg Instead of a Custom Hook

The ABMS RFC originally proposed `destructive-gate.sh` as the enforcement-layer example. That hook was functional but limited:

| | `destructive-gate.sh` (original) | `dcg` |
|---|---|---|
| Language | Bash | Rust (SIMD-accelerated) |
| Pattern count | ~8 categories | 49+ security packs |
| Context detection | None | Distinguishes `grep "rm -rf"` (data) from `rm -rf` (execution) |
| Heredoc/inline scanning | No | Yes — catches `python -c "os.remove(...)"` |
| Multi-agent support | Claude Code only | Claude, Gemini CLI, Copilot CLI, Cursor, Aider, Codex |
| Bypass UX | Hash-based file stamp | `DCG_BYPASS=1`, `allow-once <code>`, permanent allowlist |
| Explain mode | None | `dcg explain "<command>"` |
| Maintenance | Self | Jeffrey Emanuel + Darin Gordon, actively maintained |

dcg is the better implementation. ABMS recommends it as the enforcement layer.

## Installation

```bash
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.sh?$(date +%s)" | bash -s -- --easy-mode
```

The installer auto-wires dcg into Claude Code, Gemini CLI, Codex, and Cursor.

### glibc version mismatch

The pre-built Linux binary requires glibc 2.39. On Ubuntu 22.04 LTS (glibc 2.35) the binary fails to load. Build from source:

```bash
cargo install --git https://github.com/Dicklesworthstone/destructive_command_guard --locked destructive_command_guard
```

Update the hook path in `~/.claude/settings.json` to `~/.cargo/bin/dcg`.

## Configuration

The default install only enables the `core` pack. For real-world coverage, enable packs matching your stack. Example config for a stack with Postgres, Kubernetes, Cloudflare Workers, and SQLite: see `dcg-config.toml` in this directory.

Save to `~/.config/dcg/config.toml`.

## Why ABMS Still Keeps a Custom destructive-gate.sh

dcg's packs know about standard commands (`rm`, `git`, `kubectl`, SQL, etc.). They don't know about project-specific scripts with destructive flags.

Example: `load_staging.py --full-wipe` — a custom script with a custom flag — is NOT blocked by any dcg pack. But this is exactly the pattern that destroyed production data in the 2026-04-12 incident.

The trimmed `destructive-gate.sh` ONLY catches these custom script flags:
- `--full-wipe`, `--wipe`, `--truncate`, `--reset-hard`, `--drop-all`, `--nuke`, `--purge-all`

It runs AFTER dcg in the hook chain.

## Hook Order in settings.json

```json
"PreToolUse": [{
  "matcher": "Bash",
  "hooks": [
    { "command": "~/.cargo/bin/dcg" },                       // Layer 1: broad enforcement (49 packs)
    { "command": "~/.claude/hooks/destructive-gate.sh" },    // Layer 2: custom script flags
    { "command": "~/.claude/hooks/git-safety.sh" },          // Layer 3: git-specific advisory
    { "command": "~/.claude/hooks/verify-gate.sh" },         // Layer 4: commit verification gate
    { "command": "~/.claude/rules-engine/inject.sh" }        // Layer 5: ABMS advisory (rules + memory)
  ]
}]
```

Order matters: hard enforcement fires first, advisory fires last.

## What ABMS Still Owns

- **Semantic understanding** — The Apr-12 correction file explains *why* `load_staging.py --full-wipe` destroyed data (trusted docstring, didn't read implementation). dcg just blocks the command; ABMS teaches the lesson.
- **Session continuity** — MemPalace captures decisions across sessions. dcg doesn't know about decisions.
- **Context-specific advisory rules** — API verification checklists, UI mobile checks, data verification patterns. dcg only cares about "is this destructive."
- **Correction lifecycle** — Promotion, escalation decisions, importance scoring. dcg has allowlist management but not incident-to-rule evolution.

dcg is the enforcement muscle. ABMS is the semantic nervous system.
