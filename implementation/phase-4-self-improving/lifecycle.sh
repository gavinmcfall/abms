#!/bin/bash
# lifecycle.sh — Automated ABMS correction lifecycle management
#
# Run weekly via cron. Handles:
#   1. Promotion review — flag corrections with 5+ accesses
#   2. Staleness check — flag corrections with 0 accesses for 30+ days
#   3. Decay report — show importance distribution
#   4. Log rotation — trim outcomes.log
#
# Install: crontab -e → add:
#   0 9 * * 1 /home/gavin/.claude/rules-engine/lifecycle.sh >> /tmp/abms-lifecycle.log 2>&1
#
# Or run manually anytime: ~/.claude/rules-engine/lifecycle.sh

RULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$RULES_DIR/outcomes.log"
NOW=$(date -Iseconds)
STALE_DAYS=30

echo "==== ABMS Lifecycle Review — $NOW ===="
echo ""

# ── 1. Promotion Candidates ──
echo "── Promotion Candidates (access_count >= 5) ──"
PROMO_COUNT=0
for f in "$RULES_DIR/corrections/"*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "TEMPLATE.md" ] && continue
  COUNT=$(grep "^access_count:" "$f" 2>/dev/null | head -1 | awk '{print $2}')
  if [ "${COUNT:-0}" -ge 5 ]; then
    PROMO_COUNT=$((PROMO_COUNT + 1))
    TAGS=$(grep "^tags:" "$f" | head -1 | sed 's/^tags: //')
    echo "  ⬆ $(basename "$f") — $COUNT accesses, tags: $TAGS"
  fi
done
[ "$PROMO_COUNT" -eq 0 ] && echo "  None."
echo ""

# ── 2. Stale Corrections (no access for 30+ days) ──
echo "── Stale Corrections (no access for ${STALE_DAYS}+ days) ──"
STALE_COUNT=0
CUTOFF_EPOCH=$(date -d "-${STALE_DAYS} days" +%s 2>/dev/null || date -v-${STALE_DAYS}d +%s 2>/dev/null)
for f in "$RULES_DIR/corrections/"*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "TEMPLATE.md" ] && continue
  LAST=$(grep "^last_accessed:" "$f" 2>/dev/null | head -1 | awk '{print $2}')
  if [ "$LAST" = "null" ] || [ -z "$LAST" ]; then
    # Never accessed — check creation date from filename or file mtime
    FILE_DATE=$(basename "$f" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
    if [ -n "$FILE_DATE" ]; then
      FILE_EPOCH=$(date -d "$FILE_DATE" +%s 2>/dev/null || echo 0)
      if [ "$FILE_EPOCH" -gt 0 ] && [ "$FILE_EPOCH" -lt "${CUTOFF_EPOCH:-0}" ]; then
        STALE_COUNT=$((STALE_COUNT + 1))
        echo "  💤 $(basename "$f") — never accessed, created $FILE_DATE"
      fi
    fi
  else
    LAST_EPOCH=$(date -d "$LAST" +%s 2>/dev/null || echo 0)
    if [ "$LAST_EPOCH" -gt 0 ] && [ "$LAST_EPOCH" -lt "${CUTOFF_EPOCH:-0}" ]; then
      STALE_COUNT=$((STALE_COUNT + 1))
      echo "  💤 $(basename "$f") — last accessed $LAST"
    fi
  fi
done
[ "$STALE_COUNT" -eq 0 ] && echo "  None."
echo ""

# ── 3. Correction Health Summary ──
echo "── Correction Health ──"
TOTAL=0
ACTIVE=0
DORMANT=0
HIGH=0
for f in "$RULES_DIR/corrections/"*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "TEMPLATE.md" ] && continue
  TOTAL=$((TOTAL + 1))
  COUNT=$(grep "^access_count:" "$f" 2>/dev/null | head -1 | awk '{print $2}')
  COUNT=${COUNT:-0}
  if [ "$COUNT" -gt 0 ]; then
    ACTIVE=$((ACTIVE + 1))
  else
    DORMANT=$((DORMANT + 1))
  fi
  if [ "$COUNT" -ge 5 ]; then
    HIGH=$((HIGH + 1))
  fi
done
echo "  Total:      $TOTAL"
echo "  Active:     $ACTIVE (accessed at least once)"
echo "  Dormant:    $DORMANT (never accessed)"
echo "  High-freq:  $HIGH (5+ accesses, promotion candidates)"
echo "  Stale:      $STALE_COUNT (no access for ${STALE_DAYS}+ days)"
echo ""

# ── 4. Outcomes Log Rotation ──
if [ -f "$LOG" ]; then
  LOG_LINES=$(wc -l < "$LOG")
  if [ "$LOG_LINES" -gt 500 ]; then
    tail -250 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    echo "── Log Rotation ──"
    echo "  Trimmed outcomes.log from $LOG_LINES to 250 lines."
    echo ""
  fi
fi

# ── 5. Palace Health (quick check) ──
if command -v mempalace &>/dev/null; then
  echo "── Palace Health ──"
  PALACE_SIZE=$(du -sh ~/.mempalace/palace 2>/dev/null | cut -f1)
  echo "  Palace size: $PALACE_SIZE"
  # Quick search test
  TEST=$(timeout 3 mempalace search "test" --results 1 2>&1 | grep -c "Source:" || echo "0")
  if [ "$TEST" -gt 0 ]; then
    echo "  Search: ✓ working"
  else
    echo "  Search: ✗ may need repair"
  fi
  echo ""
fi

echo "==== Lifecycle Review Complete ===="
