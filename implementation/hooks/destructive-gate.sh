#!/bin/bash
# destructive-gate.sh — PreToolUse hook that BLOCKS destructive operations.
#
# This is the escalation step from advisory corrections to hard enforcement.
# Follows the verify-gate.sh pattern: physically prevents the action.
#
# What gets blocked:
#   - Scripts whose name contains: wipe, clear, reset, nuke, destroy, purge, drop
#   - Command flags: --wipe, --full-wipe, --force (git), --reset-hard, --truncate
#   - SQL keywords: DROP TABLE, DROP DATABASE, TRUNCATE, DELETE FROM (without WHERE)
#   - File destruction: rm -rf on paths outside safe-list
#   - Git destruction: push --force, reset --hard, branch -D
#   - Kubectl: delete on non-local contexts
#
# Safe paths (allow rm -rf):
#   /tmp/*, /var/tmp/*, ~/scratch/*, ~/.cache/*, /dev/shm/*
#
# Bypass:
#   Create .claude/.destructive-ok-<hash> where hash = first 8 chars of
#   sha256 of the exact command. Must be done in a DIFFERENT terminal
#   (not by Claude), ensuring out-of-band human approval.
#
# Example bypass:
#   CMD='load_staging.py --full-wipe'
#   HASH=$(echo -n "$CMD" | sha256sum | cut -c1-8)
#   touch .claude/.destructive-ok-$HASH
#   # Claude can now run the exact command one time (stamp gets deleted)

INPUT=$(cat /dev/stdin)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))" 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# ── Pattern matching ──
BLOCKED=""
REASON=""

# Script names containing destructive words
if echo "$COMMAND" | grep -qiE '\b\w*[/_-]?(wipe|clear|reset|nuke|destroy|purge)[\w_-]*\.(sh|py|js|ts|rb)\b'; then
  if ! echo "$COMMAND" | grep -qiE '\b(clearfix|resetpassword|clear-cache|reset-db-cache)\b'; then
    BLOCKED=1
    REASON="Script name suggests destructive intent (wipe/clear/reset/nuke/destroy/purge)"
  fi
fi

# Destructive flags
if echo "$COMMAND" | grep -qE '(^|[[:space:]])(--full-wipe|--wipe|--truncate|--reset-hard|--drop-all|--nuke)([[:space:]]|$)'; then
  BLOCKED=1
  REASON="Destructive flag detected ($(echo "$COMMAND" | grep -oE '\-\-(full-wipe|wipe|truncate|reset-hard|drop-all|nuke)' | head -1))"
fi

# SQL destruction
if echo "$COMMAND" | grep -qiE '(DROP[[:space:]]+TABLE|DROP[[:space:]]+DATABASE|TRUNCATE[[:space:]]+TABLE|TRUNCATE[[:space:]]+\w)'; then
  BLOCKED=1
  REASON="SQL destructive statement (DROP/TRUNCATE)"
fi

# DELETE FROM without WHERE (rough check)
if echo "$COMMAND" | grep -qiE 'DELETE[[:space:]]+FROM[[:space:]]+\w+' && ! echo "$COMMAND" | grep -qiE 'WHERE'; then
  BLOCKED=1
  REASON="DELETE FROM without WHERE clause"
fi

# git push --force / --force-with-lease
if echo "$COMMAND" | grep -qE 'git[[:space:]]+push[[:space:]]+.*(--force|--force-with-lease|[[:space:]]-f[[:space:]]|[[:space:]]-f$)'; then
  BLOCKED=1
  REASON="git push --force"
fi

# git reset --hard
if echo "$COMMAND" | grep -qE 'git[[:space:]]+.*reset[[:space:]]+--hard'; then
  BLOCKED=1
  REASON="git reset --hard"
fi

# git branch -D
if echo "$COMMAND" | grep -qE 'git[[:space:]]+branch[[:space:]]+-D'; then
  BLOCKED=1
  REASON="git branch -D (force-delete branch)"
fi

# rm -rf (unless target is in safe-list)
if echo "$COMMAND" | grep -qE 'rm[[:space:]]+.*-[rR]f?'; then
  # Extract the target — everything after the flags
  TARGETS=$(echo "$COMMAND" | grep -oE 'rm[[:space:]]+-[rRf]+[[:space:]]+[^[:space:]|&;]+' | awk '{for(i=3;i<=NF;i++) print $i}')
  for target in $TARGETS; do
    # Expand tilde
    target_expanded="${target/#\~/$HOME}"
    case "$target_expanded" in
      /tmp/*|/var/tmp/*|/dev/shm/*)
        ;;  # safe
      "$HOME"/scratch/*|"$HOME"/.cache/*|"$HOME"/.mempalace/session-saves/*)
        ;;  # safe
      /*|"$HOME"/*)
        BLOCKED=1
        REASON="rm -rf on potentially important path: $target"
        break
        ;;
    esac
  done
fi

# kubectl delete on non-local context
if echo "$COMMAND" | grep -qE 'kubectl[[:space:]]+.*delete'; then
  # If the command specifies a non-local kubeconfig or context, block
  if echo "$COMMAND" | grep -qiE '(kubeconfig.*prod|kubeconfig.*staging|--context[[:space:]]+\S*prod|--context[[:space:]]+\S*staging|home-ops|--all-namespaces)'; then
    BLOCKED=1
    REASON="kubectl delete on production/staging or cluster-wide"
  fi
fi

# Docker / container destruction
if echo "$COMMAND" | grep -qE '(docker[[:space:]]+(volume[[:space:]]+rm|system[[:space:]]+prune[[:space:]]+.*-a)|docker[[:space:]]+rm[[:space:]]+-f[[:space:]]+\$\(docker)'; then
  BLOCKED=1
  REASON="Docker volume/system destruction"
fi

# DROP DATABASE
if echo "$COMMAND" | grep -qiE 'DROP[[:space:]]+DATABASE|dropdb[[:space:]]'; then
  BLOCKED=1
  REASON="Database drop"
fi

# ── Bypass check ──
if [ -n "$BLOCKED" ]; then
  HASH=$(echo -n "$COMMAND" | sha256sum | cut -c1-8)
  STAMP="$PROJECT_DIR/.claude/.destructive-ok-$HASH"

  if [ -f "$STAMP" ]; then
    # Consume the stamp — one-time use
    rm -f "$STAMP"
    echo "Destructive-gate: approval stamp consumed for hash $HASH. Allowing this one operation." >&2
    exit 0
  fi

  # BLOCK
  cat >&2 << EOF
╔══════════════════════════════════════════════════════════════════════╗
║ DESTRUCTIVE OPERATION BLOCKED                                        ║
╚══════════════════════════════════════════════════════════════════════╝

Reason: $REASON

Command: $COMMAND

This hook exists because destructive operations against shared
environments have destroyed user data before. Advisory corrections
were not enough.

To proceed:

  OPTION A — Preferred for shared environments:
  The user runs the destructive operation themselves in their own
  terminal after verifying the scope. Do NOT ask the user to approve
  via the bypass mechanism for operations against staging/production
  unless there is no alternative.

  OPTION B — Bypass for local/sandbox operations:
  In a SEPARATE terminal (not via Claude), the user runs:

    HASH=$(echo -n "$COMMAND" | sha256sum | cut -c1-8)
    mkdir -p .claude
    touch .claude/.destructive-ok-$HASH

  Then retry the command. The stamp is consumed on use (one-shot).

If you are the AI: stop. Ask the user what they want to do. Do not
attempt to create the bypass stamp yourself — the stamp must be created
out-of-band to represent genuine human approval.
EOF
  exit 2
fi

exit 0
