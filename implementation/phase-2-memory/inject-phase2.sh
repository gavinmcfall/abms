#!/bin/bash
# inject.sh (Phase 2) — PreToolUse hook with MemPalace memory queries
#
# Extends Phase 1 with Layer 5: semantic memory search
# Falls back gracefully to Phase 1 behavior if MemPalace is unavailable

RULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_LINES=50  # increased budget for memory results

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
print(ti.get('command', ti.get('file_path', '')))" 2>/dev/null)

[ -z "$TOOL" ] && exit 0

COMMAND=""
FILE_PATH=""
case "$TOOL" in
  Bash)   COMMAND="$TOOL_INPUT" ;;
  Edit|Write) FILE_PATH="$TOOL_INPUT" ;;
esac

# Layer 1: Route to ruleset
RULESET=$("$RULES_DIR/engine.sh" "$TOOL" "$COMMAND" "$FILE_PATH")

# Layer 2: Check worklog scope
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
  [ "$(basename "$f")" = "TEMPLATE.md" ] && continue
  if head -10 "$f" | grep -q "tags:.*$RULESET"; then
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

# Layer 5: MemPalace memory query (Phase 2)
# CLI only exposes search; knowledge graph queries require MCP tools,
# which are not available to bash hooks. Search still finds KG-stored content.
if command -v mempalace &>/dev/null; then
  # Build contextual search query
  SEARCH_QUERY="$RULESET verification corrections"
  [ -n "$SCOPE" ] && SEARCH_QUERY="$SCOPE $SEARCH_QUERY"
  [ -n "$FILE_PATH" ] && SEARCH_QUERY="$SEARCH_QUERY $(basename "$FILE_PATH" 2>/dev/null)"

  # Search with timeout to avoid hanging the hook
  MEMORY_RESULTS=$(timeout 3 mempalace search "$SEARCH_QUERY" --results 3 2>/dev/null | head -20)

  if [ -n "$MEMORY_RESULTS" ]; then
    OUTPUT+="── Memory ──
$MEMORY_RESULTS
"
  fi
fi

# Write marker for outcome.sh
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
