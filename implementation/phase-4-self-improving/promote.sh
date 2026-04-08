#!/bin/bash
# promote.sh — Review correction access counts and suggest promotions
#
# Run manually or on a schedule to review which corrections should be
# promoted to permanent rules.
#
# Usage: promote.sh [--auto]
#   Without --auto: prints candidates and waits for confirmation
#   With --auto: prints candidates only (no modifications)

RULES_DIR="$HOME/.claude/rules-engine"
PROMOTION_THRESHOLD=5
AUTO_MODE="${1:-}"

echo "=== ABMS Correction Review ==="
echo ""

CANDIDATES=0
TOTAL=0
DORMANT=0

for f in "$RULES_DIR/corrections/"*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "TEMPLATE.md" ] && continue

  TOTAL=$((TOTAL + 1))
  NAME=$(basename "$f")
  COUNT=$(grep "^access_count:" "$f" 2>/dev/null | head -1 | awk '{print $2}')
  COUNT=${COUNT:-0}
  LAST=$(grep "^last_accessed:" "$f" 2>/dev/null | head -1 | awk '{print $2}')
  TAGS=$(grep "^tags:" "$f" 2>/dev/null | head -1 | sed 's/^tags: //')
  SEVERITY=$(grep "^severity:" "$f" 2>/dev/null | head -1 | awk '{print $2}')

  if [ "$COUNT" -ge "$PROMOTION_THRESHOLD" ]; then
    CANDIDATES=$((CANDIDATES + 1))
    echo "PROMOTE CANDIDATE: $NAME"
    echo "  Tags: $TAGS"
    echo "  Severity: $SEVERITY"
    echo "  Access count: $COUNT"
    echo "  Last accessed: $LAST"
    echo "  Body:"
    awk '/^---$/{n++; next} n>=2' "$f" | head -5 | sed 's/^/    /'
    echo ""
  elif [ "$COUNT" -eq 0 ]; then
    DORMANT=$((DORMANT + 1))
  fi
done

echo "---"
echo "Total corrections: $TOTAL"
echo "Promotion candidates (>= $PROMOTION_THRESHOLD accesses): $CANDIDATES"
echo "Dormant (0 accesses): $DORMANT"
echo "Active: $((TOTAL - CANDIDATES - DORMANT))"

if [ "$CANDIDATES" -eq 0 ]; then
  echo ""
  echo "No corrections ready for promotion."
  exit 0
fi

if [ "$AUTO_MODE" != "--auto" ]; then
  echo ""
  echo "To promote a correction, move its content into the matching contexts/*.md file"
  echo "and either delete or archive the correction file."
fi
