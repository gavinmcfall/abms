---
description: Self-improving correction loop setup for ABMS Phase 4
tags: [setup, promotion, escalation, self-improving, phase-4]
audience: { human: 80, agent: 20 }
purpose: { low-agency-process: 60, reference: 40 }
---

# Phase 4: Self-Improving Loop

Phase 4 adds tools for reviewing correction patterns and escalating persistent failures.

## Prerequisites

- Phases 1-3 installed and working
- A growing corrections directory with access count data

## Tools

### promote.sh — Review and promote corrections

```bash
# Review all corrections, find promotion candidates
~/.claude/rules-engine/promote.sh

# Output-only mode (no prompts)
~/.claude/rules-engine/promote.sh --auto
```

A correction is a promotion candidate when `access_count >= 5`. Promotion means moving the correction's content into the matching `contexts/*.md` file as a permanent rule.

### escalate.sh — Generate blocking hooks from persistent failures

```bash
# Generate a blocking hook from a correction that keeps failing
~/.claude/rules-engine/escalate.sh \
  corrections/2026-04-08_shallow-api.md \
  ~/.claude/hooks/deep-api-verify.sh
```

This generates a PreToolUse hook that BLOCKS the action (like verify-gate.sh) rather than just injecting advisory rules. Use when:

1. A correction has been promoted to a permanent rule
2. The AI still fails to follow it despite the rule being present
3. The behavior is important enough to justify blocking

## The Escalation Ladder

```
1. Incident → correction filed (advisory, surfaces on matching actions)
        ↓
2. Correction fires 5+ times → promote to permanent rule (always present)
        ↓
3. AI still fails despite rule → escalate to blocking hook (action blocked)
        ↓
4. Pattern resolved → demote hook back to rule, then let correction decay
```

Each step increases enforcement strength at the cost of flexibility. The goal is to use the minimum effective enforcement — block only what needs blocking.

## Suggested Review Cadence

- **Weekly:** Run `promote.sh` to review correction access counts
- **Monthly:** Review promoted rules — are they still needed? Any to demote?
- **Quarterly:** Review dormant corrections — retag, archive, or delete unused ones
