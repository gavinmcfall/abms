---
description: Verification gate protocol — the edit-test-commit chain that physically prevents unverified commits
tags: [protocol, verification, testing, commits, gate]
audience: { human: 40, agent: 60 }
purpose: { low-agency-process: 60, reference: 40 }
---

# Verification Gate Protocol

The most effective behavioral enforcement mechanism in the system. It operates at the action level — physically blocking unverified commits rather than relying on the AI to remember a rule.

## The Chain

```
Edit a file
    ↓
edit-tracker.sh fires (PostToolUse)
    ↓
.verified stamp is DELETED
.edit-count is incremented
    ↓
(Every 5 edits, a nudge reminds the AI to test)
    ↓
Run tests (npm test, pytest, etc.)
    ↓
post-bash.sh fires (PostToolUse)
    ↓
If tests PASS (exit 0):
    .verified stamp is CREATED with timestamp + command
If tests FAIL:
    .verified stamp is DELETED (if it somehow exists)
    ↓
git commit
    ↓
verify-gate.sh fires (PreToolUse)
    ↓
Checks .verified:
    EXISTS and < 30 minutes old → commit proceeds
    MISSING or > 30 minutes old → commit BLOCKED
```

## Files

| File | Purpose | Written By | Read By |
|------|---------|-----------|---------|
| `.claude/.verified` | Verification stamp: `<unix-timestamp>\|<command>` | post-bash.sh | verify-gate.sh |
| `.claude/.edit-count` | Edit counter since last verification | edit-tracker.sh | edit-tracker.sh |

## Recognized Test Commands

post-bash.sh recognizes these commands as test/build commands:

- `npm test`, `npm run test`, `npm run build`, `npm run check`, `npm run lint`
- `pytest`, `py.test`
- `go test`, `cargo test`, `cargo build`
- `dotnet test`, `dotnet build`
- `make test`, `make check`
- `bun test`, `bun run test`
- `pnpm test`, `yarn test`
- `gradle test`, `mvn test`

## Why This Works

This is the pattern ABMS extends. The verification gate succeeds where CLAUDE.md rules fail because:

1. **It operates at the action level** — not at session start where rules degrade
2. **It physically blocks** — the commit cannot proceed, not just "should not"
3. **Every edit resets the stamp** — you can't coast on a stale test run
4. **The 30-minute expiry** — forces re-verification after extended editing

ABMS applies this same principle (point-of-action intervention) to advisory rules, not just hard blocks. The escalation path is: advisory rule → permanent rule → blocking hook.

## Staleness

The `.verified` stamp expires after 30 minutes (1800 seconds). If the AI edits files, runs tests, then spends 45 minutes on other work before committing, the stamp is stale and the commit is blocked — forcing a re-test.

## Interaction with ABMS

The rules engine's `commit.md` context file adds advisory guidance on top of the verification gate's hard block. The gate ensures tests were run; the rules ensure the AI thinks about whether the tests were meaningful.
