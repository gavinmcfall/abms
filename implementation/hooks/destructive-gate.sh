#!/bin/bash
# destructive-gate.sh — Custom-script destruction flag guard.
#
# Complements dcg. dcg covers standard commands (rm, git, kubectl, SQL, etc.).
# This hook ONLY catches custom script flags that dcg can't know about:
#   --full-wipe, --wipe, --truncate, --reset-hard, --drop-all, --nuke, --purge-all
#
# Exists because of the 2026-04-12 incident where load_staging.py --full-wipe
# destroyed user tables. dcg blocks the standard ops; this blocks the ones
# hidden behind custom flags.
#
# Bypass: create .claude/.destructive-ok-<hash> in a separate terminal
# (same pattern as the original destructive-gate).

INPUT=$(cat /dev/stdin)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))" 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# ONLY match custom-script destruction flags. dcg handles everything else.
# Word boundaries on both sides to avoid matching substrings.
BLOCKED=""
REASON=""

if echo "$COMMAND" | grep -qE '(^|[[:space:]])(--full-wipe|--wipe|--truncate|--reset-hard|--drop-all|--nuke|--purge-all)([[:space:]]|=|$)'; then
  FLAG=$(echo "$COMMAND" | grep -oE '\-\-(full-wipe|wipe|truncate|reset-hard|drop-all|nuke|purge-all)' | head -1)
  BLOCKED=1
  REASON="Custom script destruction flag detected: $FLAG"
fi

if [ -z "$BLOCKED" ]; then
  exit 0
fi

# Bypass check
HASH=$(echo -n "$COMMAND" | sha256sum | cut -c1-8)
STAMP="$PROJECT_DIR/.claude/.destructive-ok-$HASH"

if [ -f "$STAMP" ]; then
  rm -f "$STAMP"
  echo "destructive-gate: approval stamp consumed for hash $HASH. Allowing." >&2
  exit 0
fi

cat >&2 << EOF
╔══════════════════════════════════════════════════════════════════════╗
║ CUSTOM DESTRUCTION FLAG BLOCKED                                      ║
╚══════════════════════════════════════════════════════════════════════╝

Reason: $REASON

Command: $COMMAND

This hook blocks script-level destruction flags that dcg's standard
packs don't know about. The 2026-04-12 incident destroyed user data
via load_staging.py --full-wipe.

Before running this:
  1. READ the implementation of the script. Don't trust the docstring.
  2. Verify what gets destroyed (tables, files, whatever).
  3. For shared environments (staging/production), have the user run
     it themselves after confirmation. Do NOT bypass this hook.

Bypass (for local/sandbox operations only):
  In a SEPARATE terminal (not via Claude), run:
    HASH=$(echo -n "$COMMAND" | sha256sum | cut -c1-8)
    mkdir -p .claude
    touch .claude/.destructive-ok-\$HASH

  Then retry. Stamp is consumed on use.
EOF
exit 2
