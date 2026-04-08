#!/bin/bash
# inject.sh — PreToolUse hook for ABMS rule injection
#
# Orchestrates the injection pipeline:
#   1. Parse action from hook JSON
#   2. Route to ruleset via engine.sh
#   3. Load static rules for that ruleset
#   4. Load matching corrections by tag
#   5. Output everything (injected into assistant context)

RULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_LINES=40

# Parse input JSON from stdin
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))" 2>/dev/null)

TOOL_INPUT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
# For Bash: command. For Edit/Write: file_path
print(ti.get('command', ti.get('file_path', '')))" 2>/dev/null)

# Bail early if we couldn't parse
[ -z "$TOOL" ] && exit 0

# Split into command and file_path based on tool type
COMMAND=""
FILE_PATH=""
case "$TOOL" in
  Bash)   COMMAND="$TOOL_INPUT" ;;
  Edit|Write) FILE_PATH="$TOOL_INPUT" ;;
esac

# Layer 1: Route to ruleset
RULESET=$("$RULES_DIR/engine.sh" "$TOOL" "$COMMAND" "$FILE_PATH")

# Layer 2: Check worklog scope for context enrichment
SCOPE=""
if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -f "$CLAUDE_PROJECT_DIR/.claude/worklog.md" ]; then
  SCOPE=$(grep "^[a-f0-9]" "$CLAUDE_PROJECT_DIR/.claude/worklog.md" 2>/dev/null \
    | head -1 | cut -d'|' -f4 | tr -d ' ')
fi

# Layer 3: Load static rules
OUTPUT=""
CONTEXT_FILE="$RULES_DIR/contexts/$RULESET.md"
if [ -f "$CONTEXT_FILE" ]; then
  OUTPUT="── ABMS ($RULESET) ──
$(cat "$CONTEXT_FILE")
"
fi

# Layer 4: Load matching corrections by tag
CORRECTION_OUTPUT=""
CORRECTION_IDS=""
for f in "$RULES_DIR/corrections/"*.md; do
  [ -f "$f" ] || continue
  # Check if any tag in the frontmatter matches the ruleset
  if head -10 "$f" | grep -q "tags:.*$RULESET"; then
    # Extract body (skip frontmatter)
    BODY=$(awk '/^---$/{n++; next} n>=2' "$f" | head -15)
    if [ -n "$BODY" ]; then
      CORRECTION_OUTPUT+="$BODY
---
"
      CORRECTION_IDS+="$(basename "$f") "
    fi
  fi
done

if [ -n "$CORRECTION_OUTPUT" ]; then
  OUTPUT+="── Corrections ──
$CORRECTION_OUTPUT"
fi

# Write marker for outcome.sh (what was injected and which corrections)
echo "$RULESET|$CORRECTION_IDS" > "$RULES_DIR/.last-injection"

# Budget check
if [ -n "$OUTPUT" ]; then
  LINE_COUNT=$(echo "$OUTPUT" | wc -l)
  if [ "$LINE_COUNT" -gt "$MAX_LINES" ]; then
    OUTPUT=$(echo "$OUTPUT" | head -"$MAX_LINES")
    OUTPUT+="
... (truncated, $LINE_COUNT lines available)"
  fi
  echo "$OUTPUT"
fi

exit 0
