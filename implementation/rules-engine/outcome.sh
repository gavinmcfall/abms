#!/bin/bash
# outcome.sh — PostToolUse hook for ABMS outcome tracking
#
# Logs outcomes and bumps access counts on corrections that were injected.
# Checks for promotion candidates.

RULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$RULES_DIR/outcomes.log"
MARKER="$RULES_DIR/.last-injection"

# Parse input
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))" 2>/dev/null)

# Log outcome (lightweight)
echo "$(date -Iseconds)|$TOOL" >> "$LOG" 2>/dev/null

# Rotate log if over 500 lines
LOG_LINES=$(wc -l < "$LOG" 2>/dev/null || echo 0)
if [ "$LOG_LINES" -gt 500 ]; then
  tail -250 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

# Bump access counts for corrections that were injected pre-action
if [ -f "$MARKER" ]; then
  RULESET=$(cut -d'|' -f1 "$MARKER")
  CORRECTION_IDS=$(cut -d'|' -f2 "$MARKER")

  for correction_name in $CORRECTION_IDS; do
    f="$RULES_DIR/corrections/$correction_name"
    [ -f "$f" ] || continue

    # Increment access_count
    if grep -q "^access_count:" "$f"; then
      COUNT=$(grep "^access_count:" "$f" | head -1 | awk '{print $2}')
      NEW_COUNT=$((COUNT + 1))
      sed -i "s/^access_count: .*/access_count: $NEW_COUNT/" "$f"
      sed -i "s/^last_accessed: .*/last_accessed: $(date -Iseconds)/" "$f"

      # Check for promotion candidate
      if [ "$NEW_COUNT" -ge 5 ]; then
        DISPLAY_NAME=$(grep "^tags:" "$f" | head -1)
        echo "⚠ RECURRING: $correction_name (fired $NEW_COUNT times). Consider promoting to contexts/$RULESET.md"
      fi
    fi
  done

  rm -f "$MARKER"
fi

exit 0
