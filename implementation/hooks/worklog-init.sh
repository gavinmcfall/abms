#!/bin/bash
# Worklog session coordination — register, clean stale, inject context
# Location: ~/.claude/hooks/worklog-init.sh (global, all projects)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
WORKLOG="$CLAUDE_DIR/worklog.md"
LOCKFILE="$CLAUDE_DIR/.worklog.lock"
SID=$(uuidgen | cut -c1-8)
NOW=$(TZ='Pacific/Auckland' date '+%Y-%m-%dT%H:%M%z')
STALE_SECONDS=$((4 * 3600))

mkdir -p "$CLAUDE_DIR"

# --- Atomic worklog operations under flock ---
(
    flock -w 5 200 || { echo "WORKLOG: lock timeout, skipping registration"; exit 0; }

    # Create worklog if missing
    if [ ! -f "$WORKLOG" ]; then
        cat > "$WORKLOG" << 'WEOF'
# WORKLOG v2

@ACTIVE
# sid|registered|last_active|scope

@LOG
# timestamp|sid|op|detail
WEOF
    fi

    # Validate structure — recreate if corrupt
    if ! grep -q '^@ACTIVE' "$WORKLOG" || ! grep -q '^@LOG' "$WORKLOG"; then
        cat > "$WORKLOG" << 'WEOF'
# WORKLOG v2

@ACTIVE
# sid|registered|last_active|scope

@LOG
# timestamp|sid|op|detail
WEOF
    fi

    # Migrate v1 → v2: remove @FILES section if present
    if grep -q '^@FILES' "$WORKLOG"; then
        sed -i '/@FILES/,/@LOG/{/@LOG/!d}' "$WORKLOG"
    fi

    # Clean stale sessions (last_active > 4h ago)
    NOW_EPOCH=$(date '+%s')
    STALE_SIDS=""
    while IFS='|' read -r s_sid s_reg s_active s_scope; do
        [[ "$s_sid" =~ ^#|^$ ]] && continue
        A_EPOCH=$(date -d "$s_active" '+%s' 2>/dev/null || echo "$NOW_EPOCH")
        if [ $((NOW_EPOCH - A_EPOCH)) -gt $STALE_SECONDS ]; then
            STALE_SIDS="$STALE_SIDS $s_sid"
        fi
    done < <(sed -n '/@ACTIVE/,/@LOG/{//d;p}' "$WORKLOG")

    for stale in $STALE_SIDS; do
        sed -i "/^${stale}|/d" "$WORKLOG"
        rm -f "$CLAUDE_DIR/.sid-${stale}"
    done
    if [ -n "$STALE_SIDS" ]; then
        CLEANED=$(echo "$STALE_SIDS" | xargs | tr ' ' ',')
        echo "${NOW}|${SID}|CLN|stale:${CLEANED}" >> "$WORKLOG"
    fi

    # Register this session in @ACTIVE (insert after header comment)
    sed -i "/^# sid|registered|last_active|scope$/a\\
${SID}|${NOW}|${NOW}|unset" "$WORKLOG"

    # Append REG log entry
    echo "${NOW}|${SID}|REG|started" >> "$WORKLOG"

    # Trim @LOG to last 50 entries (keep section marker and header comment)
    LOG_LINE=$(grep -n '^@LOG' "$WORKLOG" | cut -d: -f1)
    if [ -n "$LOG_LINE" ]; then
        COMMENT_LINE=$((LOG_LINE + 1))
        TOTAL=$(wc -l < "$WORKLOG")
        LOG_COUNT=$((TOTAL - COMMENT_LINE))
        if [ "$LOG_COUNT" -gt 50 ]; then
            KEEP_FROM=$((TOTAL - 49))
            { head -n "$COMMENT_LINE" "$WORKLOG"; tail -n +$KEEP_FROM "$WORKLOG"; } > "$WORKLOG.tmp"
            mv "$WORKLOG.tmp" "$WORKLOG"
        fi
    fi

) 200>"$LOCKFILE"

# Create session ID sidecar (survives compaction, identifies this session)
echo "$SID" > "$CLAUDE_DIR/.sid-${SID}"

# --- Output for Claude context injection ---
echo "WORKLOG_SID=${SID}"

ACTIVE_COUNT=$(sed -n '/@ACTIVE/,/@LOG/{//d;/^#/d;/^$/d;p}' "$WORKLOG" | wc -l)
if [ "$ACTIVE_COUNT" -gt 1 ]; then
    echo "WORKLOG: ${ACTIVE_COUNT} sessions active. Check worklog before committing."
    echo "---other-sessions---"
    sed -n '/@ACTIVE/,/@LOG/{//d;/^#/d;/^$/d;p}' "$WORKLOG" | grep -v "^${SID}|"
else
    echo "WORKLOG: sole session."
fi

exit 0
